//
//  AnalyticsScreenTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import XCTest
@testable import GAMSS

final class AnalyticsScreenTests: XCTestCase {
    func test_login_hasNoProperties() {
        let screen = AnalyticsScreen.login
        XCTAssertEqual(screen.name, "login")
        XCTAssertTrue(screen.properties.isEmpty)
    }

    func test_cardDelete_includesEmotionAndScope() {
        let screen = AnalyticsScreen.cardDelete(emotion: .sad, scope: .emotionAll)
        XCTAssertEqual(screen.name, "card_delete")
        XCTAssertEqual(screen.properties["emotion"] as? String, "sadness")
        XCTAssertEqual(screen.properties["scope"] as? String, "emotion_all")
    }

    func test_webview_includesPage() {
        let screen = AnalyticsScreen.webview(page: .privacyPolicy)
        XCTAssertEqual(screen.name, "webview")
        XCTAssertEqual(screen.properties["page"] as? String, "privacypolicy")
    }
}
