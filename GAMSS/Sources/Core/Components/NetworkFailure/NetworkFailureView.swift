//
//  NetworkFailureView.swift
//  GAMSS
//
//  Created by cchanmi on 9/26/26.
//

import SwiftUI

/// 네트워크 연결이 끊겨 콘텐츠를 불러오지 못했을 때, 해당 콘텐츠 영역 전체를 대체해 보여주는 안내 화면.
/// 네비게이션 바/탭바는 그대로 두고 콘텐츠 영역에서만 사용한다.
struct NetworkFailureView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.spacing300) {
            Image("networkErrorIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            VStack(spacing: Spacing.spacing050) {
                Text("네트워크에 접속할 수 없습니다.")
                    .typography(.subtitle3)
                    .foregroundStyle(Color.colorGray950)

                Text("네트워크 연결 상태를 확인해주세요.")
                    .typography(.body5Regular)
                    .foregroundStyle(Color.colorGray500)
            }

            Button(action: onRetry) {
                Text("재시도")
                    .typography(.subtitle4)
                    .foregroundStyle(Color.colorWhite)
                    .frame(width: 237, height: 52)
                    .background(Color.colorGray950)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.radius200))
            }
            .padding(.top, Spacing.spacing100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    NetworkFailureView(onRetry: {})
}
