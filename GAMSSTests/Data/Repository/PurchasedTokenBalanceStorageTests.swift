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
}
