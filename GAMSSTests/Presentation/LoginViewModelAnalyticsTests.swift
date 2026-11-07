//
//  LoginViewModelAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import AuthenticationServices
import XCTest
@testable import GAMSS

private final class MockAnalyticsTracking: AnalyticsTracking {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func trackScreen(_ screen: AnalyticsScreen) {}
}

@MainActor
final class LoginViewModelAnalyticsTests: XCTestCase {
    func test_init_acceptsAnalyticsTrackerWithoutCrashing() {
        let analyticsTracker = MockAnalyticsTracking()
        let useCase = DefaultLoginUseCase(authRepository: StubAuthRepository())
        let viewModel = LoginViewModel(loginUseCase: useCase, analyticsTracker: analyticsTracker)

        XCTAssertNotNil(viewModel)
    }
}

private final class StubAuthRepository: AuthRepository {
    func login(with socialType: SocialType, credential: ASAuthorizationAppleIDCredential, nonce: String) async throws {}
    func autoLogin() async throws {}
    func logout() async throws {}
}
