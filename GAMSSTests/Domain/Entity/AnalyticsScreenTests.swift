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

    /// 대화 본문, 카드 내용, 검색어, 닉네임, 대화 id, 카드 id는 어떤 화면에도 포함되지 않아야 한다
    /// (설계 문서 공통 규칙). enum의 모든 case를 순회해 속성 키가 허용 목록 밖으로 새지 않는지 확인한다.
    func test_allScreens_neverExposeForbiddenPropertyKeys() {
        let allowedKeys: Set<String> = ["emotion", "scope", "page"]
        let forbiddenKeys: Set<String> = [
            "conversation_id", "conversationId", "card_id", "cardId",
            "nickname", "message", "content", "query", "search_query", "text"
        ]
        let sampleScreens: [AnalyticsScreen] = [
            .login, .onboarding, .home, .chatList, .chatRoom, .archive,
            .archiveDetail(emotion: .angry),
            .cardDelete(emotion: .angry, scope: .single),
            .setting, .accountInfo, .nicknameChange,
            .webview(page: .privacyPolicy)
        ]

        for screen in sampleScreens {
            let keys = Set(screen.properties.keys)
            XCTAssertTrue(keys.isSubset(of: allowedKeys), "\(screen.name) exposes unexpected keys: \(keys.subtracting(allowedKeys))")
            XCTAssertTrue(keys.isDisjoint(with: forbiddenKeys), "\(screen.name) exposes forbidden keys: \(keys.intersection(forbiddenKeys))")
        }
    }
}
