//
//  ConversationSummaryPolicy.swift
//  GAMSS
//
//  Created by cchanmi on 8/7/26.
//

enum ConversationSummaryPolicy {
    /// 서버 제약. 메시지 입력 UI도 이 값으로 길이를 제한한다.
    static let maxMessageLength = 140
    /// 서버가 받는 컨텍스트 압축본의 최대 길이. 넘기면 서버가 전송 자체를 거절한다.
    static let maxContextSummaryLength = 2000
    /// 원문으로 남기는 최근 발화 수. 직전 맥락이 답장 품질에 가장 크게 기여한다.
    static let recentRawUtterances = 3
    /// 요약기(KoBART) 인코더 입력 한계. 이 크기로 청크를 끊어 한 번씩만 요약한다.
    static let summaryChunkTokenBudget = 512

    static let lengthLimitToastMessage = "메시지는 140자까지 입력할 수 있어요"

    struct InputNormalizationResult: Equatable {
        let value: String
        let shouldDismissKeyboard: Bool
        let didExceedLimit: Bool
    }

    /// 메시지 입력창의 원시 입력값을 정책에 맞게 정규화한다. `maxMessageLength`를 넘지 않도록
    /// 잘라내는 것 외에는 값을 건드리지 않는다(UX용 제한이며, 최종 검증은 `SendMessageUseCase`가
    /// 한다).
    static func normalizeInput(_ raw: String) -> InputNormalizationResult {
        guard raw.count > maxMessageLength else {
            return InputNormalizationResult(value: raw, shouldDismissKeyboard: false, didExceedLimit: false)
        }

        return InputNormalizationResult(
            value: String(raw.prefix(maxMessageLength)),
            shouldDismissKeyboard: false,
            didExceedLimit: true
        )
    }
}
