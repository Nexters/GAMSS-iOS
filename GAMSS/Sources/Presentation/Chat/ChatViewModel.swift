//
//  ChatViewModel.swift
//  GAMSS
//
//  Created by cchanmi on 8/7/26.
//

import Combine
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published private(set) var pendingComments: [Message] = []
    @Published var input: String = ""
    @Published private(set) var isSending = false
    @Published var alertMessage: String?
    @Published private(set) var pendingUserMessage: PendingUserMessage?
    @Published private(set) var replyTarget: Message?
    @Published var isEndConfirmationPresented = false
    @Published private(set) var isEnding = false
    @Published private(set) var isConversationEnded = false
    @Published private(set) var createdCard: Card?
    @Published private(set) var isAtBottom = true
    @Published private(set) var unseenIncomingMessage: Message?
    @Published private(set) var tokenUsage: TokenUsage?
    @Published private(set) var isLoadingTokenUsage = false
    @Published var tokenUsageErrorMessage: String?
    @Published var isTokenUsagePopoverPresented = false
    @Published var riskDetection: RiskDetection?
    @Published private(set) var isTokenExceeded = false
    @Published private(set) var isNetworkUnreachable = false
    /// 답장 하나가 막 노출된 직후, 다음 캐릭터의 입력중 표시가 뜨기 전까지의 짧은 정적 구간.
    /// 이 동안은 `nextReplyCharacter`가 nil을 돌려줘 인디케이터가 잠깐 사라진다.
    @Published private(set) var isRevealPaused = false

    private var conversationId: Int?
    private let pendingFirstMessage: PendingFirstMessage?
    let conversationDate: Date
    private let sendMessageUseCase: SendMessageUseCase
    private let getMessagesUseCase: GetMessagesUseCase
    private let endConversationUseCase: EndConversationUseCase
    private let createCardUseCase: CreateCardUseCase
    private let getTokenUsageUseCase: GetTokenUsageUseCase
    private let updateConversationTitleUseCase: UpdateConversationTitleUseCase
    private let detectRiskInTextUseCase: DetectRiskInTextUseCase
    private let summaryStore: ConversationSummaryStore
    /// 테스트에서 순차 노출이 끝나는 시점을 결정적으로 기다리기 위한 핸들.
    private(set) var revealTask: Task<Void, Never>?
    @Published private var isSendQueued = false
    private var isTokenUsageStale = true
    /// 네트워크 끊김 화면의 "재시도"에서 대화 기록을 처음부터 다시 불러와야 하는지. 이미 로드된
    /// 대화 중간에 메시지 전송만 실패한 경우엔 다시 불러오면 summaryStore 진행 상태가 초기화되므로
    /// true로 두지 않는다.
    private var needsConversationReload = false
    /// 전송이 네트워크 문제로 실패했을 때, 재시도 시 같은 옵션으로 다시 보내기 위해 보관한다.
    /// nil이면 재전송할 게 없다는 뜻(빈 Set과 구분하기 위해 옵셔널로 둔다).
    private var pendingResendExcludedCharacters: Set<EmotionCharacter>?
    /// 테스트에서 백그라운드 요약 저장이 끝나는 시점을 결정적으로 기다리기 위한 핸들.
    private(set) var pendingSummaryUpdateTask: Task<Void, Never>?
    /// 테스트에서 백그라운드 제목 저장이 끝나는 시점을 결정적으로 기다리기 위한 핸들.
    private(set) var pendingTitleUpdateTask: Task<Void, Never>?

    init(
        sendMessageUseCase: SendMessageUseCase,
        getMessagesUseCase: GetMessagesUseCase,
        endConversationUseCase: EndConversationUseCase,
        createCardUseCase: CreateCardUseCase,
        getTokenUsageUseCase: GetTokenUsageUseCase,
        updateConversationTitleUseCase: UpdateConversationTitleUseCase,
        detectRiskInTextUseCase: DetectRiskInTextUseCase,
        summaryStore: ConversationSummaryStore,
        conversationId: Int? = nil,
        pendingFirstMessage: PendingFirstMessage? = nil,
        initialDate: Date = Date()
    ) {
        self.sendMessageUseCase = sendMessageUseCase
        self.getMessagesUseCase = getMessagesUseCase
        self.endConversationUseCase = endConversationUseCase
        self.createCardUseCase = createCardUseCase
        self.getTokenUsageUseCase = getTokenUsageUseCase
        self.updateConversationTitleUseCase = updateConversationTitleUseCase
        self.detectRiskInTextUseCase = detectRiskInTextUseCase
        self.summaryStore = summaryStore
        self.conversationId = conversationId
        self.pendingFirstMessage = pendingFirstMessage
        self.conversationDate = initialDate
    }

    /// 화면 진입 시 한 번 호출한다. 기존 대화면 히스토리를 불러오고, 홈에서 아직 안 보낸 첫
    /// 메시지를 들고 왔으면(pendingFirstMessage) 그 내용으로 전송을 자동 시작한다.
    func start() async {
        async let tokenUsageFetch: Void = loadTokenUsage()

        if let conversationId {
            await load(conversationId: conversationId)
        } else if let pendingFirstMessage {
            input = pendingFirstMessage.content
            await send(excludedCharacters: pendingFirstMessage.excludedCharacters)
        }

        await tokenUsageFetch
    }

    /// 재진입 시 히스토리를 불러온다. 순차 노출은 적용하지 않고 한 번에 표시한다.
    func load(conversationId: Int) async {
        self.conversationId = conversationId
        do {
            let history = try await getMessagesUseCase.execute(conversationId: conversationId)
            messages = history
            let userUtterances = history.compactMap { message -> String? in
                guard message.sender == .user else { return nil }
                return message.content
            }
            await summaryStore.restore(historicalUtterances: userUtterances)
        } catch NetworkError.noConnection {
            needsConversationReload = true
            isNetworkUnreachable = true
        } catch {
            alertMessage = "대화를 불러오지 못했어요"
        }
    }

    /// 네트워크 끊김 화면의 "재시도" 버튼에서 호출한다. 실패했던 지점에 따라 필요한 것만
    /// 다시 시도한다 — 전송만 실패했는데 대화 기록까지 다시 불러오면 summaryStore 진행
    /// 상태가 초기화되기 때문이다.
    func retryAfterNetworkFailure() async {
        isNetworkUnreachable = false

        if needsConversationReload, let conversationId {
            needsConversationReload = false
            await load(conversationId: conversationId)
        }

        await loadTokenUsage()

        if let excludedCharacters = pendingResendExcludedCharacters {
            pendingResendExcludedCharacters = nil
            await send(excludedCharacters: excludedCharacters)
        }
    }

    /// 입력창의 원시 입력값을 받아 정책에 맞게 정규화하고, 키보드를 내려야 하는지 돌려준다.
    func updateInput(_ rawValue: String) -> Bool {
        let result = ConversationSummaryPolicy.normalizeInput(rawValue)
        input = result.value
        return result.shouldDismissKeyboard
    }

    func markAtBottom(_ atBottom: Bool) {
        isAtBottom = atBottom
        if atBottom {
            unseenIncomingMessage = nil
        }
    }

    @discardableResult
    func handleNewLastMessage(_ message: Message) -> Bool {
        guard case .character = message.sender else { return false }
        if isAtBottom {
            return true
        }
        unseenIncomingMessage = message
        return false
    }

    var isSendDisabled: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending || isSendQueued || isConversationEnded || isTokenExceeded
    }

    /// 아직 대화방이 만들어지지 않았거나(첫 메시지 전) 이미 종료된 대화는 다시 종료할 수 없다.
    var canEndConversation: Bool {
        conversationId != nil && !isConversationEnded
    }

    var isCardCreationFailureAlert: Bool {
        isConversationEnded && createdCard == nil && alertMessage != nil
    }

    var composerDisabledPlaceholder: String {
        isConversationEnded ? "대화가 종료됐어요" : "오늘의 토큰을 모두 사용했어요"
    }

    /// 다음으로 순차 노출될 답장의 발신자. 서버 응답(SentMessage.comments)이 이미 다 도착해
    /// pendingComments에 담겨있는 상태라 다음 캐릭터가 누구인지 미리 알 수 있다 — 첫 응답이
    /// 오기 전(네트워크 대기 중)에는 pendingComments가 비어있어 nil.
    var nextReplyCharacter: EmotionCharacter? {
        guard !isRevealPaused, case let .character(emotion) = pendingComments.first?.sender else { return nil }
        return emotion
    }

    /// 화면에 그려지는 순서(입력중 인디케이터 → 낙관적 메시지 → 일반 메시지) 중 가장 아래에
    /// 있는 항목이 뭔지 판단한다. 이 우선순위(무엇이 "마지막"인지)는 대화 상태에 대한 판단이라
    /// View가 아니라 여기서 정한다 — View는 이 결과를 받아 실제 스크롤 앵커 id로 옮기기만 한다.
    var scrollTarget: ScrollTarget? {
        if nextReplyCharacter != nil {
            .typingIndicator
        } else if pendingUserMessage != nil {
            .pendingUserMessage
        } else if let lastId = messages.last?.id {
            .message(lastId)
        } else {
            nil
        }
    }

    func loadTokenUsage() async {
        guard isTokenUsageStale else { return }

        isLoadingTokenUsage = true
        tokenUsageErrorMessage = nil
        defer { isLoadingTokenUsage = false }
        do {
            let usage = try await getTokenUsageUseCase.execute()
            tokenUsage = usage
            isTokenExceeded = usage.exceeded
            isTokenUsageStale = false
        } catch NetworkError.noConnection {
            isNetworkUnreachable = true
            isTokenUsagePopoverPresented = false
        } catch {
            tokenUsageErrorMessage = "토큰 사용량을 불러오지 못했어요"
        }
    }

    func send(excludedCharacters: Set<EmotionCharacter> = []) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        guard pendingComments.isEmpty else {
            isSendQueued = true
            return
        }
        isSending = true
        defer { isSending = false }

        let detection = await detectRiskInTextUseCase.execute(text: trimmed)
        if detection.level != .none {
            riskDetection = detection
        }
        if detection.shouldBlock {
            return
        }


        let replyTarget = replyTarget
        self.replyTarget = nil
        pendingUserMessage = PendingUserMessage(
            content: trimmed,
            sentAt: Date(),
            quotedSenderLabel: replyTarget.flatMap { QuotedReplyHeader.label(forQuotedSender: $0.sender) },
            quotedContent: replyTarget?.content
        )
        input = ""

        let contextSummary = await summaryStore.current()

        do {
            let sent = try await sendMessageUseCase.execute(
                conversationId: conversationId,
                content: trimmed,
                repliesToMessageId: replyTarget?.id,
                contextSummary: contextSummary,
                excludedCharacters: excludedCharacters
            )
            pendingUserMessage = nil
            seed(with: sent)

            // 요약기(온디바이스 추론)가 끝날 때까지 다음 입력을 막지 않도록 백그라운드로 돌린다.
            // self가 아니라 summaryStore를 직접 캡처해 화면을 나가도 저장은 끝까지 완료되게 한다.
            let summaryStore = summaryStore
            pendingSummaryUpdateTask = Task { await summaryStore.add(trimmed) }
        } catch NetworkError.noConnection {
            pendingUserMessage = nil
            if self.replyTarget == nil { self.replyTarget = replyTarget }
            if input.isEmpty { input = trimmed }
            pendingResendExcludedCharacters = excludedCharacters
            isNetworkUnreachable = true
        } catch let error as SendMessageValidationError {
            pendingUserMessage = nil
            if self.replyTarget == nil { self.replyTarget = replyTarget }
            if input.isEmpty { input = trimmed }
            alertMessage = error.errorDescription
        } catch {
            pendingUserMessage = nil
            if self.replyTarget == nil { self.replyTarget = replyTarget }
            if input.isEmpty { input = trimmed }
            alertMessage = "메시지를 보내지 못했어요"
        }
    }

    /// 다른 화면(홈)에서 이미 받아온 응답으로 화면을 채운다 — 방금 받은 응답을 다시
    /// getMessages로 조회하지 않기 위한 용도.
    func seed(with sent: SentMessage) {
        let isNewConversation = conversationId == nil
        conversationId = sent.message.conversationId
        isTokenUsageStale = true

        messages.append(sent.message)
        // 첫 댓글을 포함해 전부 순차 노출 큐로 — 모든 답장 앞에 로티가 한 번씩 뜬다.
        pendingComments = sent.comments
        revealRemainingComments()

        if sent.commentStatus != .done {
            alertMessage = sent.commentStatus.toUserMessage()
        }
        if sent.commentStatus == .limitExceeded {
            isTokenExceeded = true
        }

        if isNewConversation {
            updateTitleInBackground(conversationId: sent.message.conversationId, title: sent.message.content)
        }
    }

    /// 새 대화의 첫 메시지 내용을 제목으로 저장한다. 실패해도 이미 진행 중인 대화 자체를
    /// 막지 않고 알럿만 띄운다.
    private func updateTitleInBackground(conversationId: Int, title: String) {
        let updateConversationTitleUseCase = updateConversationTitleUseCase
        pendingTitleUpdateTask = Task { [weak self] in
            do {
                try await updateConversationTitleUseCase.execute(conversationId: conversationId, title: title)
            } catch {
                self?.alertMessage = "제목을 저장하지 못했어요"
            }
        }
    }

    /// 답장 말풍선에 인용할 원본 메시지를 찾는다. 서버는 repliesToMessageId만 내려주므로
    /// 이미 로드된 messages에서 직접 찾아야 한다.
    func quotedMessage(for message: Message) -> Message? {
        guard let repliesToMessageId = message.repliesToMessageId else { return nil }
        return messages.first { $0.id == repliesToMessageId }
    }

    /// 캐릭터 말풍선을 길게 눌렀을 때 호출한다. 사용자 메시지는 답장 대상이 될 수 없으므로
    /// 무시한다 — View는 아무 버블에나 제스처를 붙이고, 이 판단은 여기서만 한다.
    @discardableResult
    func startReply(to message: Message) -> Bool {
        guard case .character = message.sender else { return false }
        replyTarget = message
        return true
    }

    func cancelReply() {
        replyTarget = nil
    }

    /// 헤더의 종료 버튼이 누르는 진입점. 확인 팝업만 띄우고 실제 종료는 confirmEndConversation()에서.
    func requestEndConversation() {
        guard canEndConversation else { return }
        isEndConfirmationPresented = true
    }

    /// 종료 확인 팝업에서 "종료할래요"를 눌렀을 때. endConversation → createCard 순서로 호출한다.
    /// endConversation이 성공하면 서버에서는 이미 대화가 끝난 상태이므로, 뒤이은 createCard가
    /// 실패해도 입력창은 다시 열어주지 않는다 — retryCreateCard()로만 재시도한다.
    func confirmEndConversation() async {
        guard let conversationId, !isEnding else { return }
        isEnding = true
        defer { isEnding = false }

        do {
            try await endConversationUseCase.execute(conversationId: conversationId)
        } catch {
            alertMessage = "대화를 종료하지 못했어요"
            return
        }

        isConversationEnded = true
        await createCard(conversationId: conversationId)
    }

    /// createCard만 다시 시도한다. endConversation은 이미 성공했으므로 재호출하지 않는다.
    func retryCreateCard() async {
        guard let conversationId, isConversationEnded, !isEnding else { return }
        isEnding = true
        defer { isEnding = false }
        await createCard(conversationId: conversationId)
    }

    func dismissCard() {
        createdCard = nil
    }

    /// summary는 채팅 압축본(ConversationSummaryStore)을 그대로 재사용한다 — 카드 전용 요약을
    /// 따로 만들지 않는다. emotion은 지금까지 등장한 캐릭터 답장의 최빈값.
    private func createCard(conversationId: Int) async {
        let summary = await summaryStore.current() ?? rawUserMessagesSummary()
        let emotion = EmotionCharacter.dominant(in: messages)
        do {
            createdCard = try await createCardUseCase.execute(conversationId: conversationId, emotion: emotion, summary: summary)
        } catch {
            alertMessage = "카드를 만들지 못했어요. 다시 시도해주세요"
        }
    }

    /// summaryStore가 압축본을 못 내놓는 경우(대화가 너무 짧아 add()가 반영되기 전에
    /// 종료된 경우 등)의 대비책 — 서버에 빈 summary를 보내면 카드 생성이 실패하므로,
    /// 사용자가 실제로 보낸 원문을 그대로 이어붙여 대신 보낸다.
    private func rawUserMessagesSummary() -> String {
        messages
            .filter { $0.sender == .user }
            .map(\.content)
            .joined(separator: " ")
    }

    private func revealRemainingComments() {
        guard !pendingComments.isEmpty else { return }
        revealTask = Task { [weak self] in
            guard let self else { return }
            while true {
                let hasNext: Bool = await MainActor.run { !self.pendingComments.isEmpty }
                guard hasNext else { break }
                try? await Task.sleep(nanoseconds: UInt64(CommentRevealPolicy.nextGapSeconds() * 1_000_000_000))
                guard !Task.isCancelled else { break }
                let hasMore: Bool = await MainActor.run {
                    guard !self.pendingComments.isEmpty else { return false }
                    self.messages.append(self.pendingComments.removeFirst())
                    let hasMore = !self.pendingComments.isEmpty
                    self.isRevealPaused = hasMore
                    return hasMore
                }
                // 다음 캐릭터가 남아있을 때만 정적 구간을 둔다 — 마지막 답장 뒤에는 쉴 필요 없음.
                guard hasMore else { break }
                try? await Task.sleep(nanoseconds: UInt64(CommentRevealPolicy.postRevealGapSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await MainActor.run { self.isRevealPaused = false }
            }
            guard !Task.isCancelled else { return }
            await self.autoSendPendingInputIfPossible()
        }
    }

    private func autoSendPendingInputIfPossible() async {
        guard isSendQueued else { return }
        isSendQueued = false
        guard !isSendDisabled else { return }
        await send()
    }
}

private extension CommentGenerationStatus {
    func toUserMessage() -> String? {
        switch self {
        case .done: nil
        case .failed: "답장을 받지 못했어요. 잠시 후 다시 보내볼까요?"
        case .limitExceeded: "오늘은 대화를 많이 했어요. 내일 다시 이야기해요."
        }
    }
}
