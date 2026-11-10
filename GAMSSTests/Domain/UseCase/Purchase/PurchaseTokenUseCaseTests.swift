//
//  PurchaseTokenUseCaseTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import XCTest
@testable import GAMSS

private final class MockPurchaseRepository: PurchaseRepository {
    var stubbedPurchaseResult: Result<PurchaseResult, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var lastPurchaseProductId: String?

    func fetchProducts() async throws -> [PurchasableProduct] { fatalError("not used in this test") }
    func fetchTokenBalance() async throws -> PurchasedTokenBalance { fatalError("not used in this test") }

    func purchase(productId: String) async throws -> PurchaseResult {
        lastPurchaseProductId = productId
        return try stubbedPurchaseResult.get()
    }
}

final class PurchaseTokenUseCaseTests: XCTestCase {
    func test_execute_passesProductIdAndReturnsResult() async throws {
        let repository = MockPurchaseRepository()
        repository.stubbedPurchaseResult = .success(.success(creditedTokens: 300_000, newBalance: 300_000))
        let useCase = PurchaseTokenUseCase(purchaseRepository: repository)

        let result = try await useCase.execute(productId: "token_300000")

        XCTAssertEqual(result, .success(creditedTokens: 300_000, newBalance: 300_000))
        XCTAssertEqual(repository.lastPurchaseProductId, "token_300000")
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockPurchaseRepository()
        repository.stubbedPurchaseResult = .failure(SummaryError.inferenceFailed())
        let useCase = PurchaseTokenUseCase(purchaseRepository: repository)

        do {
            _ = try await useCase.execute(productId: "token_300000")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SummaryError, .inferenceFailed())
        }
    }
}
