//
//  EmotionAnalyticsTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

final class EmotionAnalyticsTests: XCTestCase {
    func test_analyticsValue_mapsAllSixCasesToLowercaseEnglish() {
        XCTAssertEqual(Emotion.angry.analyticsValue, "anger")
        XCTAssertEqual(Emotion.happy.analyticsValue, "joy")
        XCTAssertEqual(Emotion.anxious.analyticsValue, "anxiety")
        XCTAssertEqual(Emotion.embarrassed.analyticsValue, "quirky")
        XCTAssertEqual(Emotion.sad.analyticsValue, "sadness")
        XCTAssertEqual(Emotion.heartache.analyticsValue, "prickly")
    }
}
