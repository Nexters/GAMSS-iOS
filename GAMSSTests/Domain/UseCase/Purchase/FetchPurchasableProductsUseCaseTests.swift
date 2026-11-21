//
//  FetchPurchasableProductsUseCaseTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import XCTest
@testable import GAMSS

private final class MockPurchaseRepository: PurchaseRepository {
    var stubbedProductsResult: Result<[PurchasableProduct], Error> = .failure(SummaryError.inferenceFailed())
    var stubbedPurchaseResult: Result<PurchaseResult, Error> = .failure(SummaryError.inferenceFailed())
    var stubbedBalanceResult: Result<PurchasedTokenBalance, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var fetchProductsCallCount = 0
    private(set) var lastPurchaseProductId: String?
    private(set) var fetchTokenBalanceCallCount = 0

    func fetchProducts() async throws -> [PurchasableProduct] {
        fetchProductsCallCount += 1
        return try stubbedProductsResult.get()
    }

    func purchase(productId: String) async throws -> PurchaseResult {
        lastPurchaseProductId = productId
        return try stubbedPurchaseResult.get()
    }

    func fetchTokenBalance() async throws -> PurchasedTokenBalance {
        fetchTokenBalanceCallCount += 1
        return try stubbedBalanceResult.get()
    }
}

final class FetchPurchasableProductsUseCaseTests: XCTestCase {
    func test_execute_returnsProductsFromRepository() async throws {
        let repository = MockPurchaseRepository()
        let products = [PurchasableProduct(id: "token_300000", tokenAmount: 300_000, displayPrice: "₩990")]
        repository.stubbedProductsResult = .success(products)
        let useCase = FetchPurchasableProductsUseCase(purchaseRepository: repository)

        let result = try await useCase.execute()

        XCTAssertEqual(result, products)
        XCTAssertEqual(repository.fetchProductsCallCount, 1)
    }

    func test_execute_propagatesRepositoryError() async {
        let repository = MockPurchaseRepository()
        repository.stubbedProductsResult = .failure(SummaryError.inferenceFailed())
        let useCase = FetchPurchasableProductsUseCase(purchaseRepository: repository)

        do {
            _ = try await useCase.execute()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? SummaryError, .inferenceFailed())
        }
    }
}
