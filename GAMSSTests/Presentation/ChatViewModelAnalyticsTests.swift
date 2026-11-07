//
//  ChatViewModelAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var sendMessageResult: Result<SentMessage, Error> = .failure(SendMessageValidationError.empty)

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        try sendMessageResult.get()
    }
    func getMessages(conversationId: Int) async throws -> [Message] { fatalError("not used in this test") }
    func getIncompleteConversations() async throws -> [ConversationSummary] { fatalError("not used in this test") }
    func updateTitle(conversationId: Int, title: String) async throws {}
    func endConversation(conversationId: Int) async throws {}
    func deleteConversations(_ ids: [Int]) async throws { fatalError("not used in this test") }
    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage { fatalError("not used in this test") }
}

private final class MockCardRepository: CardRepository {
    func createCard(conversationId: Int, emotion: EmotionCharacter?, summary: String) async throws -> Card {
        fatalError("not used in this test")
    }
    func getCard(cardId: Int) async throws -> Card { fatalError("not used in this test") }
    func deleteCard(cardId: Int) async throws { fatalError("not used in this test") }
    func fetchCardsByDate(yearMonth: Date, emotion: Emotion) async throws -> [DailyEmotion] { fatalError("not used in this test") }
    func deleteAllCard() async throws { fatalError("not used in this test") }
}

private final class MockMemberRepository: MemberRepository {
    func deleteMember() async throws { fatalError("not used in this test") }
    func fetchMyProfile() async throws -> User { fatalError("not used in this test") }
    func updateNickname(_ nickname: String) async throws -> User { fatalError("not used in this test") }
    func fetchTokenUsage() async throws -> TokenUsage { fatalError("not used in this test") }
}

private final class MockRiskLexiconRepository: RiskLexiconRepository {
    var lexicon = RiskLexicon.empty

    func currentLexicon() async -> RiskLexicon { lexicon }
    func refresh() async {}
}

private final class MockAnalyticsTracking: AnalyticsTracking {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func trackScreen(_ screen: AnalyticsScreen) {}
}

@MainActor
final class ChatViewModelAnalyticsTests: XCTestCase {
    private func makeViewModel(
        conversationRepository: MockConversationRepository,
        riskLexiconRepository: MockRiskLexiconRepository = MockRiskLexiconRepository(),
        analyticsTracker: MockAnalyticsTracking
    ) -> ChatViewModel {
        ChatViewModel(
            sendMessageUseCase: SendMessageUseCase(conversationRepository: conversationRepository),
            getMessagesUseCase: GetMessagesUseCase(conversationRepository: conversationRepository),
            endConversationUseCase: EndConversationUseCase(conversationRepository: conversationRepository),
            createCardUseCase: CreateCardUseCase(cardRepository: MockCardRepository()),
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: MockMemberRepository()),
            updateConversationTitleUseCase: UpdateConversationTitleUseCase(conversationRepository: conversationRepository),
            detectRiskInTextUseCase: DetectRiskInTextUseCase(repository: riskLexiconRepository),
            summaryStore: LazyConversationSummaryStore(),
            conversationId: 1,
            analyticsTracker: analyticsTracker
        )
    }

    func test_send_onSuccess_tracksChatSend() async {
        let analyticsTracker = MockAnalyticsTracking()
        let repository = MockConversationRepository()
        let sentMessage = SentMessage(
            message: Message(id: 1, conversationId: 1, sender: .user, content: "hi", repliesToMessageId: nil, createdAt: Date()),
            commentStatus: .done,
            comments: []
        )
        repository.sendMessageResult = .success(sentMessage)
        let viewModel = makeViewModel(conversationRepository: repository, analyticsTracker: analyticsTracker)
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_send"])
    }

    func test_send_whenBlocked_tracksChatSendBlocked() async {
        let analyticsTracker = MockAnalyticsTracking()
        let riskLexiconRepository = MockRiskLexiconRepository()
        riskLexiconRepository.lexicon = RiskLexicon(
            version: 1,
            terms: [RiskTerm(term: "위험", level: .critical)],
            safePhrases: [],
            agencies: []
        )
        let viewModel = makeViewModel(
            conversationRepository: MockConversationRepository(),
            riskLexiconRepository: riskLexiconRepository,
            analyticsTracker: analyticsTracker
        )
        viewModel.input = "위험한 말"

        await viewModel.send()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_send_blocked"])
    }

    func test_send_onNetworkFailure_tracksChatSendFail() async {
        let analyticsTracker = MockAnalyticsTracking()
        let repository = MockConversationRepository()
        repository.sendMessageResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(conversationRepository: repository, analyticsTracker: analyticsTracker)
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_send_fail"])
    }
}
