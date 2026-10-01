//
//  SettingView.swift
//  GAMSS
//
//  Created by LEEGEONJUN on 8/12/26.
//

import SwiftUI

struct SettingView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var presentedWebPage: WebPage?
    
    var body: some View {
        VStack {
            NavigationBarView(title: "설정", onBack: { dismiss() })
            
            ForEach(SettingSection.allCases) { section in
                ForEach(section.items) { item in
                    settingItem(item)
                        .padding(.horizontal, 18)
                    
                    if item.showsDividerBelow {
                        fullWidthDivider
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.colorWhite)
        .hidesTabBar()
        .sheet(item: $presentedWebPage) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
    }
    
    private var fullWidthDivider: some View {
        Color.colorGray075
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    private func settingItem(_ item: SettingItem) -> some View {
        let row = MenuListItemView(
            title: item.title,
            badgeText: nil,
            trailingText: item == .appVersion ? Environment.appVersion : nil
        )
        
        switch item.action {
        case .navigate:
            NavigationLink {
                destination(for: item)
            } label: {
                row
            }
            .buttonStyle(.plain)
            
        case let .web(urlString):
            Button {
                presentWeb(urlString)
            } label: {
                row
            }
            .buttonStyle(.plain)
            
        case .none:
            row
        }
    }
    
    @ViewBuilder
    private func destination(for item: SettingItem) -> some View {
        switch item {
        case .accountInfo:
            AccountView(
                title: item.title,
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
        case .privacyPolicy, .appVersion:
            EmptyView()
        }
    }
    
    private func presentWeb(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        presentedWebPage = WebPage(url: url)
    }
}

private struct WebPage: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    NavigationStack {
        SettingView()
    }
}
