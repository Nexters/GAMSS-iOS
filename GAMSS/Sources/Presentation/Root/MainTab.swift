//
//  MainTab.swift
//  GAMSS
//
//  Created by cchanmi on 8/10/26.
//

import Foundation

enum MainTab: CaseIterable, Hashable {
    case archive
    case home
    case chat
    case game

    var title: String {
        switch self {
        case .archive: return "보관함"
        case .home: return "홈"
        case .chat: return "대화"
        case .game: return "오락"
        }
    }

    var iconName: String {
        switch self {
        case .archive: return "tabIconArchive"
        case .home: return "tabIconHome"
        case .chat: return "tabIconChat"
        case .game: return "tabIconGame"
        }
    }
}
