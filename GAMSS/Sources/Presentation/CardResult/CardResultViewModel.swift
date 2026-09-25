//
//  CardResultViewModel.swift
//  GAMSS
//
//  Created by cchanmi on 8/16/26.
//

import Combine
import Foundation

@MainActor
final class CardResultViewModel: ObservableObject {
    enum FoldStage: Equatable {
        case unfolded
        case readyToDiscard

        var next: FoldStage? {
            switch self {
            case .unfolded: .readyToDiscard
            case .readyToDiscard: nil
            }
        }
    }

    @Published private(set) var stage: FoldStage = .unfolded
    @Published private(set) var dragOffset: CGFloat = 0

    static let discardThreshold: CGFloat = 120
    static let dropOffset: CGFloat = 900

    func advanceStage() {
        guard let next = stage.next else { return }
        stage = next
    }

    func updateDrag(translationHeight: CGFloat) {
        dragOffset = max(0, translationHeight)
    }

    func resetDrag() {
        dragOffset = 0
    }

    func drop() {
        dragOffset = Self.dropOffset
    }

    static func shouldDiscard(dragOffset: CGFloat) -> Bool {
        dragOffset > discardThreshold
    }
}
