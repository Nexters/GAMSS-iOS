//
//  ConversationListEmptyView.swift
//  GAMSS
//
//  Created by cchanmi on 8/13/26.
//

import SwiftUI

/// 미완료 대화방이 하나도 없을 때 리스트 영역에 표시하는 안내 문구.
struct ConversationListEmptyView: View {
    var body: some View {
        Text("아직 나눈 대화가 없어요")
            .typography(.body3Regular)
            .foregroundStyle(Color.colorGray500)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ConversationListEmptyView()
}
