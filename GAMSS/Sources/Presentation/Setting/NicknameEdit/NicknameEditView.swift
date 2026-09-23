//
//  NicknameEditView.swift
//  GAMSS
//
//  Created by 이건준 on 8/16/26.
//

import SwiftUI

struct NicknameEditView: View {
    @StateObject private var viewModel: NicknameEditViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    
    init(viewModel: NicknameEditViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationBarView(title: "닉네임 변경", onBack: { dismiss() })

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 16)
                Text("변경할 닉네임을 입력해주세요.")
                    .padding(.bottom, 12)
                TextField(
                    text: Binding(
                        get: { viewModel.editingNickname },
                        set: { viewModel.updateEditingNickname($0) }
                    )
                ) {
                    EmptyView()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .overlay(
                    Rectangle()
                        .strokeBorder(Color.colorGray950, lineWidth: 1)
                )
                
                Text(viewModel.errorMessage ?? "")
                    .typography(.body5Medium)
                    .foregroundStyle(Color.colorRed)
                    .padding(.top, 8)
                
                Spacer()
                
                Button {
                    Task {
                        let success = await viewModel.updateNickname()
                        if success {
                            dismiss()
                        }
                    }
                } label: {
                    Text("저장하기")
                        .typography(.title5)
                        .foregroundStyle(
                            viewModel.isEnabledSaveButton
                            ? Color.colorWhite
                            : Color.colorGray300
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            viewModel.isEnabledSaveButton
                            ? Color.colorGray950
                            : Color.colorGray075
                        )
                        .clipShape(
                            RoundedRectangle(cornerRadius: 12)
                        )
                }
                .disabled(!viewModel.isEnabledSaveButton)
            }
            .padding(.horizontal, Spacing.spacing350)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hidesTabBar()
    }
}
