//
//  HomeView.swift
//  GAMSS
//
//  Created by cchanmi on 8/8/26.
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @FocusState private var isInputFocused: Bool
    @State private var isSettingPresented = false
    @SwiftUI.Environment(UserManager.self) private var userManager
    @State private var isGreetingReady = false

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent

            if let toastMessage = viewModel.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, Spacing.spacing200)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
        .onChange(of: viewModel.pendingFirstMessage) { _, newValue in
            if newValue != nil { isInputFocused = false }
        }
        .navigationDestination(item: $viewModel.pendingFirstMessage) { pendingFirstMessage in
            ChatView(
                viewModel: ChatViewModel(
                    sendMessageUseCase: SendMessageUseCase(conversationRepository: DefaultConversationRepository(networkManager: NetworkManager.shared)),
                    getMessagesUseCase: GetMessagesUseCase(conversationRepository: DefaultConversationRepository(networkManager: NetworkManager.shared)),
                    endConversationUseCase: EndConversationUseCase(conversationRepository: DefaultConversationRepository(networkManager: NetworkManager.shared)),
                    createCardUseCase: CreateCardUseCase(cardRepository: DefaultCardRepository(networkManager: NetworkManager.shared)),
                    getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: DefaultMemberRepository(networkManager: NetworkManager.shared, tokenStorage: .shared)),
                    updateConversationTitleUseCase: UpdateConversationTitleUseCase(conversationRepository: DefaultConversationRepository(networkManager: NetworkManager.shared)),
                    detectRiskInTextUseCase: DetectRiskInTextUseCase(repository: DefaultRiskLexiconRepository()),
                    summaryStore: LazyConversationSummaryStore(),
                    pendingFirstMessage: pendingFirstMessage
                )
            )
        }
        .navigationDestination(isPresented: $isSettingPresented) {
            SettingView()
        }
        .task {
            if userManager.user != nil { isGreetingReady = true }
            async let profile: Void = viewModel.loadProfileIfNeeded()
            async let tokenUsage: Void = viewModel.loadTokenUsage()
            _ = await (profile, tokenUsage)
        }
        .onChange(of: userManager.user != nil) { _, isReady in
            guard isReady, !isGreetingReady else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                isGreetingReady = true
            }
        }
        .alert(viewModel.alertMessage ?? "", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        }
    }

    private var mainContent: some View {
        ZStack {
            if viewModel.isNetworkUnreachable {
                Color.colorWhite
                    .ignoresSafeArea()
            } else {
                GeometryReader { geo in
                    Image("homeBackgroundPaper")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()

                decorations

                // 화면의 빈 영역(다른 인터랙티브 뷰가 가리지 않는 부분)을 탭하면 키보드와 감정
                // 드롭다운을 내린다. TextEditor/버튼은 그 위에 그려져 자기 탭을 먼저 가져가므로
                // 커서 이동 등은 방해받지 않는다.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isInputFocused = false
                        viewModel.isEmotionPickerOpen = false
                    }
            }

            VStack(alignment: .leading, spacing: 0) {
                NavigationBarView(leading: .logo) {
                    Button {
                        isInputFocused = false
                        isSettingPresented = true
                    } label: {
                        Image("gear")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color.colorGray900)
                    }
                }
                .padding(.bottom, viewModel.isNetworkUnreachable ? 0 : 188 - (NavigationBarMetrics.height - 24) / 2)

                if viewModel.isNetworkUnreachable {
                    // 인사말/입력창과 같은 자리를 대체한다. 네비바는 그대로 위에 남고, 이 뷰가
                    // maxHeight: .infinity로 남은 공간을 채우며 그 안에서 중앙 정렬된다.
                    NetworkFailureView {
                        Task { await viewModel.retryAfterNetworkFailure() }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        greeting
                            .padding(.bottom, Spacing.spacing500)
                            .opacity(isGreetingReady ? 1 : 0)

                        MessageComposerView(
                            input: $viewModel.input,
                            selectedEmotions: viewModel.selectedEmotions,
                            isEmotionPickerOpen: $viewModel.isEmotionPickerOpen,
                            isSendDisabled: viewModel.isSendDisabled,
                            onToggleEmotion: { viewModel.toggleEmotion($0) },
                            onCommit: { viewModel.send() },
                            onInputChange: { viewModel.updateInput($0) },
                            isFocused: $isInputFocused,
                            isDisabled: viewModel.isTokenExceeded,
                            disabledPlaceholder: viewModel.composerDisabledPlaceholder
                        )

                        Spacer()
                    }
                    .padding(.horizontal, NavigationBarMetrics.horizontalPadding)
                    .padding(.bottom, Spacing.spacing400)
                }
            }
        }
        // 키보드가 올라오면 SwiftUI가 기본적으로 사용 가능한 영역을 줄이는데, 장식
        // 이미지가 GeometryReader의 상대 좌표(geo.size)로 위치를 잡고 있어서 그 영역이
        // 줄어들면 같이 움직여 보인다 — 키보드에 반응해 레이아웃이 줄어들지 않게 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// "{닉네임}님 오늘도" / "감쓰에 버려볼까요?" — 닉네임 부분만 분홍 배경으로 하이라이트한다.
    /// UserManager에 값이 아직 없으면(조회 전/실패) fallback을 쓴다.
    private var greeting: some View {
        let nickname = userManager.user?.nickname ?? "OO"
        return VStack(alignment: .leading, spacing: Spacing.spacing050) {
            HStack(spacing: 0) {
                Text(nickname)
                    .typography(.title3)
                    .foregroundStyle(Color.colorGray950)
                    .padding(.horizontal, Spacing.spacing050)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.radius050)
                            .fill(Color.colorPink.opacity(0.5))
                    )
                Text("님 오늘도")
                    .typography(.title3)
                    .foregroundStyle(Color.colorGray950)
            }
            Text("감쓰에 버려볼까요?")
                .typography(.title3)
                .foregroundStyle(Color.colorGray950)
        }
    }

    /// 포스트잇/테이프 장식 3종. 순수 장식이라 터치를 가로채지 않는다(`allowsHitTesting(false)`).
    /// 위치/회전값은 Figma 레드라인 확정 전 임시값 — 정확한 좌표 받으면 다듬는다.
    private var decorations: some View {
        GeometryReader { geo in
            ZStack {
                Image("homeStickyNote")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .rotationEffect(.degrees(10))
                    .position(x: geo.size.width * 0.82, y: geo.size.height * 0.27)

                Image("homeTapePink")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 50)
                    .rotationEffect(.degrees(-8))
                    .position(x: geo.size.width * 0.78, y: geo.size.height * 0.68)

                Image("homeTapeOutline")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 60)
                    .rotationEffect(.degrees(-12))
                    .position(x: geo.size.width * 0.28, y: geo.size.height * 0.76)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack {
        HomeView(
            viewModel: HomeViewModel(
                fetchMyProfileUseCase: DefaultFetchMyProfileUseCase(
                    memberRepository: DefaultMemberRepository(networkManager: NetworkManager.shared, tokenStorage: .shared)
                ),
                getTokenUsageUseCase: GetTokenUsageUseCase(
                    memberRepository: DefaultMemberRepository(networkManager: NetworkManager.shared, tokenStorage: .shared)
                )
            )
        )
    }
    .environment(UserManager.shared)
}
