//
//  PurchasedTokenBalanceStorage.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import Foundation

/// 구매 잔액을 임시로 로컬에 캐시한다. `/api/payments/apple` 응답의 `paidBalance`(서버가 집계한
/// 권위 있는 잔액)로 매번 덮어쓰는 캐시일 뿐, 기기에서 직접 가산하지 않는다 — 지급 중복 방지는
/// 서버가 transaction.id 기준으로 처리하므로 클라이언트에서 별도로 추적하지 않는다.
/// 잔액 단독 조회 서버 API가 확인되면 이 타입은 제거하고 서버 조회로 교체한다.
struct PurchasedTokenBalanceStorage {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var currentBalance: Int {
        userDefaults.integer(forKey: Keys.balance)
    }

    func setBalance(_ balance: Int) {
        userDefaults.set(balance, forKey: Keys.balance)
    }

    private enum Keys {
        static let balance = "purchased_token_balance"
    }
}
