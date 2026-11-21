//
//  FetchPurchasableProductsUseCase.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

struct FetchPurchasableProductsUseCase {
    private let purchaseRepository: PurchaseRepository

    init(purchaseRepository: PurchaseRepository) {
        self.purchaseRepository = purchaseRepository
    }

    func execute() async throws -> [PurchasableProduct] {
        try await purchaseRepository.fetchProducts()
    }
}
