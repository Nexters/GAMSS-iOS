//
//  DefaultUpdateNicknameUseCase.swift
//  GAMSS
//
//  Created by 이건준 on 8/16/26.
//

import Foundation

struct DefaultUpdateNicknameUseCase: UpdateNicknameUseCase {
    private let memberRepository: MemberRepository
    private let userManager: UserManager
    
    init(memberRepository: MemberRepository, userManager: UserManager) {
        self.memberRepository = memberRepository
        self.userManager = userManager
    }
    
    func execute(_ nickname: String) async throws {
        let nicknameLength = nickname.count
        guard nicknameLength >= NicknamePolicy.minimumLength
            && nicknameLength <= NicknamePolicy.maximumLength else {
            throw AccountError.invalidNickname
        }
        let updatedUser = try await memberRepository.updateNickname(nickname)
        userManager.user = updatedUser
    }
}
