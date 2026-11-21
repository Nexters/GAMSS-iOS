//
//  TokenPurchaseViewModel.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import Combine
import Foundation

@MainActor
final class TokenPurchaseViewModel: ObservableObject {
    @Published private(set) var products: [PurchasableProduct] = []
    @Published private(set) var balance = 0
    @Published private(set) var isSubmitting = false
    @Published private(set) var toastMessage: String?

    private let fetchPurchasableProductsUseCase: FetchPurchasableProductsUseCase
    private let purchaseTokenUseCase: PurchaseTokenUseCase
    private let fetchTokenBalanceUseCase: FetchTokenBalanceUseCase
    private var toastDismissTask: Task<Void, Never>?

    init(
        fetchPurchasableProductsUseCase: FetchPurchasableProductsUseCase,
        purchaseTokenUseCase: PurchaseTokenUseCase,
        fetchTokenBalanceUseCase: FetchTokenBalanceUseCase
    ) {
        self.fetchPurchasableProductsUseCase = fetchPurchasableProductsUseCase
        self.purchaseTokenUseCase = purchaseTokenUseCase
        self.fetchTokenBalanceUseCase = fetchTokenBalanceUseCase
    }

    func loadProducts() async {
        do {
            products = try await fetchPurchasableProductsUseCase.execute()
            balance = try await fetchTokenBalanceUseCase.execute().balance
        } catch {
            showToast("상품 목록을 불러오지 못했어요")
        }
    }

    func purchase(productId: String) async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let result = try await purchaseTokenUseCase.execute(productId: productId)
            switch result {
            case let .success(_, newBalance):
                balance = newBalance
            case .userCancelled:
                break
            case .pending:
                showToast("결제 승인 대기 중이에요")
            case let .failed(reason):
                showToast(reason)
            case .unverified:
                showToast("결제 검증에 실패했어요")
            }
        } catch {
            showToast("구매 중 오류가 발생했어요")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
