//
//  AnalyticsEventTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

final class AnalyticsEventTests: XCTestCase {
    func test_loginClick_hasNoProperties() {
        let event = AnalyticsEvent.loginClick
        XCTAssertEqual(event.name, "login_click")
        XCTAssertTrue(event.properties.isEmpty)
    }

    func test_onboardingNext_includesStep() {
        let event = AnalyticsEvent.onboardingNext(step: 2)
        XCTAssertEqual(event.name, "onboarding_next")
        XCTAssertEqual(event.properties["step"] as? Int, 2)
    }

    func test_cardShredTap_includesTapCountEmotionAndScope() {
        let event = AnalyticsEvent.cardShredTap(tapCount: 3, emotion: .angry, scope: .single)
        XCTAssertEqual(event.name, "card_shred_tap")
        XCTAssertEqual(event.properties["tap_count"] as? Int, 3)
        XCTAssertEqual(event.properties["emotion"] as? String, "anger")
        XCTAssertEqual(event.properties["scope"] as? String, "single")
    }

    func test_archiveMonthChange_includesEmotionAndYearMonth() {
        let event = AnalyticsEvent.archiveMonthChange(emotion: .heartache, yearMonth: "2026-11")
        XCTAssertEqual(event.name, "archive_month_change")
        XCTAssertEqual(event.properties["emotion"] as? String, "prickly")
        XCTAssertEqual(event.properties["year_month"] as? String, "2026-11")
    }
}
