//
//  RootView.swift
//  GAMSS
//
//  Created by 이건준 on 8/12/26.
//

import SwiftUI

struct RootView: View {
    @State private var loginSession = LoginSession.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let loginUseCase: LoginUseCase = DefaultLoginUseCase(
        authRepository: DefaultAuthRepository(
            networkManager: NetworkManager.shared,
            tokenStorage: TokenStorage.shared
        )
    )
    
    var body: some View {
        ZStack {
            switch loginSession.value {
            case .notLoggedIn:
                LoginView(
                    viewModel: LoginViewModel(
                        loginUseCase: loginUseCase
                    )
                )
                
            case .autoLoginPending:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.colorWhite)
                    .task {
                        await performAutoLogin()
                    }
                
            case .loggedIn:
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                        DefaultAnalyticsTracker.shared.track(.onboardingComplete)
                    }
                }
            }
        }
        .task {
            await RefreshRiskLexiconUseCase(repository: DefaultRiskLexiconRepository()).execute()
        }
        .animation(
            .easeInOut(duration: 0.3),
            value: loginSession.value
        )
        .animation(
            .easeInOut(duration: 0.3),
            value: hasCompletedOnboarding
        )
        .environment(loginSession)
        .environment(UserManager.shared)
    }

    private func performAutoLogin() async {
        do {
            try await loginUseCase.autoLogin()
            loginSession.value = .loggedIn
        } catch {
            Log.error("Auto login failed: \(error)")
            TokenStorage.shared.clearSession()
            loginSession.value = .notLoggedIn
        }
    }
}

#Preview {
    RootView()
}
