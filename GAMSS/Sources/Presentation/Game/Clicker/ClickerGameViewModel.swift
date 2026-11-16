//
//  ClickerGameViewModel.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import Combine
import Foundation

@MainActor
final class ClickerGameViewModel: ObservableObject {
    static let roundDuration: TimeInterval = 30
    static let pointsPerCorrectTap = 1
    static let tickInterval: TimeInterval = 0.1

    @Published private(set) var remainingTime: TimeInterval
    @Published private(set) var score: Int
    @Published private(set) var prompt: ClickerPrompt
    @Published private(set) var isPlaying: Bool
    @Published private(set) var isFinished: Bool

    private let promptProvider: ClickerPromptProviding = RandomClickerPromptProvider()
    private var timerTask: Task<Void, Never>?

    init() {
        remainingTime = Self.roundDuration
        score = 0
        prompt = promptProvider.next()
        isPlaying = false
        isFinished = false
    }

    var formattedScore: String {
        String(format: "%05d", score)
    }

    var formattedTime: String {
        String(format: "%.1f초", remainingTime)
    }

    /// 화면 진입 시 한 번만 돌린다. 이미 진행 중이거나 끝난 라운드를 다시 시작하지 않는다.
    func start() {
        guard !isPlaying, !isFinished else { return }
        beginRound(resetScore: false)
    }

    func restart() {
        beginRound(resetScore: true)
    }

    /// 화면을 떠나면 타이머를 멈추고 라운드를 끝낸다. 백그라운드에서 점수가 계속 쌓이지 않게 한다.
    func stop() {
        timerTask?.cancel()
        timerTask = nil
        if isPlaying {
            isPlaying = false
            isFinished = true
        }
    }

    /// 목표 키캡과 같은 스타일을 누르면 득점하고 다음 목표를 뽑는다. 틀린 키나 종료 뒤에는 점수를 바꾸지 않는다.
    @discardableResult
    func tap(_ style: ClickerKeyStyle) -> Bool {
        guard isPlaying else { return false }
        guard style == prompt.style else { return false }

        score += Self.pointsPerCorrectTap
        prompt = promptProvider.next()
        return true
    }

    /// 0.1초마다 남은 시간을 깎고, 0이 되면 입력을 막는다.
    private func advanceTime(by delta: TimeInterval) {
        guard isPlaying else { return }

        remainingTime = max(0, remainingTime - delta)
        if remainingTime == 0 {
            finishRound()
        }
    }

    private func beginRound(resetScore: Bool) {
        timerTask?.cancel()
        remainingTime = Self.roundDuration
        if resetScore {
            score = 0
            prompt = promptProvider.next()
        }
        isFinished = false
        isPlaying = true
        startTimer()
    }

    private func finishRound() {
        isPlaying = false
        isFinished = true
        timerTask?.cancel()
        timerTask = nil
    }

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(Self.tickInterval * 1000)))
                guard !Task.isCancelled else { return }
                self?.advanceTime(by: Self.tickInterval)
            }
        }
    }
}
