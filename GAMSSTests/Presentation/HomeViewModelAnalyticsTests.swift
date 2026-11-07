//
//  HomeViewModelAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

private final class MockFetchMyProfileUseCase: FetchMyProfileUseCase {
    func execute() async throws -> User {
        throw SummaryError.inferenceFailed()
    }
}

private final class MockMemberRepository: MemberRepository {
    func deleteMember() async throws { fatalError("not used in this test") }
    func fetchMyProfile() async throws -> User { fatalError("not used in this test") }
    func updateNickname(_ nickname: String) async throws -> User { fatalError("not used in this test") }
    func fetchTokenUsage() async throws -> TokenUsage { fatalError("not used in this test") }
}

private final class MockAnalyticsTracking: AnalyticsTracking {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func trackScreen(_ screen: AnalyticsScreen) {}
}

@MainActor
final class HomeViewModelAnalyticsTests: XCTestCase {
    func test_send_onSuccess_tracksHomeSubmit() {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = HomeViewModel(
            fetchMyProfileUseCase: MockFetchMyProfileUseCase(),
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: MockMemberRepository()),
            analyticsTracker: analyticsTracker
        )
        viewModel.input = "오늘 하루 있었던 일"

        viewModel.send()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["home_submit"])
    }

    func test_send_whenInputEmpty_doesNotTrack() {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = HomeViewModel(
            fetchMyProfileUseCase: MockFetchMyProfileUseCase(),
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: MockMemberRepository()),
            analyticsTracker: analyticsTracker
        )
        viewModel.input = "   "

        viewModel.send()

        XCTAssertTrue(analyticsTracker.trackedEvents.isEmpty)
    }
}
