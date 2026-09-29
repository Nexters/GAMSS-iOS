//
//  ChatViewModelTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/7/26.
//

import XCTest
@testable import GAMSS

/// 테스트에서 send()가 네트워크 응답을 받기 전 상태(펜딩 사용자 메시지, 입력창 비움 등)를
/// 검증할 수 있도록, sendMessage 반환을 원하는 시점까지 붙잡아두는 게이트.
private actor SendGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}

private final class MockMemberRepository: MemberRepository {
    var stubbedTokenUsageResult: Result<TokenUsage, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var fetchTokenUsageCallCount = 0

    func deleteMember() async throws { fatalError("not used in this test") }
    func fetchMyProfile() async throws -> User { fatalError("not used in this test") }
    func updateNickname(_ nickname: String) async throws -> User { fatalError("not used in this test") }

    func fetchTokenUsage() async throws -> TokenUsage {
        fetchTokenUsageCallCount += 1
        return try stubbedTokenUsageResult.get()
    }
}

private final class MockConversationRepository: ConversationRepository {
    var stubbedSendResult: Result<SentMessage, Error> = .failure(SummaryError.inferenceFailed())
    var stubbedMessages: [Message] = []
    var stubbedGetMessagesResult: Result<[Message], Error>?
    var sendGate: SendGate?
    var stubbedEndConversationResult: Result<Void, Error> = .success(())
    private(set) var sendCallCount = 0
    private(set) var getMessagesCallCount = 0
    private(set) var endConversationCallCount = 0
    private(set) var receivedContextSummary: String?
    private(set) var receivedExcludedCharacters: Set<EmotionCharacter>?
    private(set) var receivedRepliesToMessageId: Int?
    private(set) var receivedEndConversationId: Int?
    var stubbedUpdateTitleResult: Result<Void, Error> = .success(())
    private(set) var updateTitleCallCount = 0
    private(set) var receivedTitleConversationId: Int?
    private(set) var receivedTitle: String?

    func sendMessage(conversationId: Int?, content: String, repliesToMessageId: Int?, contextSummary: String?, excludedCharacters: Set<EmotionCharacter>) async throws -> SentMessage {
        sendCallCount += 1
        receivedContextSummary = contextSummary
        receivedExcludedCharacters = excludedCharacters
        receivedRepliesToMessageId = repliesToMessageId
        await sendGate?.wait()
        return try stubbedSendResult.get()
    }

    func getMessages(conversationId: Int) async throws -> [Message] {
        getMessagesCallCount += 1
        if let stubbedGetMessagesResult {
            return try stubbedGetMessagesResult.get()
        }
        return stubbedMessages
    }

    func getIncompleteConversations() async throws -> [ConversationSummary] {
        []
    }

    func updateTitle(conversationId: Int, title: String) async throws {
        updateTitleCallCount += 1
        receivedTitleConversationId = conversationId
        receivedTitle = title
        _ = try stubbedUpdateTitleResult.get()
    }

    func endConversation(conversationId: Int) async throws {
        endConversationCallCount += 1
        receivedEndConversationId = conversationId
        _ = try stubbedEndConversationResult.get()
    }

    func deleteConversations(_ ids: [Int]) async throws {
        fatalError("not used in this test")
    }

    func searchConversations(_ text: String, page: Int, size: Int) async throws -> ConversationPage {
        fatalError("not used in this test")
    }
}

private final class MockCardRepository: CardRepository {
    var stubbedResult: Result<Card, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var createCardCallCount = 0
    private(set) var receivedConversationId: Int?
    private(set) var receivedEmotion: EmotionCharacter?
    private(set) var receivedSummary: String?

    func createCard(conversationId: Int, emotion: EmotionCharacter?, summary: String) async throws -> Card {
        createCardCallCount += 1
        receivedConversationId = conversationId
        receivedEmotion = emotion
        receivedSummary = summary
        return try stubbedResult.get()
    }

    func getCard(cardId: Int) async throws -> Card {
        fatalError("사용 안 함")
    }

    func deleteCard(cardId: Int) async throws {
        fatalError("사용 안 함")
    }

    func fetchCardsByDate(yearMonth: Date, emotion: Emotion) async throws -> [DailyEmotion] {
        fatalError("사용 안 함")
    }

    func deleteAllCard() async throws {
        fatalError("사용 안 함")
    }
}

private actor MockConversationSummaryStore: ConversationSummaryStore {
    private(set) var addedUtterances: [String] = []
    private(set) var restoredHistories: [[String]] = []
    nonisolated(unsafe) var stubbedCurrent: String?

    func add(_ utterance: String) async { addedUtterances.append(utterance) }
    func current() async -> String? { stubbedCurrent }
    func reset() async {}
    func restore(historicalUtterances: [String]) async { restoredHistories.append(historicalUtterances) }
}

