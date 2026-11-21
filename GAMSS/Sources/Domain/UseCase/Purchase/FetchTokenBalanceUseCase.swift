//
//  FetchTokenBalanceUseCase.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

struct FetchTokenBalanceUseCase {
    private let purchaseRepository: PurchaseRepository

    init(purchaseRepository: PurchaseRepository) {
        self.purchaseRepository = purchaseRepository
    }

    func execute() async throws -> PurchasedTokenBalance {
        try await purchaseRepository.fetchTokenBalance()
    }
}
