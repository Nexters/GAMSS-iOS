//
//  NicknameEditViewModel.swift
//  GAMSS
//
//  Created by 이건준 on 8/16/26.
//

import Combine
import Foundation

@MainActor
final class NicknameEditViewModel: ObservableObject {
    private let updateNicknameUseCase: UpdateNicknameUseCase
    private var toastDismissTask: Task<Void, Never>?

    static let networkUnreachableToastMessage = "네트워크 연결을 확인해주세요"

    private let currentNickname: String
    @Published private(set) var editingNickname: String = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var toastMessage: String?

    var isEnabledSaveButton: Bool {
        let length = editingNickname.count
        
        return editingNickname != currentNickname
        && length >= NicknamePolicy.minimumLength
        && length <= NicknamePolicy.maximumLength
    }

    init(
        updateNicknameUseCase: UpdateNicknameUseCase,
        currentNickname: String = ""
    ) {
        self.updateNicknameUseCase = updateNicknameUseCase
        self.currentNickname = currentNickname
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
        } catch NetworkError.noConnection {
            showToast(Self.networkUnreachableToastMessage)
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
