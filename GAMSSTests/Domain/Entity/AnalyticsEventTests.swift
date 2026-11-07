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

    /// 대화 본문, 카드 내용, 검색어, 닉네임, 대화 id, 카드 id는 어떤 이벤트에도 포함되지 않아야 한다
    /// (설계 문서 공통 규칙). enum의 모든 case를 순회해 속성 키가 허용 목록 밖으로 새지 않는지 확인한다.
    func test_allEvents_neverExposeForbiddenPropertyKeys() {
        let allowedKeys: Set<String> = ["step", "stage", "emotion", "year_month", "tap_count", "scope"]
        let forbiddenKeys: Set<String> = [
            "conversation_id", "conversationId", "card_id", "cardId",
            "nickname", "message", "content", "query", "search_query", "text"
        ]
        let sampleEvents: [AnalyticsEvent] = [
            .loginClick, .loginSuccess, .loginFail, .loginCancel,
            .onboardingNext(step: 1), .onboardingSkip(step: 1), .onboardingComplete,
            .homeSubmit,
            .chatSend, .chatSendBlocked, .chatSendFail,
            .chatEndRequest, .chatEndCancel, .chatEndConfirm,
            .cardCreateSuccess, .cardCreateFail, .cardFoldStep(stage: "foldedonce"),
            .chatListCardClick, .chatSearch, .chatDeleteConfirm,
            .archiveMonthChange(emotion: .angry, yearMonth: "2026-11"),
            .archiveCardOpen(emotion: .angry),
            .archiveConversationView(emotion: .angry),
            .archiveCardDiscard(emotion: .angry),
            .archiveClear(emotion: .angry),
            .cardShredTap(tapCount: 1, emotion: .angry, scope: .single),
            .cardShredSuccess(emotion: .angry, scope: .single),
            .cardShredFail(emotion: .angry, scope: .single)
        ]

        for event in sampleEvents {
            let keys = Set(event.properties.keys)
            XCTAssertTrue(keys.isSubset(of: allowedKeys), "\(event.name) exposes unexpected keys: \(keys.subtracting(allowedKeys))")
            XCTAssertTrue(keys.isDisjoint(with: forbiddenKeys), "\(event.name) exposes forbidden keys: \(keys.intersection(forbiddenKeys))")
        }
    }
}
