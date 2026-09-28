//
//  DefaultSummaryRepository.swift
//  GAMSS
//
//  Created by cchanmi on 8/7/26.
//

import Foundation
import onnxruntime_objc
import Tokenizers

// actor로 선언해 encoder/decoder ORTSession과 tokenizer에 대한 동시 접근을 직렬화한다.
// ONNX Runtime 세션은 스레드 세이프하지 않아서, summarize가 여러 곳에서 동시에
// 호출되면 run() 호출들이 서로 레이스할 수 있다.
actor DefaultSummaryRepository: SummaryRepository {
    // 모델이 이 값들에 맞춰 학습/export되어 있으므로 임의 변경 금지.
    private static let decoderStartToken = 1
    private static let eosToken = 1
    private static let vocabSize = 30_000
    private static let maxInputTokens = 512
    private static let maxOutputTokens = 64
    private static let noRepeatNgram = 3

    // 모델이 export될 때 고정된 텐서 입출력 이름.
    private static let encoderInputIdsKey = "input_ids"
    private static let encoderAttentionMaskKey = "attention_mask"
    private static let encoderOutputKey = "last_hidden_state"
    private static let decoderInputIdsKey = "input_ids"
    private static let decoderEncoderAttentionMaskKey = "encoder_attention_mask"
    private static let decoderEncoderHiddenStatesKey = "encoder_hidden_states"
    private static let decoderOutputKey = "logits"

    private let encoder: ORTSession
    private let decoder: ORTSession
    private let tokenizer: Tokenizer

    private init(encoder: ORTSession, decoder: ORTSession, tokenizer: Tokenizer) {
        self.encoder = encoder
        self.decoder = decoder
        self.tokenizer = tokenizer
    }

    static func make() async throws -> DefaultSummaryRepository {
        guard
            let encoderPath = Bundle.main.path(forResource: "kobart_encoder_int8", ofType: "onnx"),
            let decoderPath = Bundle.main.path(forResource: "kobart_decoder_int8", ofType: "onnx")
        else {
            throw SummaryError.modelLoadFailed()
        }

        let encoder: ORTSession
        let decoder: ORTSession
        do {
            let env = try ORTEnv(loggingLevel: .warning)
            encoder = try ORTSession(env: env, modelPath: encoderPath, sessionOptions: nil)
            decoder = try ORTSession(env: env, modelPath: decoderPath, sessionOptions: nil)
        } catch {
            throw SummaryError.modelLoadFailed(underlying: error)
        }

        let tokenizer = try await Self.loadTokenizer()
        return DefaultSummaryRepository(encoder: encoder, decoder: decoder, tokenizer: tokenizer)
    }

    // AutoTokenizer.from(modelFolder:)는 폴더 안에서 표준 파일명("tokenizer.json"/"tokenizer_config.json")을
    // 직접 찾는다. 앱 번들은 리소스를 평탄화해 복사하므로 kobart_tokenizer.json이 있는 폴더에는
    // 다른 모델(EmotionAnalysis)의 실제 tokenizer.json도 함께 존재해, 그쪽이 잘못 로드될 수 있다.
    // 이를 피하기 위해 표준 파일명으로만 구성된 격리된 임시 폴더를 만들어 그 안에서 로드한다.
    private static func loadTokenizer() async throws -> Tokenizer {
        guard let tokenizerURL = Bundle.main.url(forResource: "kobart_tokenizer", withExtension: "json") else {
            throw SummaryError.modelLoadFailed()
        }

        let isolatedFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: isolatedFolder) }

        do {
            try FileManager.default.createDirectory(at: isolatedFolder, withIntermediateDirectories: true)

            let tokenizerData = try Data(contentsOf: tokenizerURL)
            try tokenizerData.write(to: isolatedFolder.appendingPathComponent("tokenizer.json"))

            // tokenizer_config.json이 따로 없으므로 tokenizer_class만 채운 최소 설정을 함께 둔다.
            // 이 모델은 BPE + RobertaProcessing 구성이라 RobertaTokenizer로 지정하면 BPETokenizer로 매핑된다.
            let minimalTokenizerConfig = Data(#"{"tokenizer_class": "RobertaTokenizer", "unk_token": "<unk>"}"#.utf8)
            try minimalTokenizerConfig.write(to: isolatedFolder.appendingPathComponent("tokenizer_config.json"))

            return try await AutoTokenizer.from(modelFolder: isolatedFolder)
        } catch {
            throw SummaryError.modelLoadFailed(underlying: error)
        }
    }

    func summarize(text: String) async throws -> String {
        do {
            let (inputIds, attentionMask) = Self.buildEncoderInputs(from: tokenizer.encode(text: text))
            let idsTensor = try Self.makeInt64Tensor(inputIds)
            // encoder/decoder에서 공유하는 attention mask. ORT Objective-C에는 명시적 close()가
            // 없고 ARC가 네이티브 버퍼 해제를 담당하므로, 매 스텝 재생성하지 않고 그대로 재사용한다.
            let maskTensor = try Self.makeInt64Tensor(attentionMask)

            let encoderOutputs = try encoder.run(
                withInputs: [
                    Self.encoderInputIdsKey: idsTensor,
                    Self.encoderAttentionMaskKey: maskTensor,
                ],
                outputNames: [Self.encoderOutputKey],
                runOptions: nil
            )
            guard let encoderHidden = encoderOutputs[Self.encoderOutputKey] else {
                throw SummaryError.inferenceFailed()
            }

            let generatedTokens = try greedyDecode(encoderHidden: encoderHidden, encoderAttentionMask: maskTensor)
            let summary = tokenizer.decode(tokens: generatedTokens, skipSpecialTokens: true)
            return summary.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as SummaryError {
            throw error
        } catch {
            Log.error("요약 추론 실패: \(error)")
            throw SummaryError.inferenceFailed(underlying: error)
        }
    }

    /// 절단 없는 실제 토큰 수. swift-transformers의 encode()는 자체적으로 truncation을 하지 않으므로
    /// (그 truncation은 summarize()의 buildEncoderInputs에서만 수동으로 함) 그대로 개수를 세면 된다.
    func countTokens(text: String) async throws -> Int {
        tokenizer.encode(text: text).count
    }

    // 인코더 1회 실행 결과(encoderHidden)를 매 스텝 재사용하며, 지금까지 생성된 전체 시퀀스를
    // 다시 디코더에 통째로 넣는 cache-free 그리디 디코딩(디코더가 KV 캐시를 안 쓰므로).
    private func greedyDecode(encoderHidden: ORTValue, encoderAttentionMask: ORTValue) throws -> [Int] {
        var sequence = [Self.decoderStartToken]
        var generated: [Int] = []

        for _ in 0..<Self.maxOutputTokens {
            let sequenceTensor = try Self.makeInt64Tensor(sequence)
            let decoderOutputs = try decoder.run(
                withInputs: [
                    Self.decoderInputIdsKey: sequenceTensor,
                    Self.decoderEncoderAttentionMaskKey: encoderAttentionMask,
                    Self.decoderEncoderHiddenStatesKey: encoderHidden,
                ],
                outputNames: [Self.decoderOutputKey],
                runOptions: nil
            )
            guard let logitsValue = decoderOutputs[Self.decoderOutputKey] else {
                throw SummaryError.inferenceFailed()
            }

            let nextToken = try Self.argmaxLastPosition(
                logits: logitsValue,
                sequenceLength: sequence.count,
                banned: Self.bannedNgramTokens(sequence)
            )

            if nextToken == Self.eosToken {
                break
            }
            generated.append(nextToken)
            sequence.append(nextToken)
        }

        return generated
    }

    // swift-transformers의 Tokenizer.encode()는 truncation을 적용하지 않으므로(post-processor로
    // <s>/</s>만 붙임), 여기서 직접 자른다. 마지막 </s>(eos=1)를 보존하도록 앞 511개 + eos로 자른다.
    private static func buildEncoderInputs(from tokenIds: [Int]) -> (ids: [Int], mask: [Int]) {
        let truncated: [Int]
        if tokenIds.count > maxInputTokens {
            truncated = Array(tokenIds.prefix(maxInputTokens - 1)) + [eosToken]
        } else {
            truncated = tokenIds
        }
        return (truncated, Array(repeating: 1, count: truncated.count))
    }

    private static func makeInt64Tensor(_ values: [Int]) throws -> ORTValue {
        var data = Data(capacity: values.count * MemoryLayout<Int64>.size)
        for value in values {
            var int64Value = Int64(value)
            withUnsafeBytes(of: &int64Value) { data.append(contentsOf: $0) }
        }
        return try ORTValue(
            tensorData: NSMutableData(data: data),
            elementType: .int64,
            shape: [NSNumber(value: 1), NSNumber(value: values.count)]
        )
    }

    // shape을 require해 디코더 재export 시의 출력 형태 변화를 조기에 잡는다.
    private static func argmaxLastPosition(logits: ORTValue, sequenceLength: Int, banned: Set<Int>) throws -> Int {
        let shapeInfo = try logits.tensorTypeAndShapeInfo()
        let shape = shapeInfo.shape.map(\.intValue)
        guard shape.count == 3, shape[1] == sequenceLength, shape[2] == vocabSize else {
            throw SummaryError.inferenceFailed()
        }

        let data = try logits.tensorData() as Data
        let offset = (sequenceLength - 1) * vocabSize
        var bestIndex = 0
        var bestValue = -Float.greatestFiniteMagnitude
        data.withUnsafeBytes { (rawBuffer: UnsafeRawBufferPointer) in
            let floats = rawBuffer.bindMemory(to: Float.self)
            for index in 0..<vocabSize where !banned.contains(index) {
                let value = floats[offset + index]
                if value > bestValue {
                    bestValue = value
                    bestIndex = index
                }
            }
        }
        return bestIndex
    }

    // no_repeat_ngram: 직전 (n-1)개 토큰 뒤에 와서 이미 등장한 n-gram을 완성하는 토큰들을 금지한다.
    private static func bannedNgramTokens(_ sequence: [Int]) -> Set<Int> {
        guard sequence.count >= noRepeatNgram else { return [] }
        let prefixStart = sequence.count - (noRepeatNgram - 1)
        var banned: Set<Int> = []
        for i in 0...(sequence.count - noRepeatNgram) {
            var matches = true
            for j in 0..<(noRepeatNgram - 1) where sequence[i + j] != sequence[prefixStart + j] {
                matches = false
                break
            }
            if matches {
                banned.insert(sequence[i + noRepeatNgram - 1])
            }
        }
        return banned
    }
}
