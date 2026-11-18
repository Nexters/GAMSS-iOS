//
//  AnalyticsScreen.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

/// `screen_view` 이벤트의 화면 값과 추가 속성.
enum AnalyticsScreen {
    case login
    case onboarding
    case home
    case chatList
    case chatRoom
    case archive
    case archiveDetail(emotion: Emotion)
    case cardDelete(emotion: Emotion, scope: AnalyticsScope)
    case setting
    case accountInfo
    case nicknameChange
    case webview(page: WebviewPage)

    var name: String {
        switch self {
        case .login: "login"
        case .onboarding: "onboarding"
        case .home: "home"
        case .chatList: "chat_list"
        case .chatRoom: "chat_room"
        case .archive: "archive"
        case .archiveDetail: "archive_detail"
        case .cardDelete: "card_delete"
        case .setting: "setting"
        case .accountInfo: "account_info"
        case .nicknameChange: "nickname_change"
        case .webview: "webview"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .archiveDetail(let emotion):
            ["emotion": emotion.analyticsValue]
        case .cardDelete(let emotion, let scope):
            ["emotion": emotion.analyticsValue, "scope": scope.rawValue]
        case .webview(let page):
            ["page": page.rawValue]
        default:
            [:]
        }
    }
}
