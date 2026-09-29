//
//  ChatViewModelRiskDetectionTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/20/26.
//

import XCTest
@testable import GAMSS

private final class StubRiskLexiconRepository: RiskLexiconRepository {
    var stubbedLexicon: RiskLexicon = .empty

    func currentLexicon() async -> RiskLexicon { stubbedLexicon }

    func refresh() async {}
}

private actor GatedRiskLexiconRepository: RiskLexiconRepository {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?
    private let lexicon: RiskLexicon

    init(lexicon: RiskLexicon) {
        self.lexicon = lexicon
    }

    func currentLexicon() async -> RiskLexicon {
        if !isOpen {
            await withCheckedContinuation { continuation = $0 }
        }
        return lexicon
    }

    func refresh() async {}

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class ChatViewModelRiskDetectionTests: XCTestCase {
    private func makeViewModel(lexicon: RiskLexicon) -> (ChatViewModel, MockConversationRepositoryForRisk) {
        let repository = MockConversationRepositoryForRisk()
        let riskRepository = StubRiskLexiconRepository()
        riskRepository.stubbedLexicon = lexicon
        let viewModel = ChatViewModel(
            sendMessageUseCase: SendMessageUseCase(conversationRepository: repository),
            getMessagesUseCase: GetMessagesUseCase(conversationRepository: repository),
            endConversationUseCase: EndConversationUseCase(conversationRepository: repository),
            createCardUseCase: CreateCardUseCase(cardRepository: MockCardRepositoryForRisk()),
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: MockMemberRepositoryForRisk()),
            updateConversationTitleUseCase: UpdateConversationTitleUseCase(conversationRepository: repository),
            detectRiskInTextUseCase: DetectRiskInTextUseCase(repository: riskRepository),
            summaryStore: MockConversationSummaryStoreForRisk()
        )
        return (viewModel, repository)
    }

    private let criticalLexicon = RiskLexicon(
        version: 1,
        terms: [RiskTerm(term: "자살", level: .critical)],
        safePhrases: [],
        agencies: [SupportAgency(id: "a", name: "자살예방", description: "", phoneNumber: "109", url: nil, priority: 1, isEmergency: false)]
    )

    private let warningLexicon = RiskLexicon(
        version: 1,
        terms: [RiskTerm(term: "살기싫", level: .warning)],
        safePhrases: [],
        agencies: [SupportAgency(id: "a", name: "자살예방", description: "", phoneNumber: "109", url: nil, priority: 1, isEmergency: false)]
    )

    func test_send_criticalText_blocksSendAndKeepsInput() async {
        let (viewModel, repository) = makeViewModel(lexicon: criticalLexicon)
        viewModel.input = "자살하고싶다"

        await viewModel.send()

        XCTAssertEqual(viewModel.input, "자살하고싶다")
        XCTAssertEqual(repository.sendCallCount, 0)
        XCTAssertEqual(viewModel.riskDetection?.level, .critical)
    }

    func test_send_warningText_showsDialogAndStillSends() async {
        let (viewModel, repository) = makeViewModel(lexicon: warningLexicon)
        repository.stubbedSendResult = .success(SentMessage(
            message: Message(id: 1, conversationId: 1, sender: .user, content: "살기싫다", repliesToMessageId: nil, createdAt: Date()),
            commentStatus: .done,
            comments: []
        ))
        viewModel.input = "살기싫다"

        await viewModel.send()

        XCTAssertEqual(repository.sendCallCount, 1)
        XCTAssertEqual(viewModel.riskDetection?.level, .warning)
    }

    func test_send_noRiskText_doesNotShowDialog() async {
        let (viewModel, repository) = makeViewModel(lexicon: criticalLexicon)
        repository.stubbedSendResult = .success(SentMessage(
            message: Message(id: 1, conversationId: 1, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date()),
            commentStatus: .done,
            comments: []
        ))
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertNil(viewModel.riskDetection)
        XCTAssertEqual(repository.sendCallCount, 1)
    }

    func test_send_setsIsSendingSynchronouslyBeforeRiskCheckAwaits() async {
        let repository = MockConversationRepositoryForRisk()
        let gatedRiskRepository = GatedRiskLexiconRepository(lexicon: .empty)
        let viewModel = ChatViewModel(
            sendMessageUseCase: SendMessageUseCase(conversationRepository: repository),
            getMessagesUseCase: GetMessagesUseCase(conversationRepository: repository),
            endConversationUseCase: EndConversationUseCase(conversationRepository: repository),
            createCardUseCase: CreateCardUseCase(cardRepository: MockCardRepositoryForRisk()),
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: MockMemberRepositoryForRisk()),
            updateConversationTitleUseCase: UpdateConversationTitleUseCase(conversationRepository: repository),
            detectRiskInTextUseCase: DetectRiskInTextUseCase(repository: gatedRiskRepository),
            summaryStore: MockConversationSummaryStoreForRisk()
        )
        viewModel.input = "안녕"

        let sendTask = Task { await viewModel.send() }
        while !viewModel.isSending {
            await Task.yield()
        }
        XCTAssertTrue(viewModel.isSending)

        await gatedRiskRepository.open()
        await sendTask.value
    }
}

private final class MockConversationRepositoryForRisk: ConversationRepository {
    var stubbedSendResult: Result<SentMessage, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var sendCallCount = 0

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        sendCallCount += 1
        return try stubbedSendResult.get()
    }

    func getMessages(conversationId: Int) async throws -> [Message] { [] }
    func getIncompleteConversations() async throws -> [ConversationSummary] { [] }
    func updateTitle(conversationId: Int, title: String) async throws {}
    func endConversation(conversationId: Int) async throws {}
    func deleteConversations(_ ids: [Int]) async throws {}
    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage {
        fatalError("사용 안 함")
    }
}

private final class MockCardRepositoryForRisk: CardRepository {
    func createCard(conversationId: Int, emotion: EmotionCharacter?, summary: String) async throws -> Card {
        fatalError("사용 안 함")
    }
    func getCard(cardId: Int) async throws -> Card { fatalError("사용 안 함") }
    func deleteCard(cardId: Int) async throws {}
    func fetchCardsByDate(yearMonth: Date, emotion: Emotion) async throws -> [DailyEmotion] {
        fatalError("사용 안 함")
    }
    func deleteAllCard() async throws {}
}

private final class MockMemberRepositoryForRisk: MemberRepository {
    func deleteMember() async throws {}
    func fetchMyProfile() async throws -> User { fatalError("사용 안 함") }
    func updateNickname(_ nickname: String) async throws -> User { fatalError("사용 안 함") }
    func fetchTokenUsage() async throws -> TokenUsage { fatalError("사용 안 함") }
}

private actor MockConversationSummaryStoreForRisk: ConversationSummaryStore {
    func add(_ utterance: String) async {}
    func current() async -> String? { nil }
    func reset() async {}
    func restore(historicalUtterances: [String]) async {}
}
