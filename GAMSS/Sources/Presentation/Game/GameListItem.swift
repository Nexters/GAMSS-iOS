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

    /// 정식 썸네일이 들어오기 전까지 쓰는 기존 감정 일러스트.
    var illustrationImageName: String {
        switch self {
        case .clicker: "cardEmotionAnger"
        }
    }

    /// 카드 위에 겹쳐 놓는 액세서리. 눌러눌러는 키캡 에셋을 그대로 쓴다.
    var accessoryImageName: String {
        switch self {
        case .clicker: "clicker"
        }
    }
}
