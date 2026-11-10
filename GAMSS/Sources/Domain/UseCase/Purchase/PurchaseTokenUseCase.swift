//
//  PurchaseTokenUseCase.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

struct PurchaseTokenUseCase {
    private let purchaseRepository: PurchaseRepository

    init(purchaseRepository: PurchaseRepository) {
        self.purchaseRepository = purchaseRepository
    }

    func execute(productId: String) async throws -> PurchaseResult {
        try await purchaseRepository.purchase(productId: productId)
    }
}
