//
//  AccountViewModel.swift
//  GAMSS
//
//  Created by LEEGEONJUN on 8/13/26.
//

import Combine
import Foundation

@MainActor
final class AccountViewModel: ObservableObject {
    private let logoutUseCase: LogoutUseCase
    private let deleteMemberUseCase: DeleteMemberUseCase
    private let userManager: UserManager
    private var toastDismissTask: Task<Void, Never>?
    
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    
    init(
        logoutUseCase: LogoutUseCase,
        deleteMemberUseCase: DeleteMemberUseCase,
        userManager: UserManager = .shared
    ) {
        self.logoutUseCase = logoutUseCase
        self.deleteMemberUseCase = deleteMemberUseCase
        self.userManager = userManager
    }
    
    func deleteMember() async {
        do {
            try await deleteMemberUseCase.execute()
        } catch NetworkError.noConnection {
            showToast("네트워크 연결을 확인해주세요")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func logout() async {
        do {
            try await logoutUseCase.logout()
            userManager.user = nil
        } catch NetworkError.noConnection {
            showToast("네트워크 연결을 확인해주세요")
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
