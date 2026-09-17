//
//  ConversationListView.swift
//  GAMSS
//
//  Created by cchanmi on 8/8/26.
//

import SwiftUI

enum ConversationMode {
    case normal
    case delete
}

struct ConversationListView: View {
    @StateObject private var viewModel: ConversationListViewModel
    @State private var selectedConversation: ConversationSummary?
    @State private var isSettingPresented = false
    @State private var isDeleteConversationPresented = false

    init(viewModel: ConversationListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ConversationListHeaderView(
                currentMode: viewModel.currentMode,
                onTappedBackButton: { viewModel.updateMode(.normal) },
                onTappedSearchButton: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.startSearching()
                    }
                },
                onTappedSettingButton: { isSettingPresented = true }
            )

            if viewModel.isSearching {
                ConversationSearchView(
                    onTappedCancelButton: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.stopSearching()
                        }
                    },
                    onTappedSearchButton: {
                        Task { await viewModel.searchText() }
                    },
                    editingText: $viewModel.editedText
                )
                .frame(height: 42)
                .padding(.horizontal, NavigationBarMetrics.horizontalPadding)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            dateHeader
                .padding(.vertical, Spacing.spacing150)
                .padding(.horizontal, NavigationBarMetrics.horizontalPadding)

            if !viewModel.isLoading && viewModel.displayedConversations.isEmpty {
                ConversationListEmptyView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.horizontal, NavigationBarMetrics.horizontalPadding)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: Spacing.spacing100) {
                            ForEach(Array(viewModel.displayedConversations.enumerated()), id: \.element.id) { index, conversation in
                                conversationRow(for: conversation)
                                    .onAppear {
                                        Task {
                                            await viewModel.loadMoreIfNeeded(at: index)
                                        }
                                    }
                            }

                            if viewModel.isLoading && !viewModel.displayedConversations.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Spacing.spacing200)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if viewModel.currentMode == .delete {
                        Button {
                            isDeleteConversationPresented = true
                        } label: {
                            Text("삭제하기")
                                .typography(.body3Medium)
                                .foregroundStyle(
                                    viewModel.isDeleteButtonEnabled
                                    ? Color.colorWhite
                                    : Color.colorGray300
                                )
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    viewModel.isDeleteButtonEnabled
                                    ? Color.colorRed
                                    : Color.colorGray075
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, Spacing.spacing200)
                        .padding(.bottom, 10)
                        .disabled(!viewModel.isDeleteButtonEnabled)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, NavigationBarMetrics.horizontalPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.colorWhite)
        .navigationDestination(item: $selectedConversation) { conversation in
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
                    conversationId: conversation.id,
                    initialDate: conversation.createdAt
                )
            )
        }
        .navigationDestination(isPresented: $isSettingPresented) {
            SettingView()
        }
        .onAppear {
            Task { await viewModel.load() }
        }
        .alert(viewModel.alertMessage ?? "", isPresented: Binding(
            get: { viewModel.alertMessage != nil },
            set: { if !$0 { viewModel.alertMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        }
        .background {
            ModalContainerView(isPresented: $isDeleteConversationPresented) {
                ModalContentView(
                    title: "대화를 정말 삭제할까요?",
                    subtitle: "대화를 이어갈 수 없으며, 카드를 생성할 수 없습니다.\n채팅은 영구적으로 삭제됩니다.",
                    actions: [
                        .init(title: "뒤로가기", style: .secondary, action: {
                            isDeleteConversationPresented = false
                        }),
                        .init(title: "삭제하기", style: .destructive, action: {
                            isDeleteConversationPresented = false
                            Task { await viewModel.deleteConversations() }
                        })
                    ]
                )
            }
        }
    }

    private var dateHeader: some View {
        HStack {
            Text(ConversationListDateHeaderFormatter.string(from: Date()))
                .typography(.body5Regular)
                .foregroundStyle(Color.colorGray950)

            Spacer()

            Button {
                viewModel.updateMode(.delete)
            } label: {
                Text("삭제하기")
                    .typography(.body5Regular)
                    .foregroundStyle(Color.colorGray500)
            }
        }
    }

    @ViewBuilder
    private func conversationRow(for conversation: ConversationSummary) -> some View {
        switch viewModel.currentMode {
        case .normal:
            Button {
                selectedConversation = conversation
            } label: {
                ConversationRowView(
                    currentMode: viewModel.currentMode,
                    conversation: conversation,
                    isSelected: false
                )
            }
            .buttonStyle(.plain)

        case .delete:
            Button {
                viewModel.selectConversation(id: conversation.id)
            } label: {
                ConversationRowView(
                    currentMode: viewModel.currentMode,
                    conversation: conversation,
                    isSelected: viewModel.isSelected(id: conversation.id)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
