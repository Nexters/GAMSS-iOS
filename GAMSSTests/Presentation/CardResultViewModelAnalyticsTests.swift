//
//  CardResultViewModelAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

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
final class CardResultViewModelAnalyticsTests: XCTestCase {
    func test_advanceStage_tracksCardFoldStepWithNewStage() {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = CardResultViewModel(analyticsTracker: analyticsTracker)

        viewModel.advanceStage()
        viewModel.advanceStage()

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["card_fold_step", "card_fold_step"])
        XCTAssertEqual(analyticsTracker.trackedEvents.map { $0.properties["stage"] as? String }, ["foldedonce", "readytodiscard"])
    }

    func test_advanceStage_whenAlreadyAtLastStage_doesNotTrackAgain() {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = CardResultViewModel(analyticsTracker: analyticsTracker)
        viewModel.advanceStage()
        viewModel.advanceStage()

        viewModel.advanceStage()

        XCTAssertEqual(analyticsTracker.trackedEvents.count, 2)
    }
}
