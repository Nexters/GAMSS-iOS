//
//  PurchaseResult.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

enum PurchaseResult: Equatable {
    case success(creditedTokens: Int, newBalance: Int)
    case pending
    case userCancelled
    case failed(reason: String)
    case unverified
}
