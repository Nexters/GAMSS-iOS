//
//  AnalyticsEvent.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

/// Mixpanel에 기록하는 액션/결과 이벤트. `screen_view`는 `AnalyticsScreen`에서 별도로 다룬다.
enum AnalyticsEvent {
    // 로그인
    case loginClick
    case loginSuccess
    case loginFail
    case loginCancel

    // 온보딩
    case onboardingNext(step: Int)
    case onboardingSkip(step: Int)
    case onboardingComplete

    // 홈
    case homeSubmit

    // 대화방
    case chatSend
    case chatSendBlocked
    case chatSendFail
    case chatEndRequest
    case chatEndCancel
    case chatEndConfirm
    case cardCreateSuccess
    case cardCreateFail
    case cardFoldStep(stage: String)

    // 대화 목록
    case chatListCardClick
    case chatSearch
    case chatDeleteConfirm

    // 보관함
    case archiveMonthChange(emotion: Emotion, yearMonth: String)
    case archiveCardOpen(emotion: Emotion)
    case archiveConversationView(emotion: Emotion)
    case archiveCardDiscard(emotion: Emotion)
    case archiveClear(emotion: Emotion)

    // 파쇄 화면
    case cardShredTap(tapCount: Int, emotion: Emotion, scope: AnalyticsScope)
    case cardShredSuccess(emotion: Emotion, scope: AnalyticsScope)
    case cardShredFail(emotion: Emotion, scope: AnalyticsScope)

    var name: String {
        switch self {
        case .loginClick: "login_click"
        case .loginSuccess: "login_success"
        case .loginFail: "login_fail"
        case .loginCancel: "login_cancel"
        case .onboardingNext: "onboarding_next"
        case .onboardingSkip: "onboarding_skip"
        case .onboardingComplete: "onboarding_complete"
        case .homeSubmit: "home_submit"
        case .chatSend: "chat_send"
        case .chatSendBlocked: "chat_send_blocked"
        case .chatSendFail: "chat_send_fail"
        case .chatEndRequest: "chat_end_request"
        case .chatEndCancel: "chat_end_cancel"
        case .chatEndConfirm: "chat_end_confirm"
        case .cardCreateSuccess: "card_create_success"
        case .cardCreateFail: "card_create_fail"
        case .cardFoldStep: "card_fold_step"
        case .chatListCardClick: "chat_list_card_click"
        case .chatSearch: "chat_search"
        case .chatDeleteConfirm: "chat_delete_confirm"
        case .archiveMonthChange: "archive_month_change"
        case .archiveCardOpen: "archive_card_open"
        case .archiveConversationView: "archive_conversation_view"
        case .archiveCardDiscard: "archive_card_discard"
        case .archiveClear: "archive_clear"
        case .cardShredTap: "card_shred_tap"
        case .cardShredSuccess: "card_shred_success"
        case .cardShredFail: "card_shred_fail"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .onboardingNext(let step), .onboardingSkip(let step):
            ["step": step]
        case .cardFoldStep(let stage):
            ["stage": stage]
        case .archiveMonthChange(let emotion, let yearMonth):
            ["emotion": emotion.analyticsValue, "year_month": yearMonth]
        case .archiveCardOpen(let emotion),
             .archiveConversationView(let emotion),
             .archiveCardDiscard(let emotion),
             .archiveClear(let emotion):
            ["emotion": emotion.analyticsValue]
        case .cardShredTap(let tapCount, let emotion, let scope):
            ["tap_count": tapCount, "emotion": emotion.analyticsValue, "scope": scope.rawValue]
        case .cardShredSuccess(let emotion, let scope),
             .cardShredFail(let emotion, let scope):
            ["emotion": emotion.analyticsValue, "scope": scope.rawValue]
        default:
            [:]
        }
    }
}
