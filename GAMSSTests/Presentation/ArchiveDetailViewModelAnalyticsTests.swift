//
//  ArchiveDetailViewModelAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

private final class MockFetchCardsByDateUseCase: FetchCardsByDateUseCase {
    func execute(yearMonth: Date) async throws -> [DailyEmotion] { [] }
}

private final class MockDeleteAllCardUseCase: DeleteAllCardUseCase {
    func execute() async throws {}
}

private final class MockAnalyticsTracking: AnalyticsTracking {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func trackScreen(_ screen: AnalyticsScreen) {}
}

@MainActor
final class ArchiveDetailViewModelAnalyticsTests: XCTestCase {
    func test_selectMonth_tracksArchiveMonthChangeWithEmotionAndYearMonth() async {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = ArchiveDetailViewModel(
            emotion: .angry,
            fetchCardsByDateUseCase: MockFetchCardsByDateUseCase(),
            deleteAllCardUseCase: MockDeleteAllCardUseCase(),
            analyticsTracker: analyticsTracker
        )
        let newMonth = DateFormatterFactory.yearMonthWithHypen.date(from: "2026-11") ?? Date()

        await viewModel.selectMonth(newMonth)

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["archive_month_change"])
        XCTAssertEqual(analyticsTracker.trackedEvents.first?.properties["emotion"] as? String, "anger")
        XCTAssertEqual(analyticsTracker.trackedEvents.first?.properties["year_month"] as? String, "2026-11")
    }
}
