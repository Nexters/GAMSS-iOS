//
//  GetMessagesUseCaseTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/7/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var stubbedMessages: [Message] = []
    private(set) var receivedConversationId: Int?

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        fatalError("not used in this test")
    }

    func getMessages(conversationId: Int) async throws -> [Message] {
        receivedConversationId = conversationId
        return stubbedMessages
    }

    func getIncompleteConversations() async throws -> [ConversationSummary] {
        []
    }

    func updateTitle(conversationId: Int, title: String) async throws {
        fatalError("not used in this test")
    }

    func endConversation(conversationId: Int) async throws {
        fatalError("not used in this test")
    }

    func deleteConversations(_ ids: [Int]) async throws {
        fatalError("not used in this test")
    }

    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage {
        fatalError("not used in this test")
    }
}

final class GetMessagesUseCaseTests: XCTestCase {
    func test_execute_returnsMessagesFromRepository() async throws {
        let repository = MockConversationRepository()
        repository.stubbedMessages = [
            Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0)),
        ]
        let useCase = GetMessagesUseCase(conversationRepository: repository)

        let result = try await useCase.execute(conversationId: 10)

        XCTAssertEqual(result, repository.stubbedMessages)
        XCTAssertEqual(repository.receivedConversationId, 10)
    }
}
