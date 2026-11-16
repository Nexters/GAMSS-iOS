//
//  ClickerPrompt.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

/// 눌러눌러 하단 키 두 개의 스타일. 캐릭터 위 목표 키캡과 같은 값을 맞춰 누르면 득점한다.
enum ClickerKeyStyle: CaseIterable, Equatable, Hashable {
    case pink
    case blue

    var fillColor: Color {
        switch self {
        case .pink: .colorPink
        case .blue: .colorBlue
        }
    }
}

struct ClickerPrompt: Equatable, Identifiable {
    let id: UUID
    let style: ClickerKeyStyle
    let syllable: String

    init(id: UUID = UUID(), style: ClickerKeyStyle, syllable: String) {
        self.id = id
        self.style = style
        self.syllable = syllable
    }
}

protocol ClickerPromptProviding {
    func next() -> ClickerPrompt
}

/// 키캡 전용 이미지가 들어오기 전까지 기존 한글 음절로 목표를 섞는다.
struct RandomClickerPromptProvider: ClickerPromptProviding {
    static let syllables = ["이", "가", "나", "다", "라", "마", "바", "사", "아", "자"]

    func next() -> ClickerPrompt {
        ClickerPrompt(
            style: ClickerKeyStyle.allCases.randomElement() ?? .pink,
            syllable: Self.syllables.randomElement() ?? "이"
        )
    }
}
