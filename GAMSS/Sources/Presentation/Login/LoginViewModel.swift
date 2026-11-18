//
//  LoginViewModel.swift
//  GAMSS
//
//  Created by 이건준 on 7/19/26.
//

import AuthenticationServices
import Combine
import Foundation

@MainActor
final class LoginViewModel: ObservableObject {
    private let loginUseCase: LoginUseCase
    private let analyticsTracker: AnalyticsTracking
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    init(loginUseCase: LoginUseCase, analyticsTracker: AnalyticsTracking = DefaultAnalyticsTracker.shared) {
        self.loginUseCase = loginUseCase
        self.analyticsTracker = analyticsTracker
    }
    
    func login(
        with socialType: SocialType,
        credential: ASAuthorizationAppleIDCredential,
        nonce: String
    ) async {
        isLoading = true
        
        defer {
            isLoading = false
        }
        
        do {
            try await loginUseCase.login(
                with: socialType,
                credential: credential,
                nonce: nonce
            )
        } catch {
            errorMessage = error.localizedDescription
            analyticsTracker.track(.loginFail)
        }
    }
}
