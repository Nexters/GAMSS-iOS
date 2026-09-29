//
//  CardDetailViewModelTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/17/26.
//

import XCTest
@testable import GAMSS

private final class MockCardRepository: CardRepository {
    var stubbedGetCardResult: Result<Card, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var receivedGetCardId: Int?

    func createCard(conversationId: Int, emotion: EmotionCharacter?, summary: String) async throws -> Card {
        fatalError("사용 안 함")
    }

    func getCard(cardId: Int) async throws -> Card {
        receivedGetCardId = cardId
        return try stubbedGetCardResult.get()
    }

    func deleteCard(cardId: Int) async throws {
        fatalError("사용 안 함")
    }

    func fetchCardsByDate(yearMonth: Date, emotion: Emotion) async throws -> [DailyEmotion] {
        fatalError("사용 안 함")
    }

    func deleteAllCard() async throws {
        fatalError("사용 안 함")
    }
}

@MainActor
final class CardDetailViewModelTests: XCTestCase {
    private func makeViewModel(cardId: Int = 1, repository: MockCardRepository) -> CardDetailViewModel {
        CardDetailViewModel(
            cardId: cardId,
            getCardUseCase: GetCardUseCase(cardRepository: repository)
        )
    }

    func test_loadCard_onSuccess_setsCardAndClearsLoading() async {
        let repository = MockCardRepository()
        let card = Card(id: 1, conversationId: 10, emotion: .anger, summary: "요약", message: "메시지", date: Date(timeIntervalSince1970: 0))
        repository.stubbedGetCardResult = .success(card)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadCard()

        XCTAssertEqual(viewModel.card, card)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(repository.receivedGetCardId, 1)
    }

    func test_loadCard_onFailure_setsAlertMessageAndClearsLoading() async {
        let repository = MockCardRepository()
        repository.stubbedGetCardResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadCard()

        XCTAssertEqual(viewModel.alertMessage, "카드를 불러오지 못했어요")
        XCTAssertNil(viewModel.card)
        XCTAssertFalse(viewModel.isLoading)
    }

    func test_isLoadFailureAlert_whenCardIsNilAndAlertMessageSet_isTrue() async {
        let repository = MockCardRepository()
        repository.stubbedGetCardResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadCard()

        XCTAssertTrue(viewModel.isLoadFailureAlert)
    }

    func test_showNetworkUnreachableToast_setsToastMessage() {
        let repository = MockCardRepository()
        let viewModel = makeViewModel(repository: repository)

        viewModel.showNetworkUnreachableToast()

        XCTAssertEqual(viewModel.toastMessage, "네트워크 연결을 확인해주세요.")
    }
}
