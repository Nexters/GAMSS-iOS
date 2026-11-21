//
//  FetchTokenBalanceUseCaseTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import XCTest
@testable import GAMSS

private final class MockPurchaseRepository: PurchaseRepository {
    var stubbedBalanceResult: Result<PurchasedTokenBalance, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var fetchTokenBalanceCallCount = 0

    func fetchProducts() async throws -> [PurchasableProduct] { fatalError("not used in this test") }
    func purchase(productId: String) async throws -> PurchaseResult { fatalError("not used in this test") }

    func fetchTokenBalance() async throws -> PurchasedTokenBalance {
        fetchTokenBalanceCallCount += 1
        return try stubbedBalanceResult.get()
    }
}

final class FetchTokenBalanceUseCaseTests: XCTestCase {
    func test_execute_returnsBalanceFromRepository() async throws {
        let repository = MockPurchaseRepository()
        repository.stubbedBalanceResult = .success(PurchasedTokenBalance(balance: 500_000))
        let useCase = FetchTokenBalanceUseCase(purchaseRepository: repository)

        let result = try await useCase.execute()

        XCTAssertEqual(result, PurchasedTokenBalance(balance: 500_000))
        XCTAssertEqual(repository.fetchTokenBalanceCallCount, 1)
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockPurchaseRepository()
        repository.stubbedBalanceResult = .failure(SummaryError.inferenceFailed())
        let useCase = FetchTokenBalanceUseCase(purchaseRepository: repository)

        do {
            _ = try await useCase.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SummaryError, .inferenceFailed())
        }
    }
}
