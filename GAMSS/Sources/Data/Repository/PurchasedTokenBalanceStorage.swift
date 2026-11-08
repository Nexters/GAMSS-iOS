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

    /// 같은 StoreKit 트랜잭션이 두 번 지급 처리되는 것(예: 포그라운드 purchase()와
    /// Transaction.updates 리스너가 동시에 같은 트랜잭션을 처리하거나, 지급 후 finish() 호출
    /// 전에 프로세스가 죽어 다음 실행에서 같은 트랜잭션이 다시 전달되는 경우)을 막기 위해,
    /// 이미 처리한 transaction.id 목록을 함께 저장해 중복 지급을 거른다.
    /// 반환값의 credited가 false면 이미 처리된 트랜잭션이라 잔액은 바뀌지 않았다는 뜻이다.
    @discardableResult
    func addTokensIfNotProcessed(transactionID: UInt64, tokenAmount: Int) -> (credited: Bool, balance: Int) {
        var processedIDs = Set((userDefaults.array(forKey: Keys.processedTransactionIDs) as? [String]) ?? [])
        let id = String(transactionID)

        guard !processedIDs.contains(id) else {
            return (false, currentBalance)
        }

        processedIDs.insert(id)
        userDefaults.set(Array(processedIDs), forKey: Keys.processedTransactionIDs)

        let newBalance = addTokens(tokenAmount)
        return (true, newBalance)
    }

    private enum Keys {
        static let balance = "purchased_token_balance"
        static let processedTransactionIDs = "purchased_token_processed_transaction_ids"
    }
}
