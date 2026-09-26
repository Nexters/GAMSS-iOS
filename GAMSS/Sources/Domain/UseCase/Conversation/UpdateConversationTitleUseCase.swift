//
//  UpdateConversationTitleUseCase.swift
//  GAMSS
//
//  Created by cchanmi on 8/14/26.
//

import Foundation

struct UpdateConversationTitleUseCase {
    /// 서버가 허용하는 채팅방 제목 최대 길이(100자)에 맞춘다. 메시지 최대 길이(140자)보다
    /// 짧기 때문에, 긴 첫 메시지를 제목으로 그대로 보내면 서버가 거절한다.
    static let maxTitleLength = 100

    private let conversationRepository: ConversationRepository

    init(conversationRepository: ConversationRepository) {
        self.conversationRepository = conversationRepository
    }

    func execute(conversationId: Int, title: String) async throws {
        let truncatedTitle = String(title.prefix(Self.maxTitleLength))
        try await conversationRepository.updateTitle(conversationId: conversationId, title: truncatedTitle)
    }
}
