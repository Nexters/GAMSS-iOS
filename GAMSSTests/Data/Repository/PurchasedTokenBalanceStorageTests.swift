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

    func test_currentBalance_withoutSetBalance_isZero() {
        XCTAssertEqual(storage.currentBalance, 0)
    }

    func test_setBalance_updatesCurrentBalance() {
        storage.setBalance(300_000)

        XCTAssertEqual(storage.currentBalance, 300_000)
    }

    func test_setBalance_calledTwice_overwritesRatherThanAccumulates() {
        storage.setBalance(300_000)
        storage.setBalance(500_000)

        XCTAssertEqual(storage.currentBalance, 500_000)
    }
}
