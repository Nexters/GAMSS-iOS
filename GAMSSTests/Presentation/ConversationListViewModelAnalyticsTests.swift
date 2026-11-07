//
//  ConversationListViewModelAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var searchResult: Result<ConversationPage, Error> = .failure(NetworkError.noConnection)
    var deleteError: Error?

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        fatalError("not used in this test")
    }
    func getMessages(conversationId: Int) async throws -> [Message] { fatalError("not used in this test") }
    func getIncompleteConversations() async throws -> [ConversationSummary] { [] }
    func updateTitle(conversationId: Int, title: String) async throws { fatalError("not used in this test") }
    func endConversation(conversationId: Int) async throws { fatalError("not used in this test") }
    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage {
        try searchResult.get()
    }
    func deleteConversations(_ ids: [Int]) async throws {
        if let deleteError { throw deleteError }
    }
}

private final class MockAnalyticsTracking: AnalyticsTracking {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func trackScreen(_ screen: AnalyticsScreen) {}
}

@MainActor
final class ConversationListViewModelAnalyticsTests: XCTestCase {
    private func makeViewModel(
        conversationRepository: MockConversationRepository,
        analyticsTracker: MockAnalyticsTracking
    ) -> ConversationListViewModel {
        ConversationListViewModel(
            getIncompleteConversationsUseCase: GetIncompleteConversationsUseCase(conversationRepository: conversationRepository),
            deleteConversationsUseCase: DefaultDeleteConversationsUseCase(conversationRepository: conversationRepository),
            searchConversationUseCase: DefaultSearchConversationUseCase(conversationRepository: conversationRepository),
            analyticsTracker: analyticsTracker
        )
    }

    func test_searchText_onSuccess_tracksChatSearch() async {
        let repository = MockConversationRepository()
        repository.searchResult = .success(ConversationPage(items: [], page: 0, size: 10, totalPages: 1))
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = makeViewModel(conversationRepository: repository, analyticsTracker: analyticsTracker)
        viewModel.editedText = "안녕"

        await viewModel.searchText()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_search"])
    }

    func test_searchText_belowMinimumLength_doesNotTrack() async {
        let repository = MockConversationRepository()
        repository.searchResult = .failure(ConversationError.invalidSearchKeyword)
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = makeViewModel(conversationRepository: repository, analyticsTracker: analyticsTracker)
        viewModel.editedText = "a"

        await viewModel.searchText()

        XCTAssertTrue(analyticsTracker.trackedEvents.isEmpty)
    }

    func test_deleteConversations_onSuccess_tracksChatDeleteConfirm() async {
        let repository = MockConversationRepository()
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = makeViewModel(conversationRepository: repository, analyticsTracker: analyticsTracker)

        await viewModel.deleteConversations()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["chat_delete_confirm"])
    }
}
