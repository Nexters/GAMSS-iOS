//
//  ConversationSearchEmptyView.swift
//  GAMSS
//
//  Created by 이건준 on 10/1/26.
//

import SwiftUI

/// 검색 결과가 없을 때 리스트 영역에 표시하는 안내 화면.
struct ConversationSearchEmptyView: View {
    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(Color.colorGray400)
                .padding(.bottom, Spacing.spacing300)

            Text("찾으시는 결과가 없어요.")
                .typography(.subtitle2)
                .foregroundStyle(Color.colorGray950)
                .padding(.bottom, Spacing.spacing100)

            Text("다른 검색어로 다시 찾아보세요.")
                .typography(.body5Regular)
                .foregroundStyle(Color.colorGray500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ConversationSearchEmptyView()
}
