//
//  CardShredViewModelTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import Foundation
import XCTest
@testable import GAMSS

private final class MockCardRepository: CardRepository {
    var deleteCardError: Error?
    var deleteAllCardError: Error?

    func createCard(conversationId: Int, emotion: EmotionCharacter?, summary: String) async throws -> Card {
        fatalError("not used in this test")
    }
    func getCard(cardId: Int) async throws -> Card { fatalError("not used in this test") }
    func deleteCard(cardId: Int) async throws {
        if let deleteCardError { throw deleteCardError }
    }
    func fetchCardsByDate(yearMonth: Date, emotion: Emotion) async throws -> [DailyEmotion] { fatalError("not used in this test") }
    func deleteAllCard() async throws {
        if let deleteAllCardError { throw deleteAllCardError }
    }
}

private final class MockDeleteAllCardUseCase: DeleteAllCardUseCase {
    var error: Error?

    func execute() async throws {
        if let error { throw error }
    }
}

private final class MockAnalyticsTracking: AnalyticsTracking {
    private(set) var trackedEvents: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        trackedEvents.append(event)
    }

    func trackScreen(_ screen: AnalyticsScreen) {}
}

@MainActor
final class CardShredViewModelTests: XCTestCase {
    func test_advance_tracksCardShredTapWithIncrementedCount() {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = CardShredViewModel(
            emotion: .angry,
            cardId: 1,
            deleteCardUseCase: DeleteCardUseCase(cardRepository: MockCardRepository()),
            analyticsTracker: analyticsTracker
        )

        for _ in 0..<4 { viewModel.advance() }

        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), Array(repeating: "card_shred_tap", count: 4))
        XCTAssertEqual(analyticsTracker.trackedEvents.map { $0.properties["tap_count"] as? Int }, [1, 2, 3, 4])
        XCTAssertEqual(analyticsTracker.trackedEvents.first?.properties["emotion"] as? String, "anger")
        XCTAssertEqual(analyticsTracker.trackedEvents.first?.properties["scope"] as? String, "single")
    }

    func test_shred_onSuccess_tracksFinalTapAndSuccess() async {
        let analyticsTracker = MockAnalyticsTracking()
        let viewModel = CardShredViewModel(
            emotion: .sad,
            deleteAllCardUseCase: MockDeleteAllCardUseCase(),
            analyticsTracker: analyticsTracker
        )
        for _ in 0..<4 { viewModel.advance() }

        let succeeded = await viewModel.shred()

        XCTAssertTrue(succeeded)
        XCTAssertEqual(analyticsTracker.trackedEvents.map(\.name), ["card_shred_tap", "card_shred_tap", "card_shred_tap", "card_shred_tap", "card_shred_tap", "card_shred_success"])
        let tapCounts = analyticsTracker.trackedEvents.prefix(5).map { $0.properties["tap_count"] as? Int }
        XCTAssertEqual(tapCounts, [1, 2, 3, 4, 5])
        XCTAssertEqual(analyticsTracker.trackedEvents.last?.properties["scope"] as? String, "emotion_all")
    }

    func test_shred_onFailure_tracksFail() async {
        let analyticsTracker = MockAnalyticsTracking()
        let useCase = MockDeleteAllCardUseCase()
        useCase.error = NetworkError.noConnection
        let viewModel = CardShredViewModel(
            emotion: .happy,
            deleteAllCardUseCase: useCase,
            analyticsTracker: analyticsTracker
        )
        for _ in 0..<4 { viewModel.advance() }

        let succeeded = await viewModel.shred()

        XCTAssertFalse(succeeded)
        XCTAssertEqual(analyticsTracker.trackedEvents.last?.name, "card_shred_fail")
    }
}
