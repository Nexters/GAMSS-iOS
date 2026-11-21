//
//  PurchaseRepository.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

protocol PurchaseRepository {
    func fetchProducts() async throws -> [PurchasableProduct]
    func purchase(productId: String) async throws -> PurchaseResult
    func fetchTokenBalance() async throws -> PurchasedTokenBalance
}
