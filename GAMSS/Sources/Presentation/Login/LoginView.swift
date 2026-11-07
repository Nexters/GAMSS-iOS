//
//  LoginView.swift
//  GAMSS
//
//  Created by 이건준 on 7/12/26.
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @SwiftUI.Environment(LoginSession.self) private var loginState
    @StateObject private var viewModel: LoginViewModel
    @State private var currentNonce: String?
    private let analyticsTracker: AnalyticsTracking

    init(viewModel: LoginViewModel, analyticsTracker: AnalyticsTracking = DefaultAnalyticsTracker.shared) {
        _viewModel = StateObject(
            wrappedValue: viewModel
        )
        self.analyticsTracker = analyticsTracker
    }
    
    var body: some View {
        VStack(alignment: .center) {
            Spacer()
            
            Image(.logoGamss)
                .padding(.bottom, 12)
            Text("오늘의 감정을 비워보세요")
                .foregroundStyle(Color.colorGray950)
                .typography(.subtitle2)
                .padding(.bottom, 32)
            Image(.emotions)
                .resizable()
                .scaledToFit()
                .padding(.bottom, 54)
                .padding(.horizontal, 31)
            
            SignInWithAppleButton(.signIn) { request in
                analyticsTracker.track(.loginClick)
                let nonce = NonceGenerator.generate()
                currentNonce = nonce
                
                request.requestedScopes = [
                    .fullName,
                    .email
                ]
                
                request.nonce = NonceGenerator.sha256(nonce)
            } onCompletion: { result in
                switch result {
                case .success(let authorization):
                    guard let credential = authorization.credential
                            as? ASAuthorizationAppleIDCredential,
                          let nonce = currentNonce
                    else {
                        return
                    }
                    
                    Task {
                        await viewModel.login(
                            with: .apple,
                            credential: credential,
                            nonce: nonce
                        )
                        loginState.value = LoginState.current
                        if loginState.value == .loggedIn {
                            analyticsTracker.track(.loginSuccess)
                        }
                    }
                case .failure(let error):
                    if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                        analyticsTracker.track(.loginCancel)
                    } else {
                        analyticsTracker.track(.loginFail)
                    }
                    Log.debug(error.localizedDescription)
                }
            }
            .frame(height: 54)
            .padding(.horizontal, 18)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.colorWhite)
        .trackScreen(.login)
    }
}
