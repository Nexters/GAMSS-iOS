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
    func test_fetchTokenAmount_withMatchingProductId_returnsTokenAmount() async throws {
        let network = MockNetworkRequesting()
        network.stubbedData = Data("""
        {"success":true,"data":[{"productId":"token_300000","tokenAmount":300000},{"productId":"token_500000","tokenAmount":500000}],"error":null}
        """.utf8)
        let repository = DefaultPurchaseRepository(networkManager: network)

        let tokenAmount = try await repository.fetchTokenAmount(for: "token_500000")

        XCTAssertEqual(tokenAmount, 500_000)
        XCTAssertEqual(network.lastEndpoint?.path, "/api/payments/products")
    }

    func test_fetchTokenAmount_withNoMatchingProductId_returnsNil() async throws {
        let network = MockNetworkRequesting()
        network.stubbedData = Data("""
        {"success":true,"data":[{"productId":"token_300000","tokenAmount":300000}],"error":null}
        """.utf8)
        let repository = DefaultPurchaseRepository(networkManager: network)

        let tokenAmount = try await repository.fetchTokenAmount(for: "token_unknown")

        XCTAssertNil(tokenAmount)
    }

    func test_fetchTokenBalance_returnsBalanceFromStorage() async throws {
        let network = MockNetworkRequesting()
        let userDefaults = UserDefaults(suiteName: #file)!
        userDefaults.removePersistentDomain(forName: #file)
        let storage = PurchasedTokenBalanceStorage(userDefaults: userDefaults)
        storage.addTokens(300_000)
        let repository = DefaultPurchaseRepository(networkManager: network, balanceStorage: storage)

        let balance = try await repository.fetchTokenBalance()

        XCTAssertEqual(balance, PurchasedTokenBalance(balance: 300_000))
    }
}
