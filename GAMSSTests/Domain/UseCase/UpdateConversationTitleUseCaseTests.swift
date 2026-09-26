//
//  UpdateConversationTitleUseCaseTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/14/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var stubbedUpdateTitleResult: Result<Void, Error> = .success(())
    private(set) var receivedConversationId: Int?
    private(set) var receivedTitle: String?

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
        receivedConversationId = conversationId
        receivedTitle = title
        _ = try stubbedUpdateTitleResult.get()
    }

    func endConversation(conversationId: Int) async throws {
        fatalError("not used in this test")
    }

    func deleteConversations(_ ids: [Int]) async throws {
        fatalError("not used in this test")
    }

    func searchConversations(_ text: String) async throws -> SearchChatResponseDTO {
        fatalError("not used in this test")
    }
}

final class UpdateConversationTitleUseCaseTests: XCTestCase {
    func test_execute_passesConversationIdAndTitleThrough() async throws {
        let repository = MockConversationRepository()
        let useCase = UpdateConversationTitleUseCase(conversationRepository: repository)

        try await useCase.execute(conversationId: 10, title: "안녕")

        XCTAssertEqual(repository.receivedConversationId, 10)
        XCTAssertEqual(repository.receivedTitle, "안녕")
    }

    func test_execute_truncatesTitleExceedingMaxLength() async throws {
        let repository = MockConversationRepository()
        let useCase = UpdateConversationTitleUseCase(conversationRepository: repository)
        let longTitle = String(repeating: "가", count: 139)

        try await useCase.execute(conversationId: 10, title: longTitle)

        XCTAssertEqual(repository.receivedTitle?.count, UpdateConversationTitleUseCase.maxTitleLength)
        XCTAssertEqual(repository.receivedTitle, String(longTitle.prefix(UpdateConversationTitleUseCase.maxTitleLength)))
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockConversationRepository()
        repository.stubbedUpdateTitleResult = .failure(SummaryError.inferenceFailed())
        let useCase = UpdateConversationTitleUseCase(conversationRepository: repository)

        do {
            try await useCase.execute(conversationId: 10, title: "안녕")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SummaryError, .inferenceFailed())
        }
    }
}
