//
//  SendMessageUseCaseTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/7/26.
//

import XCTest
@testable import GAMSS

private final class MockConversationRepository: ConversationRepository {
    var stubbedSendResult: Result<SentMessage, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var receivedConversationId: Int?
    private(set) var receivedContent: String?
    private(set) var receivedRepliesToMessageId: Int?
    private(set) var receivedContextSummary: String?
    private(set) var receivedExcludedCharacters: Set<EmotionCharacter>?
    private(set) var sendCallCount = 0

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        sendCallCount += 1
        receivedConversationId = conversationId
        receivedContent = content
        receivedRepliesToMessageId = repliesToMessageId
        receivedContextSummary = contextSummary
        receivedExcludedCharacters = excludedCharacters
        return try stubbedSendResult.get()
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
        fatalError("not used in this test")
    }

    func deleteConversations(_ ids: [Int]) async throws {
        fatalError("not used in this test")
    }

    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage {
        fatalError("not used in this test")
    }
}

final class SendMessageUseCaseTests: XCTestCase {
    func test_execute_passesAllParametersThrough() async throws {
        let repository = MockConversationRepository()
        let sent = SentMessage(
            message: Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done,
            comments: []
        )
        repository.stubbedSendResult = .success(sent)
        let useCase = SendMessageUseCase(conversationRepository: repository)

        let result = try await useCase.execute(conversationId: 10, content: "안녕", repliesToMessageId: 5, contextSummary: "압축본", excludedCharacters: [])

        XCTAssertEqual(result, sent)
        XCTAssertEqual(repository.receivedConversationId, 10)
        XCTAssertEqual(repository.receivedContent, "안녕")
        XCTAssertEqual(repository.receivedRepliesToMessageId, 5)
        XCTAssertEqual(repository.receivedContextSummary, "압축본")
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(SummaryError.inferenceFailed())
        let useCase = SendMessageUseCase(conversationRepository: repository)

        do {
            _ = try await useCase.execute(conversationId: nil, content: "안녕", repliesToMessageId: nil, contextSummary: nil, excludedCharacters: [])
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SummaryError, .inferenceFailed())
        }
    }

    func test_execute_blankContent_throwsEmptyWithoutCallingRepository() async {
        let repository = MockConversationRepository()
        let useCase = SendMessageUseCase(conversationRepository: repository)

        do {
            _ = try await useCase.execute(conversationId: nil, content: "   ", repliesToMessageId: nil, contextSummary: nil, excludedCharacters: [])
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SendMessageValidationError, .empty)
        }
        XCTAssertEqual(repository.sendCallCount, 0, "검증에 실패하면 네트워크 호출까지 가면 안 됨")
    }

    func test_execute_contentOverMaxLength_throwsTooLongWithoutCallingRepository() async {
        let repository = MockConversationRepository()
        let useCase = SendMessageUseCase(conversationRepository: repository)
        let overLong = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 1)

        do {
            _ = try await useCase.execute(conversationId: nil, content: overLong, repliesToMessageId: nil, contextSummary: nil, excludedCharacters: [])
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SendMessageValidationError, .tooLong)
        }
        XCTAssertEqual(repository.sendCallCount, 0, "검증에 실패하면 네트워크 호출까지 가면 안 됨")
    }

    func test_execute_contentAtMaxLength_isAllowed() async throws {
        let repository = MockConversationRepository()
        let sent = SentMessage(
            message: Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done,
            comments: []
        )
        repository.stubbedSendResult = .success(sent)
        let useCase = SendMessageUseCase(conversationRepository: repository)
        let exact = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength)

        _ = try await useCase.execute(conversationId: nil, content: exact, repliesToMessageId: nil, contextSummary: nil, excludedCharacters: [])

        XCTAssertEqual(repository.sendCallCount, 1)
    }

    func test_execute_passesExcludedCharactersThrough() async throws {
        let repository = MockConversationRepository()
        let sent = SentMessage(
            message: Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done,
            comments: []
        )
        repository.stubbedSendResult = .success(sent)
        let useCase = SendMessageUseCase(conversationRepository: repository)

        _ = try await useCase.execute(conversationId: nil, content: "안녕", repliesToMessageId: nil, contextSummary: nil, excludedCharacters: [.anger, .joy])

        XCTAssertEqual(repository.receivedExcludedCharacters, [.anger, .joy])
    }
}
