//
//  ToastView.swift
//  GAMSS
//
//  Created by cchanmi on 9/21/26.
//

import SwiftUI

/// 화면 하단 등에 잠깐 띄우는 단순 안내 문구. 표시/자동 dismiss 타이밍은 호출부가 관리한다.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .typography(.body4Medium)
            .foregroundStyle(Color.colorGray025)
            .padding(.horizontal, Spacing.spacing300)
            .frame(height: 34)
            .background(Color.colorGray800)
            .overlay(Rectangle().strokeBorder(Color.colorGray950, lineWidth: 1))
            .shadow(color: Color.colorBlack.opacity(0.25), radius: 30)
    }
}

#Preview {
    ToastView(message: "메시지는 140자까지 입력할 수 있어요")
        .padding(.vertical, Spacing.spacing300)
        .background(Color.colorGray100)
}
