//
//  ChatView.swift
//  GAMSS
//
//  Created by cchanmi on 8/7/26.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var keyboardHeight: CGFloat = 0
    @State private var isMessageListPositioned = false
    private static var hasPositionedOnce = false

    private let keyboardWillChange = NotificationCenter.default.publisher(
        for: UIResponder.keyboardWillChangeFrameNotification
    )

    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// ScrollView 콘텐츠(LazyVStack)에 적용하는 좌우 패딩. `maxBubbleWidth` 계산에 쓰는
    /// containerPadding이 아래 `.padding(containerPadding)`과 같은 값을 참조하도록 상수 하나로
    /// 묶어서, 패딩을 바꿀 때 폭 계산이 따로 놀지 않게 한다.
    private let containerPadding = Spacing.spacing300

    var body: some View {
        ZStack(alignment: .topTrailing) {
            chatContent

            ModalContainerView(isPresented: $viewModel.isEndConfirmationPresented) {
                ModalContentView(
                    title: "대화를 종료하고 감정 기록을 생성할게요",
                    subtitle: "감정 기록 생성 시 대화는 종료되며,\n더 이상 대화를 이어갈 수 없어요.",
                    actions: [
                        .init(title: "뒤로가기", style: .secondary, action: {
                            viewModel.isEndConfirmationPresented = false
                        }),
                        .init(title: "기록 생성하기", style: .primary, action: {
                            viewModel.isEndConfirmationPresented = false
                            Task { await viewModel.confirmEndConversation() }
                        })
                    ]
                )
            }

            if viewModel.isTokenUsagePopoverPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.isTokenUsagePopoverPresented = false
                    }

                TokenUsagePopoverView(
                    tokenUsage: viewModel.tokenUsage,
                    isLoading: viewModel.isLoadingTokenUsage,
                    errorMessage: viewModel.tokenUsageErrorMessage,
                    onRetry: { Task { await viewModel.loadTokenUsage() } }
                )
                .task {
                    await viewModel.loadTokenUsage()
                }
                .padding(.top, tokenUsagePopoverTopOffset)
                .padding(.trailing, Spacing.spacing400)
            }

            ModalContainerView(isPresented: Binding(
                get: { viewModel.riskDetection != nil },
                set: { if !$0 { viewModel.riskDetection = nil } }
            )) {
                SupportAgencyDialogContentView(
                    detection: viewModel.riskDetection ?? .none,
                    onDismiss: { viewModel.riskDetection = nil }
                )
            }

            if viewModel.isEnding {
                Color.colorBlack.opacity(0.7)
                    .ignoresSafeArea()

                ProgressView()
                    .tint(Color.colorWhite)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if let card = viewModel.createdCard {
                CardResultView(
                    card: card,
                    viewModel: CardResultViewModel(),
                    onComplete: {
                        withAnimation(.easeOut(duration: 0.12)) {
                            viewModel.dismissCard()
                        }
                        DispatchQueue.main.async {
                            dismiss()
                        }
                    }
                )
                .id(card.id)
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.12), value: viewModel.createdCard?.id)
        .hidesTabBar()
        .onChange(of: viewModel.riskDetection) { _, newValue in
            if newValue != nil { isInputFocused = false }
        }
    }

    private let tokenUsagePopoverTopOffset: CGFloat = Spacing.spacing400 + 24 + Spacing.spacing200

    private var chatContent: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: Spacing.spacing200) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    quotedMessage: viewModel.quotedMessage(for: message),
                                    maxWidth: MessageBubbleLayout.maxBubbleWidth(
                                        availableWidth: geometry.size.width,
                                        containerPadding: containerPadding * 2
                                    )
                                )
                                .id(message.id)
                                .onLongPressGesture {
                                    if viewModel.startReply(to: message) {
                                        isInputFocused = true
                                    }
                                }
                            }

                            if let pendingUserMessage = viewModel.pendingUserMessage {
                                MessageBubbleView(
                                    pendingUserMessage: pendingUserMessage,
                                    maxWidth: MessageBubbleLayout.maxBubbleWidth(
                                        availableWidth: geometry.size.width,
                                        containerPadding: containerPadding * 2
                                    )
                                )
                                .id(PendingUserMessage.scrollAnchorID)
                            }

                            if let nextReplyCharacter = viewModel.nextReplyCharacter {
                                TypingIndicatorView(emotion: nextReplyCharacter)
                                    .id(TypingIndicatorView.scrollAnchorID)
                                    .transition(.opacity)
                            }

                            Color.clear
                                .frame(height: 0)
                                .onAppear { viewModel.markAtBottom(true) }
                                .onDisappear { viewModel.markAtBottom(false) }
                        }
                        .animation(.easeOut(duration: 0.2), value: viewModel.nextReplyCharacter)
                        .padding(.horizontal, containerPadding)
                        .padding(.top, containerPadding)
                    }
                    .opacity(isMessageListPositioned ? 1 : 0)
                    .simultaneousGesture(
                        TapGesture().onEnded { isInputFocused = false }
                    )
                    .onChange(of: viewModel.messages) { oldValue, newValue in
                        guard !oldValue.isEmpty else {
                            positionMessageListForInitialLoad(proxy)
                            return
                        }
                        if let last = newValue.last, viewModel.handleNewLastMessage(last) {
                            scrollToBottom(proxy)
                        }
                    }
                    .onChange(of: viewModel.pendingUserMessage) { _, _ in
                        isMessageListPositioned = true
                        scrollToBottom(proxy)
                    }
                    .onChange(of: viewModel.nextReplyCharacter) { _, _ in
                        if viewModel.isAtBottom {
                            scrollToBottom(proxy)
                        }
                    }
                    .onReceive(keyboardWillChange) { notification in
                        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                        let newHeight = max(0, UIScreen.main.bounds.height - frame.origin.y)
                        guard newHeight != keyboardHeight else { return }
                        keyboardHeight = newHeight
                        if viewModel.isAtBottom {
                            let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                            scrollToBottom(proxy, animation: .easeInOut(duration: duration))
                        }
                    }
                    .onChange(of: viewModel.replyTarget) { _, _ in
                        if keyboardHeight > 0, viewModel.isAtBottom {
                            scrollToBottom(proxy)
                        }
                    }
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        VStack(spacing: 0) {
                            bottomIndicator(proxy: proxy)

                            ChatComposerView(
                                text: $viewModel.input,
                                isSendDisabled: viewModel.isSendDisabled,
                                isSending: viewModel.isSending,
                                replyTargetLabel: viewModel.replyTarget.flatMap { QuotedReplyHeader.label(forQuotedSender: $0.sender) },
                                replyTargetContent: viewModel.replyTarget?.content,
                                onCancelReply: { viewModel.cancelReply() },
                                isDisabled: viewModel.isConversationEnded || viewModel.isTokenExceeded,
                                disabledPlaceholder: viewModel.composerDisabledPlaceholder,
                                onSend: { Task { await viewModel.send() } },
                                onTextChange: { viewModel.updateInput($0) },
                                isFocused: $isInputFocused
                            )
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.start()
        }
        .alert(
            viewModel.alertMessage ?? "",
            isPresented: Binding(
                get: {
                    viewModel.alertMessage != nil
                },
                set: {
                    if !$0 {
                        viewModel.alertMessage = nil
                    }
                }
            )
        ) {
            if viewModel.isCardCreationFailureAlert {
                Button("다시 시도") { Task { await viewModel.retryCreateCard() } }
            }
            Button("확인", role: .cancel) {}
        }
    }

    private var header: some View {
        NavigationBarView(
            title: headerDateText,
            titlePlacement: .center,
            titleStyle: .subtitle3,
            titleColor: .colorGray950,
            onBack: { dismiss() },
            horizontalPadding: Spacing.spacing400
        ) {
            HStack(spacing: Spacing.spacing400) {
                Button(action: { viewModel.requestEndConversation() }) {
                    Image("iconCardGenerate")
                }
                .disabled(!viewModel.canEndConversation)
                .accessibilityLabel("대화 종료")

                Button(action: {
                    viewModel.isTokenUsagePopoverPresented.toggle()
                }) {
                    Image("iconTokenUsage")
                }
                .accessibilityLabel("토큰 사용량")
            }
        }
        .background(Color.colorWhite)
    }

    private var headerDateText: String {
        ConversationListDateHeaderFormatter.string(from: viewModel.conversationDate)
    }

    @ViewBuilder
    private func bottomIndicator(proxy: ScrollViewProxy) -> some View {
        if let unseen = viewModel.unseenIncomingMessage {
            NewMessageToastView(message: unseen) {
                viewModel.markAtBottom(true)
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(unseen.id, anchor: .bottom)
                }
            }
        } else if !viewModel.isAtBottom {
            HStack {
                Spacer()
                ScrollDownButtonView { scrollToBottom(proxy) }
                    .padding(.trailing, Spacing.spacing350)
                    .padding(.bottom, Spacing.spacing100)
            }
        }
    }

    /// 화면에 그려지는 순서(메시지 → 낙관적 메시지 → 입력중 인디케이터) 중 가장 아래에 있는
    /// 항목을 기준으로 맨 아래로 스크롤한다.
    private func scrollToBottom(_ proxy: ScrollViewProxy, animation: Animation? = .easeOut(duration: 0.2)) {
        guard let target = viewModel.scrollTarget else { return }
        withAnimation(animation) {
            switch target {
            case .typingIndicator:
                proxy.scrollTo(TypingIndicatorView.scrollAnchorID, anchor: .bottom)
            case .pendingUserMessage:
                proxy.scrollTo(PendingUserMessage.scrollAnchorID, anchor: .bottom)
            case let .message(id):
                proxy.scrollTo(id, anchor: .bottom)
            }
        }
    }

    /// 채팅방 진입 직후 대화 기록을 처음 불러왔을 때만 쓰는 초기 위치 잡기.
    private func positionMessageListForInitialLoad(_ proxy: ScrollViewProxy) {
        guard !Self.hasPositionedOnce else {
            DispatchQueue.main.async {
                scrollToBottom(proxy, animation: nil)
                isMessageListPositioned = true
            }
            return
        }

        DispatchQueue.main.async {
            scrollToBottom(proxy, animation: nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                scrollToBottom(proxy, animation: nil)
                isMessageListPositioned = true
                Self.hasPositionedOnce = true
            }
        }
    }
}
