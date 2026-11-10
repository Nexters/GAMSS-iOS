//
//  PurchasedTokenBalanceStorageTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import XCTest
@testable import GAMSS

final class PurchasedTokenBalanceStorageTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var storage: PurchasedTokenBalanceStorage!

    override func setUp() {
        super.setUp()
        userDefaults = UserDefaults(suiteName: #file)
        userDefaults.removePersistentDomain(forName: #file)
        storage = PurchasedTokenBalanceStorage(userDefaults: userDefaults)
    }

    func test_currentBalance_withNoAdds_isZero() {
        XCTAssertEqual(storage.currentBalance, 0)
    }

    func test_addTokens_increasesCurrentBalance() {
        let newBalance = storage.addTokens(300_000)

        XCTAssertEqual(newBalance, 300_000)
        XCTAssertEqual(storage.currentBalance, 300_000)
    }

    func test_addTokens_calledTwice_accumulates() {
        storage.addTokens(300_000)
        let newBalance = storage.addTokens(500_000)

        XCTAssertEqual(newBalance, 800_000)
        XCTAssertEqual(storage.currentBalance, 800_000)
    }

    func test_addTokensIfNotProcessed_firstCall_creditsAndReturnsTrue() {
        let result = storage.addTokensIfNotProcessed(transactionID: 12345, tokenAmount: 300_000)

        XCTAssertTrue(result.credited)
        XCTAssertEqual(result.balance, 300_000)
        XCTAssertEqual(storage.currentBalance, 300_000)
    }

    func test_addTokensIfNotProcessed_sameTransactionIDTwice_creditsOnlyOnce() {
        storage.addTokensIfNotProcessed(transactionID: 12345, tokenAmount: 300_000)
        let secondResult = storage.addTokensIfNotProcessed(transactionID: 12345, tokenAmount: 300_000)

        XCTAssertFalse(secondResult.credited)
        XCTAssertEqual(secondResult.balance, 300_000)
        XCTAssertEqual(storage.currentBalance, 300_000)
    }

    func test_addTokensIfNotProcessed_differentTransactionIDs_creditsBoth() {
        storage.addTokensIfNotProcessed(transactionID: 1, tokenAmount: 300_000)
        let result = storage.addTokensIfNotProcessed(transactionID: 2, tokenAmount: 500_000)

        XCTAssertTrue(result.credited)
        XCTAssertEqual(result.balance, 800_000)
    }
}
