//
//  AccountView.swift
//  GAMSS
//
//  Created by LEEGEONJUN on 8/13/26.
//

import SwiftUI

struct AccountView: View {
    let title: String
    
    @StateObject private var viewModel: AccountViewModel
    @SwiftUI.Environment(LoginSession.self) private var loginSession
    @SwiftUI.Environment(UserManager.self) private var userManager
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var isLogoutModalPresented = false
    @State private var isWithdrawModalPresented = false
    
    init(title: String, viewModel: AccountViewModel) {
        self.title = title
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                NavigationBarView(title: title, onBack: { dismiss() })
                
                ForEach(AccountItem.allCases) { item in
                    accountItem(item)
                        .padding(.horizontal, 18)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.colorWhite)
            .alert(
                viewModel.errorMessage ?? "",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            }
            
            ModalContainerView(isPresented: $isLogoutModalPresented) {
                ModalContentView(title: "로그아웃 하시겠어요?", actions: [
                    .init(title: "로그아웃", style: .secondary, action: {
                        isLogoutModalPresented = false
                        
                        Task {
                            await viewModel.logout()
                            loginSession.value = .current
                        }
                    }),
                    .init(title: "마저 사용하기", style: .primary, action: {
                        isLogoutModalPresented = false
                    })
                ])
            }
            
            ModalContainerView(isPresented: $isWithdrawModalPresented) {
                ModalContentView(
                    title: "정말 탈퇴하시겠어요?",
                    subtitle: "회원 탈퇴 시 지금까지 기록된 카드와 대화 내용은\n 영원히 삭제되며 복구되지 않아요.",
                    actions: [
                        .init(title: "뒤로가기", style: .secondary, action: {
                            isWithdrawModalPresented = false
                        }),
                        .init(title: "탈퇴하기", style: .destructive, action: {
                            isWithdrawModalPresented = false
                            
                            Task {
                                await viewModel.deleteMember()
                                loginSession.value = .current
                            }
                        })
                    ])
            }
        }
        .hidesTabBar()
    }
    
    @ViewBuilder
    private func accountItem(_ item: AccountItem) -> some View {
        let row = MenuListItemView(
            title: item.title,
            titleColor: item.titleColor,
            trailingText: trailingText(for: item)
        )
        
        switch item {
        case .changeNickname:
            NavigationLink {
                NicknameEditView(viewModel: NicknameEditViewModel(updateNicknameUseCase: DefaultUpdateNicknameUseCase(memberRepository: DefaultMemberRepository(networkManager: NetworkManager.shared, tokenStorage: TokenStorage.shared), userManager: UserManager.shared)))
            } label: {
                row
            }
            .buttonStyle(.plain)
        case .email:
            row
        case .logout:
            Button {
                isLogoutModalPresented = true
            } label: {
                row
            }
            .buttonStyle(.plain)
        case .withdraw:
            Button {
                isWithdrawModalPresented = true
            } label: {
                row
            }
            .buttonStyle(.plain)
        }
    }
    
    private func trailingText(for item: AccountItem) -> String? {
        switch item {
        case .changeNickname:
            userManager.user?.nickname ?? "-"
        case .email:
            userManager.user?.email ?? "-"
        case .logout, .withdraw:
            nil
        }
    }
}

#Preview {
    NavigationStack {
        AccountView(
            title: SettingItem.accountInfo.title,
            viewModel: AccountViewModel(
                logoutUseCase: DefaultLogoutUseCase(
                    authRepository: DefaultAuthRepository(
                        networkManager: NetworkManager.shared,
                        tokenStorage: TokenStorage.shared
                    )
                ),
                deleteMemberUseCase: DefaultDeleteMemberUseCase(
                    memberRepository: DefaultMemberRepository(
                        networkManager: NetworkManager.shared,
                        tokenStorage: .shared
                    )
                )
            )
        )
        .environment(LoginSession.shared)
        .environment(UserManager.shared)
    }
}
