//
//  ConversationHistoryViewModel.swift
//  GAMSS
//
//  Created by cchanmi on 8/17/26.
//

import Combine
import Foundation

@MainActor
final class ConversationHistoryViewModel: ObservableObject {
    @Published private(set) var messages: [Message] = []
    @Published private(set) var isLoading = false
    @Published var alertMessage: String?

    private let getMessagesUseCase: GetMessagesUseCase
    private var loadedConversationId: Int?

    init(getMessagesUseCase: GetMessagesUseCase) {
        self.getMessagesUseCase = getMessagesUseCase
    }

    /// 같은 대화를 이미 불러온 적 있으면 재조회하지 않는다 — 카드 ↔ 대화 모드를 여러 번
    /// 오가도 네트워크 요청은 한 번만 나간다.
    func loadMessagesIfNeeded(conversationId: Int) async {
        guard loadedConversationId != conversationId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await getMessagesUseCase.execute(conversationId: conversationId)
            loadedConversationId = conversationId
        } catch {
            alertMessage = "대화를 불러오지 못했어요"
        }
    }

    /// 실패 알럿의 "다시 시도"에서만 호출한다 — 캐시를 지우고 다시 조회한다.
    func retryLoad(conversationId: Int) async {
        loadedConversationId = nil
        await loadMessagesIfNeeded(conversationId: conversationId)
    }

    /// "대화보기" 탭 시 화면을 넘기기 전에 먼저 호출한다. 네트워크가 끊겨 있으면 화면 전환
    /// 자체를 막도록 false를 돌려준다 — 호출부가 화면 대신 토스트로 안내한다. 성공하면
    /// messages가 이미 채워져 화면 진입 후 다시 조회하지 않는다. 그 외 실패는 기존처럼
    /// 화면을 넘긴 뒤 alertMessage로 안내한다.
    func canShowConversation(conversationId: Int) async -> Bool {
        guard loadedConversationId != conversationId else { return true }
        isLoading = true
        defer { isLoading = false }
        do {
            messages = try await getMessagesUseCase.execute(conversationId: conversationId)
            loadedConversationId = conversationId
            return true
        } catch NetworkError.noConnection {
            return false
        } catch {
            return true
        }
    }

    func quotedMessage(for message: Message) -> Message? {
        guard let repliesToMessageId = message.repliesToMessageId else { return nil }
        return messages.first { $0.id == repliesToMessageId }
    }
}
