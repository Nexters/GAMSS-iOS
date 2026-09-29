//
//  CardResultViewModelTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/16/26.
//

import XCTest
@testable import GAMSS

@MainActor
final class CardResultViewModelTests: XCTestCase {
    func test_foldStage_next_advancesThroughEachStageInOrder() {
        XCTAssertEqual(CardResultViewModel.FoldStage.unfolded.next, .foldedOnce)
        XCTAssertEqual(CardResultViewModel.FoldStage.foldedOnce.next, .readyToDiscard)
    }

    func test_foldStage_next_readyToDiscard_returnsNil() {
        XCTAssertNil(CardResultViewModel.FoldStage.readyToDiscard.next)
    }

    func test_advanceStage_movesThroughEachStageInOrder() {
        let viewModel = CardResultViewModel()

        XCTAssertEqual(viewModel.stage, .unfolded)
        viewModel.advanceStage()
        XCTAssertEqual(viewModel.stage, .foldedOnce)
        viewModel.advanceStage()
        XCTAssertEqual(viewModel.stage, .readyToDiscard)
    }

    func test_advanceStage_atReadyToDiscard_staysPut() {
        let viewModel = CardResultViewModel()
        viewModel.advanceStage()
        viewModel.advanceStage()

        viewModel.advanceStage()

        XCTAssertEqual(viewModel.stage, .readyToDiscard)
    }

    func test_updateDrag_negativeTranslation_clampsToZero() {
        let viewModel = CardResultViewModel()

        viewModel.updateDrag(translationHeight: -50)

        XCTAssertEqual(viewModel.dragOffset, 0)
    }

    func test_updateDrag_positiveTranslation_setsDragOffset() {
        let viewModel = CardResultViewModel()

        viewModel.updateDrag(translationHeight: 80)

        XCTAssertEqual(viewModel.dragOffset, 80)
    }

    func test_resetDrag_clearsDragOffset() {
        let viewModel = CardResultViewModel()
        viewModel.updateDrag(translationHeight: 80)

        viewModel.resetDrag()

        XCTAssertEqual(viewModel.dragOffset, 0)
    }

    func test_drop_setsDragOffsetToDropOffset() {
        let viewModel = CardResultViewModel()
        viewModel.updateDrag(translationHeight: 130)

        viewModel.drop()

        XCTAssertEqual(viewModel.dragOffset, CardResultViewModel.dropOffset)
    }

    func test_shouldDiscard_belowThreshold_returnsFalse() {
        XCTAssertFalse(CardResultViewModel.shouldDiscard(dragOffset: 0))
        XCTAssertFalse(CardResultViewModel.shouldDiscard(dragOffset: 119))
    }

    func test_shouldDiscard_aboveThreshold_returnsTrue() {
        XCTAssertTrue(CardResultViewModel.shouldDiscard(dragOffset: 121))
    }
}
