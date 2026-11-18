//
//  CardShredViewModel.swift
//  GAMSS
//
//  Created by 이건준 on 8/21/26.
//

import Combine
import Foundation

enum CardShredMode: Hashable, Identifiable {
    case single(cardId: Int)
    case all

    var id: Self { self }
}

@MainActor
final class CardShredViewModel: ObservableObject {
    @Published private(set) var step = 0
    @Published private(set) var isSubmitting = false
    @Published private(set) var toastMessage: String?

    let emotion: Emotion
    private let mode: CardShredMode
    private let deleteCardUseCase: DeleteCardUseCase?
    private let deleteAllCardUseCase: DeleteAllCardUseCase?
    private let analyticsTracker: AnalyticsTracking
    private let requiredSteps = 4
    private var toastDismissTask: Task<Void, Never>?

    static let shredFailureToastMessage = "파쇄에 실패했어요. 다시 시도해주세요"

    var analyticsScope: AnalyticsScope {
        switch mode {
        case .single: .single
        case .all: .emotionAll
        }
    }

    init(
        emotion: Emotion,
        cardId: Int,
        deleteCardUseCase: DeleteCardUseCase,
        analyticsTracker: AnalyticsTracking = DefaultAnalyticsTracker.shared
    ) {
        self.emotion = emotion
        self.mode = .single(cardId: cardId)
        self.deleteCardUseCase = deleteCardUseCase
        self.deleteAllCardUseCase = nil
        self.analyticsTracker = analyticsTracker
    }

    init(
        emotion: Emotion,
        deleteAllCardUseCase: DeleteAllCardUseCase,
        analyticsTracker: AnalyticsTracking = DefaultAnalyticsTracker.shared
    ) {
        self.emotion = emotion
        self.mode = .all
        self.deleteCardUseCase = nil
        self.deleteAllCardUseCase = deleteAllCardUseCase
        self.analyticsTracker = analyticsTracker
    }

    var isPowerOn: Bool {
        step > 0 && step < requiredSteps
    }

    var isShredEnabled: Bool {
        step >= requiredSteps
    }

    var progress: CGFloat {
        CGFloat(step) / CGFloat(requiredSteps)
    }

    func advance() {
        guard step < requiredSteps else { return }
        step += 1
        trackTap(tapCount: step)
    }

    func reset() {
        step = 0
    }

    @discardableResult
    func shred() async -> Bool {
        guard isShredEnabled, !isSubmitting else { return false }

        isSubmitting = true
        defer { isSubmitting = false }
        trackTap(tapCount: step + 1)

        do {
            switch mode {
            case .single(let cardId):
                guard let deleteCardUseCase else { return false }
                try await deleteCardUseCase.execute(cardId: cardId)
            case .all:
                guard let deleteAllCardUseCase else { return false }
                try await deleteAllCardUseCase.execute()
            }
            analyticsTracker.track(.cardShredSuccess(emotion: emotion, scope: analyticsScope))
            return true
        } catch {
            analyticsTracker.track(.cardShredFail(emotion: emotion, scope: analyticsScope))
            return false
        }
    }

    func showShredFailureToast() {
        toastMessage = Self.shredFailureToastMessage
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    /// `advance()`(접는 탭)와 `shred()`(마지막 파쇄 탭) 양쪽에서 호출해, 탭마다 하나씩
    /// `card_shred_tap`을 기록한다. `isShredEnabled`(= `step >= requiredSteps`)는 마지막
    /// `advance()` 호출 후와 그 다음 `shred()` 호출 양쪽에서 똑같이 true라 두 경우를
    /// 구분하지 못하므로, 호출부가 직접 자신의 탭 번호를 넘긴다.
    private func trackTap(tapCount: Int) {
        analyticsTracker.track(.cardShredTap(tapCount: tapCount, emotion: emotion, scope: analyticsScope))
    }
}
