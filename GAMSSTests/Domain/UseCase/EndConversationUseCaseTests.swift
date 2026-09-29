//
//  EndConversationUseCaseTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/15/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var stubbedEndConversationResult: Result<Void, Error> = .success(())
    private(set) var receivedConversationId: Int?

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        fatalError("not used in this test")
    }

    func getMessages(conversationId: Int) async throws -> [Message] {
        []
    }

    func getIncompleteConversations() async throws -> [ConversationSummary] {
        []
    }

    func updateTitle(conversationId: Int, title: String) async throws {
        fatalError("not used in this test")
    }

    func endConversation(conversationId: Int) async throws {
        receivedConversationId = conversationId
        _ = try stubbedEndConversationResult.get()
    }

    func deleteConversations(_ ids: [Int]) async throws {
        fatalError("not used in this test")
    }

    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage {
        fatalError("not used in this test")
    }
}

final class EndConversationUseCaseTests: XCTestCase {
    func test_execute_passesConversationIdThrough() async throws {
        let repository = MockConversationRepository()
        let useCase = EndConversationUseCase(conversationRepository: repository)

        try await useCase.execute(conversationId: 10)

        XCTAssertEqual(repository.receivedConversationId, 10)
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockConversationRepository()
        repository.stubbedEndConversationResult = .failure(SummaryError.inferenceFailed())
        let useCase = EndConversationUseCase(conversationRepository: repository)

        do {
            try await useCase.execute(conversationId: 10)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SummaryError, .inferenceFailed())
        }
    }
}
