//
//  ClickerPromptBoardView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

/// 테이프가 붙인 종이 위에 캐릭터와 목표 키캡을 올린다. 캐릭터 이미지는 정식 에셋이 오기 전 분노 일러스트를 쓴다.
struct ClickerPromptBoardView: View {
    let prompt: ClickerPrompt
    var size: CGFloat = 268

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.radius050)
                .fill(Color.colorWhite)
                .shadow(color: Color.colorBlack.opacity(0.08), radius: 10, y: 4)

            Image("cardEmotionAnger")
                .resizable()
                .scaledToFit()
                .padding(size * 0.09)

            ClickerTargetOverlay(prompt: prompt)
                .frame(width: size * 0.24, height: size * 0.24)
                .offset(x: size * 0.10, y: -size * 0.03)

            cornerTapes
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(3))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("목표 키 \(prompt.syllable)")
    }

    private var cornerTapes: some View {
        let inset = size * 0.44
        return ZStack {
            paperTape.offset(x: -inset, y: -inset).rotationEffect(.degrees(-38))
            paperTape.offset(x: inset, y: -inset).rotationEffect(.degrees(32))
            paperTape.offset(x: -inset, y: inset).rotationEffect(.degrees(28))
            paperTape.offset(x: inset, y: inset).rotationEffect(.degrees(-34))
        }
        .allowsHitTesting(false)
    }

    private var paperTape: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.colorGray800.opacity(0.82))
            .frame(width: 42, height: 14)
    }
}

/// 캐릭터 위에 얹는 목표 키캡. 하단 키와 같은 뱃지 언어를 써서 무엇을 눌러야 하는지 바로 보이게 한다.
private struct ClickerTargetOverlay: View {
    let prompt: ClickerPrompt

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.colorGray700, Color.colorGray950],
                            center: .top,
                            startRadius: 2,
                            endRadius: side / 2
                        )
                    )
                    .shadow(color: Color.colorBlack.opacity(0.2), radius: 2, y: 2)

                ClickerKeycapBadge(
                    style: prompt.style,
                    syllable: prompt.syllable,
                    size: side * 0.72
                )
            }
            .frame(width: side, height: side)
        }
    }
}

#Preview {
    ClickerPromptBoardView(prompt: ClickerPrompt(style: .pink, syllable: "이"))
        .padding()
        .background(Color.colorGray025)
}
