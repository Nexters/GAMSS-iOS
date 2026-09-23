//
//  NicknameEditViewModel.swift
//  GAMSS
//
//  Created by 이건준 on 8/16/26.
//

import Combine
import Foundation

final class NicknameEditViewModel: ObservableObject {
    private let updateNicknameUseCase: UpdateNicknameUseCase

    @Published private(set) var editingNickname: String = ""
    @Published private(set) var errorMessage: String?

    var isEnabledSaveButton: Bool {
        let length = editingNickname.count
        return length >= NicknamePolicy.minimumLength
            && length <= NicknamePolicy.maximumLength
    }

    init(
        updateNicknameUseCase: UpdateNicknameUseCase,
        currentNickname: String = ""
    ) {
        self.updateNicknameUseCase = updateNicknameUseCase
        self.editingNickname = currentNickname
    }

    func updateEditingNickname(_ nickname: String) {
        editingNickname = nickname

        if nickname.count > NicknamePolicy.maximumLength {
            errorMessage = "닉네임은 \(NicknamePolicy.maximumLength)자 이하로 입력해주세요."
        } else if nickname.count < NicknamePolicy.minimumLength {
            errorMessage = "닉네임은 \(NicknamePolicy.minimumLength)자 이상으로 입력해주세요."
        } else {
            errorMessage = nil
        }
    }

    func updateNickname() async -> Bool {
        do {
            try await updateNicknameUseCase.execute(editingNickname)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
