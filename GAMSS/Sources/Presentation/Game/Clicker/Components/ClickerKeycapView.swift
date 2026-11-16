//
//  ClickerKeycapView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

struct ClickerKeycapView: View {
    let style: ClickerKeyStyle
    let syllable: String
    let isEnabled: Bool
    let action: () -> Void

    private let keySize: CGFloat = 132

    var body: some View {
        Button(action: action) {
            Image("clicker")
                .resizable()
                .scaledToFit()
                .frame(width: keySize, height: keySize)
                .overlay(alignment: badgeAlignment) {
                    ClickerKeycapBadge(style: style, syllable: syllable, size: 46)
                        .offset(badgeOffset)
                }
        }
        .buttonStyle(ClickerKeyButtonStyle())
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private var badgeAlignment: Alignment {
        switch style {
        case .pink: .topLeading
        case .blue: .topTrailing
        }
    }

    private var badgeOffset: CGSize {
        switch style {
        case .pink: CGSize(width: 10, height: 8)
        case .blue: CGSize(width: -10, height: 8)
        }
    }

    private var accessibilityLabel: String {
        switch style {
        case .pink: "분홍 키 \(syllable)"
        case .blue: "파란 키 \(syllable)"
        }
    }
}

/// 물리 키를 누르는 느낌으로 살짝 내려가게 한다.
private struct ClickerKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

#Preview {
    HStack(spacing: Spacing.spacing700) {
        ClickerKeycapView(style: .pink, syllable: "이", isEnabled: true, action: {})
        ClickerKeycapView(style: .blue, syllable: "이", isEnabled: true, action: {})
    }
    .padding()
}
