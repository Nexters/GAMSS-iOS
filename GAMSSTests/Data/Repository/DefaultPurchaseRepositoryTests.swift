//
//  DefaultPurchaseRepositoryTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import XCTest
@testable import GAMSS

private final class MockNetworkRequesting: NetworkRequesting {
    var stubbedData: Data?
    var stubbedError: Error?
    private(set) var lastEndpoint: Endpoint?

    func request<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        isRetryAfterReissue: Bool
    ) async throws -> T {
        lastEndpoint = endpoint
        if let stubbedError { throw stubbedError }
        guard let stubbedData else { fatalError("stubbedData not set") }
        return try JSONDecoder().decode(T.self, from: stubbedData)
    }
}

final class DefaultPurchaseRepositoryTests: XCTestCase {
    func test_fetchTokenBalance_returnsBalanceFromStorage() async throws {
        let network = MockNetworkRequesting()
        let userDefaults = UserDefaults(suiteName: #file)!
        userDefaults.removePersistentDomain(forName: #file)
        let storage = PurchasedTokenBalanceStorage(userDefaults: userDefaults)
        storage.setBalance(300_000)
        let repository = DefaultPurchaseRepository(networkManager: network, balanceStorage: storage)

        let balance = try await repository.fetchTokenBalance()

        XCTAssertEqual(balance, PurchasedTokenBalance(balance: 300_000))
    }

    func test_purchaseResult_forPurchaseInvalid_failsAndFinishes() {
        let error = NetworkError.httpError(statusCode: 400, code: "PURCHASE_INVALID")

        let (result, shouldFinish) = DefaultPurchaseRepository.purchaseResult(for: error)

        XCTAssertTrue(shouldFinish)
        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
    }

    func test_purchaseResult_forPurchaseCancelled_failsAndFinishes() {
        let error = NetworkError.httpError(statusCode: 409, code: "PURCHASE_CANCELLED")

        let (result, shouldFinish) = DefaultPurchaseRepository.purchaseResult(for: error)

        XCTAssertTrue(shouldFinish)
        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
    }

    func test_purchaseResult_forProductUnavailable_failsWithoutFinishing() {
        let error = NetworkError.httpError(statusCode: 409, code: "PAYMENT_PRODUCT_UNAVAILABLE")

        let (result, shouldFinish) = DefaultPurchaseRepository.purchaseResult(for: error)

        XCTAssertFalse(shouldFinish)
        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
    }

    func test_purchaseResult_forStoreUnavailable_failsWithoutFinishing() {
        let error = NetworkError.httpError(statusCode: 503, code: "PAYMENT_STORE_UNAVAILABLE")

        let (result, shouldFinish) = DefaultPurchaseRepository.purchaseResult(for: error)

        XCTAssertFalse(shouldFinish)
        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
    }

    func test_purchaseResult_forNonHTTPError_failsWithoutFinishing() {
        let error = NetworkError.decodingError

        let (result, shouldFinish) = DefaultPurchaseRepository.purchaseResult(for: error)

        XCTAssertFalse(shouldFinish)
        guard case .failed = result else { return XCTFail("expected .failed, got \(result)") }
    }
}
