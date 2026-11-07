//
//  ChatViewModelEndConversationAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var endConversationError: Error?

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        fatalError("not used in this test")
    }
    func getMessages(conversationId: Int) async throws -> [Message] { fatalError("not used in this test") }
    func getIncompleteConversations() async throws -> [ConversationSummary] { fatalError("not used in this test") }
    func updateTitle(conversationId: Int, title: String) async throws {}
    func endConversation(conversationId: Int) async throws {
        if let endConversationError { throw endConversationError }
    }
    func deleteConversations(_ ids: [Int]) async throws { fatalError("not used in this test") }
    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage { fatalError("not used in this test") }
}

private final class MockCardRepository: CardRepository {
    var createCardResult: Result<Card, Error> = .failure(NetworkError.noConnection)

    func createCard(conversationId: Int, emotion: EmotionCharacter?, summary: String) async throws -> Card {
        try createCardResult.get()
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
    func currentLexicon() async -> RiskLexicon { .empty }
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
final class ChatViewModelEndConversationAnalyticsTests: XCTestCase {
    private func makeViewModel(
        conversationRepository: MockConversationRepository = MockConversationRepository(),
        cardRepository: MockCardRepository = MockCardRepository(),
        analyticsTracker: MockAnalyticsTracking
    ) -> ChatViewModel {
        return ChatViewModel(
            sendMessageUseCase: SendMessageUseCase(conversationRepository: conversationRepository),
            getMessagesUseCase: GetMessagesUseCase(conversationRepository: conversationRepository),
            endConversationUseCase: EndConversationUseCase(conversationRepository: conversationRepository),
            createCardUseCase: CreateCardUseCase(cardRepository: cardRepository),
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: MockMemberRepository()),
            updateConversationTitleUseCase: UpdateConversationTitleUseCase(conversationRepository: conversationRepository),
            detectRiskInTextUseCase: DetectRiskInTextUseCase(repository: MockRiskLexiconRepository()),
            summaryStore: LazyConversationSummaryStore(),
            conversationId: 1,
            analyticsTracker: analyticsTracker
        )
    }

    func test_requestEndConversation_whenAllowed_tracksChatEndRequest() {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = makeViewModel(analyticsTracker: analyticsTracker)

        viewModel.requestEndConversation()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_end_request"])
    }

    func test_cancelEndConfirmation_tracksChatEndCancelAndDismisses() {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = makeViewModel(analyticsTracker: analyticsTracker)
        viewModel.requestEndConversation()

        viewModel.cancelEndConfirmation()

        XCTAssertFalse(viewModel.isEndConfirmationPresented)
        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_end_request", "chat_end_cancel"])
    }

    func test_confirmEndConversation_onCardCreateSuccess_tracksChatEndConfirmAndCardCreateSuccess() async {
        let analyticsTracker = MockAnalyticsTracking()
        let cardRepository = MockCardRepository()
        cardRepository.createCardResult = .success(Card(id: 1, conversationId: 1, emotion: .joy, summary: "요약", message: "메시지", date: Date()))
        let viewModel = makeViewModel(cardRepository: cardRepository, analyticsTracker: analyticsTracker)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_end_confirm", "card_create_success"])
    }

    func test_confirmEndConversation_onCardCreateFailure_tracksChatEndConfirmAndCardCreateFail() async {
        let analyticsTracker = MockAnalyticsTracking()
        let cardRepository = MockCardRepository()
        cardRepository.createCardResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(cardRepository: cardRepository, analyticsTracker: analyticsTracker)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_end_confirm", "card_create_fail"])
    }

    func test_confirmEndConversation_whenEndConversationFails_tracksOnlyChatEndConfirm() async {
        let analyticsTracker = MockAnalyticsTracking()
        let conversationRepository = MockConversationRepository()
        conversationRepository.endConversationError = NetworkError.noConnection
        let viewModel = makeViewModel(conversationRepository: conversationRepository, analyticsTracker: analyticsTracker)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_end_confirm"])
    }
}
