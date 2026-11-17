//
//  GameListItem.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import Foundation

/// 게임 목록에 노출할 미니게임. 탭바 연동 전에 화면만 먼저 붙이기 위한 카탈로그다.
enum GameListItem: String, CaseIterable, Identifiable, Hashable {
    case clicker

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clicker: "눌러눌러"
        }
    }

    var illustrationImageName: String {
        switch self {
        case .clicker: "angry_clicker"
        }
    }
}
