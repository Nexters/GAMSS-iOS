//
//  ConversationHistoryViewModelTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/17/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var stubbedMessagesResult: Result<[Message], Error> = .success([])
    private(set) var receivedConversationIds: [Int] = []

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        fatalError("사용 안 함")
    }

    func getMessages(conversationId: Int) async throws -> [Message] {
        receivedConversationIds.append(conversationId)
        return try stubbedMessagesResult.get()
    }

    func getIncompleteConversations() async throws -> [ConversationSummary] {
        fatalError("사용 안 함")
    }

    func updateTitle(conversationId: Int, title: String) async throws {
        fatalError("사용 안 함")
    }

    func endConversation(conversationId: Int) async throws {
        fatalError("사용 안 함")
    }

    func deleteConversations(_ ids: [Int]) async throws {
        fatalError("사용 안 함")
    }

    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage {
        fatalError("사용 안 함")
    }
}

@MainActor
final class ConversationHistoryViewModelTests: XCTestCase {
    private func makeViewModel(repository: MockConversationRepository) -> ConversationHistoryViewModel {
        ConversationHistoryViewModel(getMessagesUseCase: GetMessagesUseCase(conversationRepository: repository))
    }

    func test_loadMessagesIfNeeded_onSuccess_setsMessagesAndClearsLoading() async {
        let repository = MockConversationRepository()
        let messages = [
            Message(id: 1, conversationId: 10, sender: .character(.sadness), content: "오늘 하루 어땠어?", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            Message(id: 2, conversationId: 10, sender: .user, content: "그냥 그랬어", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 60))
        ]
        repository.stubbedMessagesResult = .success(messages)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadMessagesIfNeeded(conversationId: 10)

        XCTAssertEqual(viewModel.messages, messages)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.alertMessage)
        XCTAssertEqual(repository.receivedConversationIds, [10])
    }

    func test_loadMessagesIfNeeded_onFailure_setsAlertMessage() async {
        let repository = MockConversationRepository()
        repository.stubbedMessagesResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadMessagesIfNeeded(conversationId: 10)

        XCTAssertEqual(viewModel.alertMessage, "대화를 불러오지 못했어요")
        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_loadMessagesIfNeeded_calledTwiceWithSameConversationId_doesNotRefetch() async {
        let repository = MockConversationRepository()
        repository.stubbedMessagesResult = .success([
            Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        ])
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadMessagesIfNeeded(conversationId: 10)
        await viewModel.loadMessagesIfNeeded(conversationId: 10)

        XCTAssertEqual(repository.receivedConversationIds, [10])
    }

    func test_retryLoad_resetsCacheAndRefetches() async {
        let repository = MockConversationRepository()
        repository.stubbedMessagesResult = .success([
            Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        ])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadMessagesIfNeeded(conversationId: 10)

        await viewModel.retryLoad(conversationId: 10)

        XCTAssertEqual(repository.receivedConversationIds, [10, 10])
    }

    func test_quotedMessage_returnsMatchingMessage() async {
        let repository = MockConversationRepository()
        let original = Message(id: 1, conversationId: 10, sender: .character(.sadness), content: "오늘 하루 어땠어?", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let reply = Message(id: 2, conversationId: 10, sender: .user, content: "그냥 그랬어", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 60))
        repository.stubbedMessagesResult = .success([original, reply])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadMessagesIfNeeded(conversationId: 10)

        XCTAssertEqual(viewModel.quotedMessage(for: reply), original)
    }

    func test_quotedMessage_returnsNilWhenMessageHasNoReply() async {
        let repository = MockConversationRepository()
        let message = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedMessagesResult = .success([message])
        let viewModel = makeViewModel(repository: repository)
        await viewModel.loadMessagesIfNeeded(conversationId: 10)

        XCTAssertNil(viewModel.quotedMessage(for: message))
    }

    func test_canShowConversation_onSuccess_returnsTrueAndPreloadsMessages() async {
        let repository = MockConversationRepository()
        let messages = [
            Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        ]
        repository.stubbedMessagesResult = .success(messages)
        let viewModel = makeViewModel(repository: repository)

        let canShow = await viewModel.canShowConversation(conversationId: 10)

        XCTAssertTrue(canShow)
        XCTAssertEqual(viewModel.messages, messages)
    }

    func test_canShowConversation_onSuccess_avoidsRefetchWhenScreenLoads() async {
        let repository = MockConversationRepository()
        repository.stubbedMessagesResult = .success([
            Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        ])
        let viewModel = makeViewModel(repository: repository)
        _ = await viewModel.canShowConversation(conversationId: 10)

        await viewModel.loadMessagesIfNeeded(conversationId: 10)

        XCTAssertEqual(repository.receivedConversationIds, [10], "미리 불러온 게 있으면 화면 진입 후 다시 조회하면 안 됨")
    }

    func test_canShowConversation_onNetworkFailure_returnsFalseWithoutSettingAlert() async {
        let repository = MockConversationRepository()
        repository.stubbedMessagesResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(repository: repository)

        let canShow = await viewModel.canShowConversation(conversationId: 10)

        XCTAssertFalse(canShow)
        XCTAssertNil(viewModel.alertMessage, "네트워크 끊김은 화면 전환을 막는 것으로 안내하므로 alertMessage를 쓰지 않아야 함")
    }

    func test_canShowConversation_onNonNetworkFailure_returnsTrueSoScreenStillTransitions() async {
        let repository = MockConversationRepository()
        repository.stubbedMessagesResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)

        let canShow = await viewModel.canShowConversation(conversationId: 10)

        XCTAssertTrue(canShow, "네트워크 문제가 아니면 기존처럼 화면을 넘겨 그 화면의 alertMessage로 안내해야 함")
    }
}
