//
//  ConversationRowView.swift
//  GAMSS
//
//  Created by cchanmi on 8/13/26.
//

import SwiftUI

/// 대화방 목록의 카드 한 장. 좌측엔 미리보기 텍스트(대화방 title — 사용자가 대화를 처음 시작할 때
/// 보낸 문장이 서버에 title로 저장된다, 25자 초과 시 말줄임), 우측엔 생성 시각을 보여준다.
struct ConversationRowView: View {
    let currentMode: ConversationMode
    let conversation: ConversationSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: Spacing.spacing200) {
            selectionView

            Text(
                ConversationPreviewTextFormatter.truncated(
                    conversation.title ?? "제목 없는 대화"
                )
            )
            .typography(.body4Medium)
            .foregroundStyle(Color.colorGray950)
            .lineLimit(1)
            .truncationMode(.tail)

            Spacer(minLength: Spacing.spacing200)

            Text(
                MessageTimestampFormatter.string(
                    from: conversation.createdAt
                )
            )
            .typography(.body5Regular)
            .foregroundStyle(Color.colorGray600)
        }
        .padding(Spacing.spacing300)
        .background(Color.colorGray025)
        .overlay(
            Rectangle()
                .strokeBorder(Color.colorGray950, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var selectionView: some View {
        switch currentMode {
        case .normal:
            EmptyView()

        case .delete:
            if isSelected {
                Image(.redMinusCircleFill)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .stroke(Color.colorGray400)
                    .frame(width: 16, height: 16)
            }
        }
    }
}
