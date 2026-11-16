//
//  ClickerKeycapBadge.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

/// 키캡 위에 얹는 장식. 정식 키캡 이미지가 들어오기 전까지 분홍 원 / 파란 말풍선으로 왼쪽·오른쪽 키를 구분한다.
struct ClickerKeycapBadge: View {
    let style: ClickerKeyStyle
    let syllable: String
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            badgeBackground
            Text(syllable)
                .font(.custom(FontWeight.bold.postScriptName(), size: size * 0.38))
                .foregroundStyle(Color.colorWhite)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badgeBackground: some View {
        switch style {
        case .pink:
            ZStack {
                Circle()
                    .fill(Color.colorGray950)
                    .frame(width: size, height: size)
                Circle()
                    .fill(Color.colorPink)
                    .frame(width: size * 0.72, height: size * 0.72)
            }
        case .blue:
            SpeechBubbleShape()
                .fill(Color.colorBlue)
                .frame(width: size, height: size)
        }
    }
}

private struct SpeechBubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let corner = min(rect.width, rect.height) * 0.38
        var path = Path(
            roundedRect: CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height * 0.82
            ),
            cornerRadius: corner
        )
        let tail = Path { tailPath in
            tailPath.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.height * 0.72))
            tailPath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
            tailPath.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.height * 0.78))
            tailPath.closeSubpath()
        }
        path.addPath(tail)
        return path
    }
}

#Preview {
    HStack(spacing: Spacing.spacing400) {
        ClickerKeycapBadge(style: .pink, syllable: "이")
        ClickerKeycapBadge(style: .blue, syllable: "이")
    }
    .padding()
}