@MainActor
final class ChatViewModelTests: XCTestCase {
    private func makeViewModel(
        repository: MockConversationRepository = MockConversationRepository(),
        cardRepository: MockCardRepository = MockCardRepository(),
        memberRepository: MockMemberRepository = MockMemberRepository(),
        riskLexiconRepository: RiskLexiconRepository = StubEmptyRiskLexiconRepository(),
        summaryStore: MockConversationSummaryStore = MockConversationSummaryStore(),
        conversationId: Int? = nil,
        pendingFirstMessage: PendingFirstMessage? = nil,
        initialDate: Date = Date()
    ) -> ChatViewModel {
        ChatViewModel(
            sendMessageUseCase: SendMessageUseCase(conversationRepository: repository),
            getMessagesUseCase: GetMessagesUseCase(conversationRepository: repository),
            endConversationUseCase: EndConversationUseCase(conversationRepository: repository),
            createCardUseCase: CreateCardUseCase(cardRepository: cardRepository),
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: memberRepository),
            updateConversationTitleUseCase: UpdateConversationTitleUseCase(conversationRepository: repository),
            detectRiskInTextUseCase: DetectRiskInTextUseCase(repository: riskLexiconRepository),
            summaryStore: summaryStore,
            conversationId: conversationId,
            pendingFirstMessage: pendingFirstMessage,
            initialDate: initialDate
        )
    }

    func test_conversationDate_whenInitialDateProvided_usesItInsteadOfWaitingForMessages() {
        let expectedDate = Date(timeIntervalSince1970: 1_000_000)
        let viewModel = makeViewModel(initialDate: expectedDate)

        XCTAssertEqual(viewModel.conversationDate, expectedDate)
    }

    func test_send_onSuccess_queuesAllCommentsForSequentialReveal() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment1 = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        let comment2 = Message(id: 3, conversationId: 10, sender: .character(.sadness), content: "오늘 어때?", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment1, comment2]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertEqual(viewModel.messages, [sentMessage], "첫 댓글도 즉시 붙이지 않고 순차 노출 큐로 넘어가야 함")
        XCTAssertEqual(viewModel.pendingComments, [comment1, comment2])
        XCTAssertEqual(viewModel.input, "")
        XCTAssertEqual(viewModel.nextReplyCharacter, .joy, "첫 댓글(comment1)의 발신자를 가리켜야 함")
    }

    func test_send_onSuccess_addsContentToSummaryStoreAfterUpdatingMessages() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "오늘 힘들었어", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))
        let summaryStore = MockConversationSummaryStore()
        let viewModel = makeViewModel(repository: repository, summaryStore: summaryStore)
        viewModel.input = "오늘 힘들었어"

        await viewModel.send()
        await viewModel.pendingSummaryUpdateTask?.value

        let added = await summaryStore.addedUtterances
        XCTAssertEqual(added, ["오늘 힘들었어"], "전송 성공한 사용자 발화만 압축 저장소에 추가되어야 함")
    }

    func test_send_onFailure_doesNotAddToSummaryStore() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(SummaryError.inferenceFailed())
        let summaryStore = MockConversationSummaryStore()
        let viewModel = makeViewModel(repository: repository, summaryStore: summaryStore)
        viewModel.input = "실패할 메시지"

        await viewModel.send()

        let added = await summaryStore.addedUtterances
        XCTAssertTrue(added.isEmpty, "전송 실패한 발화는 압축 저장소에 들어가면 안 됨")
    }

    func test_send_usesCurrentContextSummaryFromStore() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .success(SentMessage(
            message: Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done, comments: []
        ))
        let summaryStore = MockConversationSummaryStore()
        summaryStore.stubbedCurrent = "이전 압축본"
        let viewModel = makeViewModel(repository: repository, summaryStore: summaryStore)
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertEqual(repository.receivedContextSummary, "이전 압축본")
    }

    func test_send_commentStatusNotDone_keepsMessageAndSetsAlert() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .limitExceeded, comments: []))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertEqual(viewModel.messages, [sentMessage], "댓글 생성 실패해도 보낸 메시지는 화면에 유지되어야 함")
        XCTAssertNotNil(viewModel.alertMessage)
    }

    func test_send_contentTooLong_setsValidationAlertAndDoesNotCallRepository() async {
        let repository = MockConversationRepository()
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 1)

        await viewModel.send()

        XCTAssertEqual(repository.sendCallCount, 0, "최종 검증에 걸리면 네트워크 호출까지 가면 안 됨")
        XCTAssertEqual(viewModel.alertMessage, SendMessageValidationError.tooLong.errorDescription)
        XCTAssertNil(viewModel.nextReplyCharacter, "검증 실패로 응답 자체를 못 받으면 다음 발신자도 없어야 함")
    }

    func test_send_beforeNetworkResponds_showsPendingUserMessageAndClearsInput() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.pendingUserMessage?.content, "안녕")
        XCTAssertEqual(viewModel.input, "", "응답을 기다리지 않고 입력창이 바로 비워져야 함")
        XCTAssertTrue(viewModel.messages.isEmpty, "응답 전에는 확정 목록에 들어가면 안 됨")

        await gate.open()
        await sendTask.value

        XCTAssertNil(viewModel.pendingUserMessage)
        XCTAssertEqual(viewModel.messages, [sentMessage])
    }

    func test_send_onFailure_clearsPendingUserMessageAndRestoresInput() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "실패할 메시지"

        await viewModel.send()

        XCTAssertNil(viewModel.pendingUserMessage)
        XCTAssertEqual(viewModel.input, "실패할 메시지", "실패하면 작성 중이던 내용을 잃지 않도록 복원되어야 함")
        XCTAssertNotNil(viewModel.alertMessage)
    }

    func test_send_onNetworkFailure_setsNetworkUnreachableAndRestoresInput() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "끊길 메시지"

        await viewModel.send()

        XCTAssertTrue(viewModel.isNetworkUnreachable)
        XCTAssertEqual(viewModel.input, "끊길 메시지", "실패했으니 작성 중이던 내용을 잃지 않아야 함")
        XCTAssertNil(viewModel.pendingUserMessage)
        XCTAssertNil(viewModel.alertMessage, "네트워크 끊김은 알림창 대신 전용 화면으로 안내해야 함")
    }

    func test_send_onNetworkFailure_withReplyTarget_keepsReplyTarget() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(repository: repository)
        let replyTarget = Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.startReply(to: replyTarget)
        viewModel.input = "고마워"

        await viewModel.send()

        XCTAssertEqual(viewModel.replyTarget, replyTarget)
        XCTAssertTrue(viewModel.isNetworkUnreachable)
    }

    func test_send_onFailure_doesNotOverwriteInputIfUserTypedSomethingNewWhileSending() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        repository.stubbedSendResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "실패할 메시지"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        viewModel.input = "그 사이에 새로 입력한 메시지"
        await gate.open()
        await sendTask.value

        XCTAssertEqual(viewModel.input, "그 사이에 새로 입력한 메시지", "전송 실패 시점에 사용자가 이미 새 내용을 입력 중이었다면 그 내용을 덮어쓰면 안 됨")
        XCTAssertNil(viewModel.pendingUserMessage)
    }

    func test_startReply_characterMessage_setsReplyTarget() {
        let viewModel = makeViewModel()
        let characterMessage = Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))

        viewModel.startReply(to: characterMessage)

        XCTAssertEqual(viewModel.replyTarget, characterMessage)
    }

    func test_startReply_userMessage_isIgnored() {
        let viewModel = makeViewModel()
        let userMessage = Message(id: 5, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))

        viewModel.startReply(to: userMessage)

        XCTAssertNil(viewModel.replyTarget, "사용자 메시지는 답장 대상이 될 수 없음")
    }

    func test_cancelReply_clearsReplyTarget() {
        let viewModel = makeViewModel()
        viewModel.startReply(to: Message(id: 5, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)))

        viewModel.cancelReply()

        XCTAssertNil(viewModel.replyTarget)
    }

    func test_startReply_secondCharacterMessage_replacesReplyTarget() {
        let viewModel = makeViewModel()
        let first = Message(id: 5, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let second = Message(id: 6, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.startReply(to: first)

        viewModel.startReply(to: second)

        XCTAssertEqual(viewModel.replyTarget, second)
    }

    func test_send_withReplyTarget_passesRepliesToMessageIdAndClearsOnSuccess() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 2, conversationId: 10, sender: .user, content: "고마워", repliesToMessageId: 5, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))
        let viewModel = makeViewModel(repository: repository)
        viewModel.startReply(to: Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)))
        viewModel.input = "고마워"

        await viewModel.send()

        XCTAssertEqual(repository.receivedRepliesToMessageId, 5)
        XCTAssertNil(viewModel.replyTarget, "성공하면 답장 모드가 자동으로 꺼져야 함")
    }

    func test_send_withReplyTarget_onFailure_keepsReplyTarget() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)
        let replyTarget = Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.startReply(to: replyTarget)
        viewModel.input = "고마워"

        await viewModel.send()

        XCTAssertEqual(viewModel.replyTarget, replyTarget, "실패하면 답장 대상을 다시 고를 필요 없이 유지되어야 함")
    }

    func test_send_withReplyTarget_pendingUserMessageShowsQuoteImmediately() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        repository.stubbedSendResult = .success(SentMessage(
            message: Message(id: 2, conversationId: 10, sender: .user, content: "고마워", repliesToMessageId: 5, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done, comments: []
        ))
        let viewModel = makeViewModel(repository: repository)
        viewModel.startReply(to: Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)))
        viewModel.input = "고마워"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.pendingUserMessage?.quotedSenderLabel, "불안에게 답장")
        XCTAssertEqual(viewModel.pendingUserMessage?.quotedContent, "안녕하세용")

        await gate.open()
        await sendTask.value
    }

    func test_send_onSuccess_doesNotClearReplyTargetIfUserStartedNewReplyMidFlight() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        repository.stubbedSendResult = .success(SentMessage(
            message: Message(id: 2, conversationId: 10, sender: .user, content: "고마워", repliesToMessageId: 5, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done, comments: []
        ))
        let viewModel = makeViewModel(repository: repository)
        viewModel.startReply(to: Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)))
        viewModel.input = "고마워"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        let newTarget = Message(id: 6, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.startReply(to: newTarget)

        await gate.open()
        await sendTask.value

        XCTAssertEqual(viewModel.replyTarget, newTarget, "전송 성공 처리가 그 사이에 새로 고른 답장 대상을 지우면 안 됨")
    }

    func test_send_withReplyTarget_clearsReplyTargetImmediatelyBeforeNetworkResponds() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        repository.stubbedSendResult = .success(SentMessage(
            message: Message(id: 2, conversationId: 10, sender: .user, content: "고마워", repliesToMessageId: 5, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done, comments: []
        ))
        let viewModel = makeViewModel(repository: repository)
        viewModel.startReply(to: Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)))
        viewModel.input = "고마워"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        XCTAssertNil(viewModel.replyTarget, "감정 캐릭터의 응답을 기다리지 않고 답장 모드가 바로 꺼져야 함")

        await gate.open()
        await sendTask.value
    }

    func test_send_onFailure_doesNotRestoreReplyTargetIfUserStartedNewReplyMidFlight() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        repository.stubbedSendResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)
        viewModel.startReply(to: Message(id: 5, conversationId: 10, sender: .character(.anxiety), content: "안녕하세용", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)))
        viewModel.input = "고마워"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        let newTarget = Message(id: 6, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.startReply(to: newTarget)

        await gate.open()
        await sendTask.value

        XCTAssertEqual(viewModel.replyTarget, newTarget, "전송 실패 복원이 그 사이에 새로 고른 답장 대상을 덮어쓰면 안 됨")
    }

    func test_send_withoutReplyTarget_pendingUserMessageHasNoQuote() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        repository.stubbedSendResult = .success(SentMessage(
            message: Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            commentStatus: .done, comments: []
        ))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        XCTAssertNil(viewModel.pendingUserMessage?.quotedSenderLabel)
        XCTAssertNil(viewModel.pendingUserMessage?.quotedContent)

        await gate.open()
        await sendTask.value
    }

    func test_load_populatesMessagesAndRestoresSummaryStoreWithUserUtterancesOnly() async {
        let repository = MockConversationRepository()
        let userMessage = Message(id: 1, conversationId: 10, sender: .user, content: "사용자 발화", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let characterMessage = Message(id: 2, conversationId: 10, sender: .character(.sadness), content: "캐릭터 답장", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedMessages = [userMessage, characterMessage]
        let summaryStore = MockConversationSummaryStore()
        let viewModel = makeViewModel(repository: repository, summaryStore: summaryStore)

        await viewModel.load(conversationId: 10)

        XCTAssertEqual(viewModel.messages, [userMessage, characterMessage])
        let restored = await summaryStore.restoredHistories
        XCTAssertEqual(restored, [["사용자 발화"]], "재진입 복원은 사용자 발화만 summaryStore에 넘겨야 함")
    }

    func test_load_onNetworkFailure_setsNetworkUnreachable() async {
        let repository = MockConversationRepository()
        repository.stubbedGetMessagesResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load(conversationId: 10)

        XCTAssertTrue(viewModel.isNetworkUnreachable)
        XCTAssertNil(viewModel.alertMessage, "네트워크 끊김은 알림창 대신 전용 화면으로 안내해야 함")
    }

    func test_load_onNonNetworkFailure_doesNotSetNetworkUnreachable() async {
        let repository = MockConversationRepository()
        repository.stubbedGetMessagesResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)

        await viewModel.load(conversationId: 10)

        XCTAssertFalse(viewModel.isNetworkUnreachable)
        XCTAssertNotNil(viewModel.alertMessage)
    }

    func test_retryAfterNetworkFailure_afterLoadFailure_reloadsConversation() async {
        let repository = MockConversationRepository()
        repository.stubbedGetMessagesResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load(conversationId: 10)
        XCTAssertTrue(viewModel.isNetworkUnreachable, "사전 조건: 네트워크 끊김 상태여야 함")

        let userMessage = Message(id: 1, conversationId: 10, sender: .user, content: "복구됨", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedGetMessagesResult = .success([userMessage])

        await viewModel.retryAfterNetworkFailure()

        XCTAssertFalse(viewModel.isNetworkUnreachable)
        XCTAssertEqual(viewModel.messages, [userMessage])
        XCTAssertEqual(repository.getMessagesCallCount, 2, "처음 실패 + 재시도, 총 2번 호출되어야 함")
    }

    func test_retryAfterNetworkFailure_afterSendFailure_doesNotReloadConversationButResends() async {
        let repository = MockConversationRepository()
        let existingMessage = Message(id: 1, conversationId: 10, sender: .user, content: "기존 메시지", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedMessages = [existingMessage]
        let viewModel = makeViewModel(repository: repository)
        await viewModel.load(conversationId: 10)
        XCTAssertEqual(repository.getMessagesCallCount, 1, "사전 조건")

        repository.stubbedSendResult = .failure(NetworkError.noConnection)
        viewModel.input = "재전송할 메시지"
        await viewModel.send()
        XCTAssertTrue(viewModel.isNetworkUnreachable, "사전 조건: 전송 실패로 네트워크 끊김 상태여야 함")

        let sentMessage = Message(id: 2, conversationId: 10, sender: .user, content: "재전송할 메시지", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))

        await viewModel.retryAfterNetworkFailure()

        XCTAssertFalse(viewModel.isNetworkUnreachable)
        XCTAssertEqual(repository.getMessagesCallCount, 1, "전송만 실패했던 것이므로 대화 기록을 다시 불러오면 안 됨(요약 진행 상태 보존)")
        XCTAssertEqual(viewModel.messages, [existingMessage, sentMessage])
    }

    func test_retryAfterNetworkFailure_resendsWithOriginalExcludedCharacters() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(NetworkError.noConnection)
        let pendingFirstMessage = PendingFirstMessage(content: "안녕", excludedCharacters: [.anger])
        let viewModel = makeViewModel(repository: repository, pendingFirstMessage: pendingFirstMessage)
        await viewModel.start()
        XCTAssertTrue(viewModel.isNetworkUnreachable, "사전 조건")

        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))

        await viewModel.retryAfterNetworkFailure()

        XCTAssertEqual(repository.receivedExcludedCharacters, [.anger])
        XCTAssertEqual(viewModel.messages, [sentMessage])
    }

    func test_start_withConversationIdOnly_loadsHistory() async {
        let repository = MockConversationRepository()
        let userMessage = Message(id: 1, conversationId: 10, sender: .user, content: "사용자 발화", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedMessages = [userMessage]
        let viewModel = makeViewModel(repository: repository, conversationId: 10)

        await viewModel.start()

        XCTAssertEqual(viewModel.messages, [userMessage])
        XCTAssertEqual(repository.getMessagesCallCount, 1)
    }

    func test_start_withNeitherConversationIdNorPendingFirstMessage_doesNothing() async {
        let repository = MockConversationRepository()
        let viewModel = makeViewModel(repository: repository)

        await viewModel.start()

        XCTAssertTrue(viewModel.messages.isEmpty)
        XCTAssertEqual(repository.getMessagesCallCount, 0)
        XCTAssertEqual(repository.sendCallCount, 0)
    }

    func test_start_withPendingFirstMessage_sendsAutomaticallyWithExcludedCharacters() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))
        let pendingFirstMessage = PendingFirstMessage(content: "안녕", excludedCharacters: [.anger])
        let viewModel = makeViewModel(repository: repository, pendingFirstMessage: pendingFirstMessage)

        await viewModel.start()

        XCTAssertEqual(repository.sendCallCount, 1)
        XCTAssertEqual(repository.receivedExcludedCharacters, [.anger])
        XCTAssertEqual(viewModel.messages, [sentMessage])
    }

    func test_seed_newConversation_updatesTitleWithMessageContentInBackground() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        await viewModel.pendingTitleUpdateTask?.value

        XCTAssertEqual(repository.updateTitleCallCount, 1)
        XCTAssertEqual(repository.receivedTitleConversationId, 10)
        XCTAssertEqual(repository.receivedTitle, "안녕")
    }

    func test_seed_existingConversation_doesNotUpdateTitle() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 2, conversationId: 10, sender: .user, content: "고마워", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))
        let viewModel = makeViewModel(repository: repository, conversationId: 10)
        viewModel.input = "고마워"

        await viewModel.send()

        XCTAssertEqual(repository.updateTitleCallCount, 0, "이미 대화가 있으면(재진입/두 번째 메시지) 제목을 다시 저장하면 안 됨")
    }

    func test_updateInput_trailingNewline_keepsNewlineAndDoesNotSignalKeyboardDismiss() {
        let viewModel = makeViewModel()

        let shouldDismiss = viewModel.updateInput("안녕\n")

        XCTAssertFalse(shouldDismiss)
        XCTAssertEqual(viewModel.input, "안녕\n")
    }

    func test_updateInput_overMaxLength_truncatesToMaxLength() {
        let viewModel = makeViewModel()
        let overLong = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 10)

        let shouldDismiss = viewModel.updateInput(overLong)

        XCTAssertFalse(shouldDismiss)
        XCTAssertEqual(viewModel.input.count, ConversationSummaryPolicy.maxMessageLength)
    }

    func test_isSendDisabled_trueWhenInputBlank() {
        let viewModel = makeViewModel()
        viewModel.input = "   "

        XCTAssertTrue(viewModel.isSendDisabled)
    }

    func test_isSendDisabled_falseWhenInputHasContent() {
        let viewModel = makeViewModel()
        viewModel.input = "안녕"

        XCTAssertFalse(viewModel.isSendDisabled)
    }

    func test_canEndConversation_falseWithoutConversationId() {
        let viewModel = makeViewModel(conversationId: nil)

        XCTAssertFalse(viewModel.canEndConversation)
    }

    func test_requestEndConversation_presentsConfirmation() {
        let viewModel = makeViewModel(conversationId: 10)

        viewModel.requestEndConversation()

        XCTAssertTrue(viewModel.isEndConfirmationPresented)
    }

    func test_confirmEndConversation_onSuccess_endsThenCreatesCardAndDisablesComposer() async {
        let repository = MockConversationRepository()
        let cardRepository = MockCardRepository()
        let card = Card(id: 1, conversationId: 10, emotion: .joy, summary: "요약", message: "메시지", date: Date(timeIntervalSince1970: 0))
        cardRepository.stubbedResult = .success(card)
        let summaryStore = MockConversationSummaryStore()
        summaryStore.stubbedCurrent = "압축본"
        let viewModel = makeViewModel(repository: repository, cardRepository: cardRepository, summaryStore: summaryStore, conversationId: 10)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(repository.endConversationCallCount, 1)
        XCTAssertEqual(repository.receivedEndConversationId, 10)
        XCTAssertTrue(viewModel.isConversationEnded)
        XCTAssertTrue(viewModel.isSendDisabled, "종료된 대화는 전송도 막혀야 함")
        XCTAssertEqual(viewModel.createdCard, card)
        XCTAssertEqual(cardRepository.receivedSummary, "압축본")
    }

    func test_confirmEndConversation_usesDominantCharacterEmotionFromMessages() async {
        let repository = MockConversationRepository()
        repository.stubbedMessages = [
            Message(id: 1, conversationId: 10, sender: .character(.anger), content: "", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            Message(id: 2, conversationId: 10, sender: .character(.anger), content: "", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
        ]
        let cardRepository = MockCardRepository()
        cardRepository.stubbedResult = .success(Card(id: 1, conversationId: 10, emotion: .anger, summary: "", message: "", date: Date(timeIntervalSince1970: 0)))
        let viewModel = makeViewModel(repository: repository, cardRepository: cardRepository, conversationId: 10)
        await viewModel.load(conversationId: 10)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(cardRepository.receivedEmotion, .anger)
    }

    func test_confirmEndConversation_summaryStoreReturnsNil_usesJoinedUserMessagesAsSummary() async {
        let repository = MockConversationRepository()
        repository.stubbedMessages = [
            Message(id: 1, conversationId: 10, sender: .user, content: "오늘 힘들었어", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            Message(id: 2, conversationId: 10, sender: .character(.sadness), content: "무슨 일이야?", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
            Message(id: 3, conversationId: 10, sender: .user, content: "그냥 그랬어", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0)),
        ]
        let cardRepository = MockCardRepository()
        cardRepository.stubbedResult = .success(Card(id: 1, conversationId: 10, emotion: .sadness, summary: "", message: "", date: Date(timeIntervalSince1970: 0)))
        let viewModel = makeViewModel(repository: repository, cardRepository: cardRepository, conversationId: 10)
        await viewModel.load(conversationId: 10)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(cardRepository.receivedSummary, "오늘 힘들었어 그냥 그랬어", "압축본이 없으면(대화가 너무 짧은 경우 등) 사용자 원문을 이어붙여 대신 보내야 함")
    }

    func test_confirmEndConversation_endConversationFails_doesNotCreateCard() async {
        let repository = MockConversationRepository()
        repository.stubbedEndConversationResult = .failure(SummaryError.inferenceFailed())
        let cardRepository = MockCardRepository()
        let viewModel = makeViewModel(repository: repository, cardRepository: cardRepository, conversationId: 10)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(cardRepository.createCardCallCount, 0)
        XCTAssertFalse(viewModel.isConversationEnded)
        XCTAssertNotNil(viewModel.alertMessage)
    }

    func test_confirmEndConversation_createCardFails_keepsConversationEndedAndSetsAlert() async {
        let repository = MockConversationRepository()
        let cardRepository = MockCardRepository()
        cardRepository.stubbedResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository, cardRepository: cardRepository, conversationId: 10)

        await viewModel.confirmEndConversation()

        XCTAssertTrue(viewModel.isConversationEnded, "endConversation은 이미 성공했으므로 대화는 종료 상태로 유지되어야 함")
        XCTAssertNil(viewModel.createdCard)
        XCTAssertNotNil(viewModel.alertMessage)
    }

    func test_retryCreateCard_onlyRetriesCardCreationNotEndConversation() async {
        let repository = MockConversationRepository()
        let cardRepository = MockCardRepository()
        cardRepository.stubbedResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository, cardRepository: cardRepository, conversationId: 10)
        await viewModel.confirmEndConversation()
        XCTAssertEqual(repository.endConversationCallCount, 1)

        let card = Card(id: 1, conversationId: 10, emotion: nil, summary: "", message: "", date: Date(timeIntervalSince1970: 0))
        cardRepository.stubbedResult = .success(card)
        await viewModel.retryCreateCard()

        XCTAssertEqual(repository.endConversationCallCount, 1, "endConversation은 재호출되면 안 됨")
        XCTAssertEqual(cardRepository.createCardCallCount, 2)
        XCTAssertEqual(viewModel.createdCard, card)
    }

    func test_dismissCard_clearsCreatedCard() async {
        let cardRepository = MockCardRepository()
        cardRepository.stubbedResult = .success(Card(id: 1, conversationId: 10, emotion: nil, summary: "", message: "", date: Date(timeIntervalSince1970: 0)))
        let viewModel = makeViewModel(cardRepository: cardRepository, conversationId: 10)
        await viewModel.confirmEndConversation()
        XCTAssertNotNil(viewModel.createdCard)

        viewModel.dismissCard()

        XCTAssertNil(viewModel.createdCard)
    }

    func test_isAtBottom_defaultsToTrue() {
        let viewModel = makeViewModel()

        XCTAssertTrue(viewModel.isAtBottom)
    }

    func test_markAtBottom_true_clearsUnseenIncomingMessage() {
        let viewModel = makeViewModel()
        let characterMessage = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.markAtBottom(false)
        viewModel.handleNewLastMessage(characterMessage)
        XCTAssertNotNil(viewModel.unseenIncomingMessage)

        viewModel.markAtBottom(true)

        XCTAssertTrue(viewModel.isAtBottom)
        XCTAssertNil(viewModel.unseenIncomingMessage)
    }

    func test_markAtBottom_false_doesNotTouchUnseenIncomingMessage() {
        let viewModel = makeViewModel()

        viewModel.markAtBottom(false)

        XCTAssertFalse(viewModel.isAtBottom)
        XCTAssertNil(viewModel.unseenIncomingMessage)
    }

    func test_handleNewLastMessage_whenAtBottom_returnsTrueAndDoesNotSetUnseen() {
        let viewModel = makeViewModel()
        let characterMessage = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))

        let shouldScroll = viewModel.handleNewLastMessage(characterMessage)

        XCTAssertTrue(shouldScroll)
        XCTAssertNil(viewModel.unseenIncomingMessage)
    }

    func test_handleNewLastMessage_whenNotAtBottom_characterMessage_returnsFalseAndSetsUnseen() {
        let viewModel = makeViewModel()
        let characterMessage = Message(id: 2, conversationId: 10, sender: .character(.sadness), content: "무슨 일이야", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.markAtBottom(false)

        let shouldScroll = viewModel.handleNewLastMessage(characterMessage)

        XCTAssertFalse(shouldScroll)
        XCTAssertEqual(viewModel.unseenIncomingMessage, characterMessage)
    }

    func test_handleNewLastMessage_whenNotAtBottom_secondCharacterMessage_updatesToLatestWithoutAccumulating() {
        let viewModel = makeViewModel()
        let first = Message(id: 2, conversationId: 10, sender: .character(.sadness), content: "무슨 일이야", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let second = Message(id: 3, conversationId: 10, sender: .character(.joy), content: "괜찮아?", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.markAtBottom(false)
        viewModel.handleNewLastMessage(first)

        viewModel.handleNewLastMessage(second)

        XCTAssertEqual(viewModel.unseenIncomingMessage, second, "누적 없이 항상 최신 1개만 유지해야 함")
    }

    func test_handleNewLastMessage_whenNotAtBottom_userMessage_returnsFalseAndDoesNotSetUnseen() {
        let viewModel = makeViewModel()
        let userMessage = Message(id: 2, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.markAtBottom(false)

        let shouldScroll = viewModel.handleNewLastMessage(userMessage)

        XCTAssertFalse(shouldScroll, "내 메시지 echo는 스크롤 위치와 무관하게 무시해야 함(별도 스크롤/토스트 없음)")
        XCTAssertNil(viewModel.unseenIncomingMessage)
    }

    func test_send_beforeNetworkResponds_hasNoNextReplyCharacter() async {
        let repository = MockConversationRepository()
        let gate = SendGate()
        repository.sendGate = gate
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: []))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        let sendTask = Task { await viewModel.send() }
        while viewModel.pendingUserMessage == nil {
            await Task.yield()
        }

        XCTAssertNil(viewModel.nextReplyCharacter, "서버 응답 자체가 아직 안 왔으면(pendingComments 없음) 다음 발신자를 알 수 없어야 함")

        await gate.open()
        await sendTask.value

        XCTAssertNil(viewModel.nextReplyCharacter, "답장이 0개면 응답 도착 후에도 다음 발신자가 없어야 함")
    }

    func test_send_onSuccess_singleComment_queuesItForRevealThenClearsNextReplyCharacter() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertEqual(viewModel.messages, [sentMessage], "댓글이 1개뿐이어도 즉시 붙이지 않고 순차 노출 큐로 넘어가야 함")
        XCTAssertEqual(viewModel.nextReplyCharacter, .joy, "노출 대기 중인 댓글의 발신자를 가리켜야 함")

        await viewModel.revealTask?.value

        XCTAssertEqual(viewModel.messages, [sentMessage, comment])
        XCTAssertNil(viewModel.nextReplyCharacter, "노출이 끝나면 다음 발신자가 없어야 함")
    }

    func test_send_onSuccess_withRemainingComments_clearsNextReplyCharacterOnceRevealCompletes() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment1 = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        let comment2 = Message(id: 3, conversationId: 10, sender: .character(.sadness), content: "오늘 어때?", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment1, comment2]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        XCTAssertEqual(viewModel.nextReplyCharacter, .joy, "아직 아무 댓글도 노출 전이므로 첫 댓글(comment1)의 발신자를 가리켜야 함")

        await viewModel.revealTask?.value

        XCTAssertNil(viewModel.nextReplyCharacter, "마지막 답장까지 다 노출되면 다음 발신자가 없어야 함")
        XCTAssertEqual(viewModel.messages, [sentMessage, comment1, comment2])
    }

    func test_isSendDisabled_whileCommentsStillRevealingButNotYetTapped_isFalse() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment1 = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        let comment2 = Message(id: 3, conversationId: 10, sender: .character(.sadness), content: "오늘 어때?", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment1, comment2]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        viewModel.input = "다음 메시지"

        XCTAssertFalse(viewModel.isSendDisabled, "감정 답장이 노출 중이어도 아직 탭하지 않았으면 버튼은 활성 상태로 보여야 함")
    }

    func test_isSendDisabled_afterTappingSendWhileRevealing_isTrue() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment1 = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        let comment2 = Message(id: 3, conversationId: 10, sender: .character(.sadness), content: "오늘 어때?", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment1, comment2]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        viewModel.input = "다음 메시지"
        await viewModel.send() // 노출 중 전송 버튼을 탭함

        XCTAssertTrue(viewModel.isSendDisabled, "탭해서 전송이 대기열에 담기면 버튼이 비활성 상태로 보여야 함")
    }

    func test_isSendDisabled_afterRevealCompletesWithNoLeftoverInput_isTrueBecauseInputIsEmpty() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        await viewModel.revealTask?.value

        XCTAssertTrue(viewModel.pendingComments.isEmpty)
        XCTAssertFalse(viewModel.isSending)
        XCTAssertTrue(viewModel.isSendDisabled, "노출은 끝났지만 입력이 비어있으니 전송 버튼은 계속 비활성 상태여야 함")
    }

    func test_send_whileCommentsStillRevealing_doesNothingAndDoesNotFlushReveal() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment1 = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        let comment2 = Message(id: 3, conversationId: 10, sender: .character(.sadness), content: "오늘 어때?", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment1, comment2]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        viewModel.input = "다음 메시지"

        await viewModel.send()

        XCTAssertEqual(repository.sendCallCount, 1, "감정 답장이 노출 중일 때는 새 전송이 서버까지 가면 안 됨")
        XCTAssertEqual(viewModel.messages, [sentMessage], "노출 중이던 답장을 한 번에 쏟아내면 안 됨")
        XCTAssertEqual(viewModel.pendingComments, [comment1, comment2], "순차 노출 큐가 그대로 유지되어야 함")
        XCTAssertEqual(viewModel.input, "다음 메시지", "막힌 전송은 입력값을 비우면 안 됨")

        // 노출 완료 시 남은 입력이 자동 전송되는 동작은 별도 테스트에서 검증한다 — 여기서는
        // 차단된 전송이 노출 자체를 망가뜨리지 않는지만 본다.
        viewModel.input = ""
        await viewModel.revealTask?.value

        XCTAssertEqual(viewModel.messages, [sentMessage, comment1, comment2], "차단된 뒤에도 원래 노출은 정상적으로 이어져야 함")
    }

    func test_whenRevealCompletes_ifUserTappedSendWhileBlocked_autoSendsIt() async {
        let repository = MockConversationRepository()
        let sentMessage1 = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage1, commentStatus: .done, comments: [comment]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        viewModel.input = "다음 메시지"
        await viewModel.send() // 노출 중에 사용자가 전송 버튼을 누른 상황

        let sentMessage2 = Message(id: 3, conversationId: 10, sender: .user, content: "다음 메시지", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage2, commentStatus: .done, comments: []))

        let firstRevealTask = viewModel.revealTask
        await firstRevealTask?.value

        XCTAssertEqual(repository.sendCallCount, 2, "노출 중에 눌러둔 전송은 노출이 끝나면 재탭 없이 이어서 전송되어야 함")
        XCTAssertEqual(viewModel.messages, [sentMessage1, comment, sentMessage2])
        XCTAssertEqual(viewModel.input, "", "자동 전송 후 입력창은 비워져야 함")
    }

    func test_whenRevealCompletes_ifSendWasNeverTappedWhileBlocked_doesNotAutoSend() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        viewModel.input = "다음 메시지" // 타이핑만 하고 전송 버튼은 누르지 않음

        await viewModel.revealTask?.value

        XCTAssertEqual(repository.sendCallCount, 1, "전송 버튼을 누르지 않았다면 노출이 끝나도 자동 전송되면 안 됨")
        XCTAssertEqual(viewModel.input, "다음 메시지", "입력값은 그대로 남아있어야 함")
    }

    func test_whenRevealCompletes_ifQueuedButInputWasClearedMeanwhile_doesNotAutoSend() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        let comment = Message(id: 2, conversationId: 10, sender: .character(.joy), content: "반가워", repliesToMessageId: 1, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .done, comments: [comment]))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()
        viewModel.input = "다음 메시지"
        await viewModel.send() // 눌러서 대기열에 담아둔 뒤
        viewModel.input = "" // 마음이 바뀌어 지움

        await viewModel.revealTask?.value

        XCTAssertEqual(repository.sendCallCount, 1, "대기열에 담겼어도 그 사이 입력이 비었으면 자동 전송하면 안 됨")
    }

    func test_send_onFailure_hasNoNextReplyCharacter() async {
        let repository = MockConversationRepository()
        repository.stubbedSendResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "실패할 메시지"

        await viewModel.send()

        XCTAssertNil(viewModel.nextReplyCharacter)
    }

    func test_loadTokenUsage_onSuccess_setsTokenUsageAndExceededFlag() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 100000, dailyLimit: 100000, exceeded: true))
        let viewModel = makeViewModel(memberRepository: memberRepository)

        await viewModel.loadTokenUsage()

        XCTAssertEqual(viewModel.tokenUsage?.percent, 100)
        XCTAssertTrue(viewModel.isTokenExceeded)
        XCTAssertTrue(viewModel.isSendDisabled)
        XCTAssertEqual(memberRepository.fetchTokenUsageCallCount, 1)
    }

    func test_loadTokenUsage_onSuccess_notExceeded_leavesComposerEnabled() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 12000, dailyLimit: 100000, exceeded: false))
        let viewModel = makeViewModel(memberRepository: memberRepository)
        viewModel.input = "안녕"

        await viewModel.loadTokenUsage()

        XCTAssertFalse(viewModel.isTokenExceeded)
        XCTAssertFalse(viewModel.isSendDisabled)
    }

    func test_loadTokenUsage_onFailure_setsErrorMessage() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(memberRepository: memberRepository)

        await viewModel.loadTokenUsage()

        XCTAssertNotNil(viewModel.tokenUsageErrorMessage)
        XCTAssertNil(viewModel.tokenUsage)
    }

    func test_loadTokenUsage_onNetworkFailure_setsNetworkUnreachable() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .failure(NetworkError.noConnection)
        let viewModel = makeViewModel(memberRepository: memberRepository)

        await viewModel.loadTokenUsage()

        XCTAssertTrue(viewModel.isNetworkUnreachable)
        XCTAssertNil(viewModel.tokenUsageErrorMessage, "네트워크 끊김은 팝오버 에러 문구 대신 전용 화면으로 안내해야 함")
    }

    func test_send_commentStatusLimitExceeded_disablesComposerAndSetsPlaceholder() async {
        let repository = MockConversationRepository()
        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedSendResult = .success(SentMessage(message: sentMessage, commentStatus: .limitExceeded, comments: []))
        let viewModel = makeViewModel(repository: repository)
        viewModel.input = "안녕"

        await viewModel.send()

        XCTAssertTrue(viewModel.isTokenExceeded)
        XCTAssertTrue(viewModel.isSendDisabled)
        XCTAssertEqual(viewModel.composerDisabledPlaceholder, "오늘의 토큰을 모두 사용했어요")
    }

    func test_composerDisabledPlaceholder_conversationEnded_returnsEndedMessage() async {
        let repository = MockConversationRepository()
        let viewModel = makeViewModel(repository: repository, conversationId: 10)

        await viewModel.confirmEndConversation()

        XCTAssertEqual(viewModel.composerDisabledPlaceholder, "대화가 종료됐어요")
    }

    func test_start_fetchesTokenUsageAndSetsExceededFlagWithoutExplicitLoadCall() async {
        let repository = MockConversationRepository()
        let userMessage = Message(id: 1, conversationId: 10, sender: .user, content: "사용자 발화", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        repository.stubbedMessages = [userMessage]
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 100000, dailyLimit: 100000, exceeded: true))
        let viewModel = makeViewModel(repository: repository, memberRepository: memberRepository, conversationId: 10)

        await viewModel.start()

        XCTAssertTrue(viewModel.isTokenExceeded, "start() 하나만으로 토큰 초과 상태가 반영되어야 함")
        XCTAssertEqual(memberRepository.fetchTokenUsageCallCount, 1)
        XCTAssertEqual(viewModel.messages, [userMessage], "토큰 조회와 무관하게 메시지 히스토리도 정상 로드되어야 함")
    }

    func test_loadTokenUsage_calledAgainAfterNewMessage_refetchesAndFlipsFlagBackToFalse() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 100000, dailyLimit: 100000, exceeded: true))
        let viewModel = makeViewModel(memberRepository: memberRepository)

        await viewModel.loadTokenUsage()
        XCTAssertTrue(viewModel.isTokenExceeded)

        let sentMessage = Message(id: 1, conversationId: 10, sender: .user, content: "안녕", repliesToMessageId: nil, createdAt: Date(timeIntervalSince1970: 0))
        viewModel.seed(with: SentMessage(message: sentMessage, commentStatus: .done, comments: []))

        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 12000, dailyLimit: 100000, exceeded: false))
        await viewModel.loadTokenUsage()

        XCTAssertFalse(viewModel.isTokenExceeded, "새 메시지가 오간 뒤 재조회 결과가 더 이상 초과가 아니면 다시 false로 내려가야 함")
        XCTAssertEqual(memberRepository.fetchTokenUsageCallCount, 2, "새 메시지가 있었으면 캐시를 쓰지 않고 다시 API를 불러야 함")
    }

    func test_loadTokenUsage_calledAgainWithoutNewMessage_skipsRefetchAndKeepsCachedValue() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 12000, dailyLimit: 100000, exceeded: false))
        let viewModel = makeViewModel(memberRepository: memberRepository)

        await viewModel.loadTokenUsage()
        XCTAssertEqual(memberRepository.fetchTokenUsageCallCount, 1)

        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 99000, dailyLimit: 100000, exceeded: true))
        await viewModel.loadTokenUsage()

        XCTAssertEqual(memberRepository.fetchTokenUsageCallCount, 1, "그 사이 새 메시지가 없었으면 API를 다시 부르면 안 됨")
        XCTAssertEqual(viewModel.tokenUsage?.usedTokens, 12000, "마지막으로 받아온 값을 그대로 보여줘야 함")
        XCTAssertFalse(viewModel.isTokenExceeded, "캐시된 값 기준 상태를 그대로 유지해야 함")
    }
}

private final class StubEmptyRiskLexiconRepository: RiskLexiconRepository {
    func currentLexicon() async -> RiskLexicon { .empty }
    func refresh() async {}
}
