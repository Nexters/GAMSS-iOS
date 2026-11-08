//
//  PurchasedTokenBalanceStorage.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import Foundation

/// 구매 잔액을 임시로 로컬에 저장한다. 서버 집계가 아니며, 재설치 시 초기화되고 기기 간 동기화되지 않는다.
/// 잔액 조회 서버 API가 확인되면 이 타입은 제거하고 서버 조회로 교체한다.
struct PurchasedTokenBalanceStorage {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currentBalance: Int {
        userDefaults.integer(forKey: Keys.balance)
    }

    @discardableResult
    func addTokens(_ amount: Int) -> Int {
        let newBalance = currentBalance + amount
        userDefaults.set(newBalance, forKey: Keys.balance)
        return newBalance
    }

    private enum Keys {
        static let balance = "purchased_token_balance"
    }
}
