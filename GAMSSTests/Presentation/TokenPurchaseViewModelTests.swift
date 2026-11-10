//
//  TokenPurchaseViewModelTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import XCTest
@testable import GAMSS

private final class MockPurchaseRepository: PurchaseRepository {
    var stubbedProductsResult: Result<[PurchasableProduct], Error> = .success([])
    var stubbedPurchaseResult: Result<PurchaseResult, Error> = .success(.userCancelled)
    var stubbedBalanceResult: Result<PurchasedTokenBalance, Error> = .success(PurchasedTokenBalance(balance: 0))
    private(set) var lastPurchaseProductId: String?

    func fetchProducts() async throws -> [PurchasableProduct] {
        try stubbedProductsResult.get()
    }

    func purchase(productId: String) async throws -> PurchaseResult {
        lastPurchaseProductId = productId
        return try stubbedPurchaseResult.get()
    }

    func fetchTokenBalance() async throws -> PurchasedTokenBalance {
        try stubbedBalanceResult.get()
    }
}

@MainActor
private func makeViewModel(repository: MockPurchaseRepository = MockPurchaseRepository()) -> TokenPurchaseViewModel {
    TokenPurchaseViewModel(
        fetchPurchasableProductsUseCase: FetchPurchasableProductsUseCase(purchaseRepository: repository),
        purchaseTokenUseCase: PurchaseTokenUseCase(purchaseRepository: repository),
        fetchTokenBalanceUseCase: FetchTokenBalanceUseCase(purchaseRepository: repository)
    )
}

@MainActor
final class TokenPurchaseViewModelTests: XCTestCase {
    func test_loadProducts_populatesProductsAndBalance() async {
        let repository = MockPurchaseRepository()
        let products = [PurchasableProduct(id: "token_300000", tokenAmount: 300_000, displayPrice: "₩990")]
        repository.stubbedProductsResult = .success(products)
        repository.stubbedBalanceResult = .success(PurchasedTokenBalance(balance: 200_000))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.loadProducts()

        XCTAssertEqual(viewModel.products, products)
        XCTAssertEqual(viewModel.balance, 200_000)
    }

    func test_purchase_onSuccess_updatesBalanceAndClearsToast() async {
        let repository = MockPurchaseRepository()
        repository.stubbedPurchaseResult = .success(.success(creditedTokens: 300_000, newBalance: 300_000))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.purchase(productId: "token_300000")

        XCTAssertEqual(viewModel.balance, 300_000)
        XCTAssertNil(viewModel.toastMessage)
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertEqual(repository.lastPurchaseProductId, "token_300000")
    }

    func test_purchase_onUserCancelled_showsNoToast() async {
        let repository = MockPurchaseRepository()
        repository.stubbedPurchaseResult = .success(.userCancelled)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.purchase(productId: "token_300000")

        XCTAssertNil(viewModel.toastMessage)
    }

    func test_purchase_onFailed_showsToastWithReason() async {
        let repository = MockPurchaseRepository()
        repository.stubbedPurchaseResult = .success(.failed(reason: "네트워크 오류"))
        let viewModel = makeViewModel(repository: repository)

        await viewModel.purchase(productId: "token_300000")

        XCTAssertEqual(viewModel.toastMessage, "네트워크 오류")
    }

    func test_purchase_onUnverified_showsToast() async {
        let repository = MockPurchaseRepository()
        repository.stubbedPurchaseResult = .success(.unverified)
        let viewModel = makeViewModel(repository: repository)

        await viewModel.purchase(productId: "token_300000")

        XCTAssertNotNil(viewModel.toastMessage)
    }
}
