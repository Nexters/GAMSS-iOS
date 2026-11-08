//
//  DefaultPurchaseRepository.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import Foundation
import StoreKit

final class DefaultPurchaseRepository: PurchaseRepository {
    private let networkManager: NetworkRequesting
    private let balanceStorage: PurchasedTokenBalanceStorage
    private var transactionListenerTask: Task<Void, Never>?

    init(networkManager: NetworkRequesting, balanceStorage: PurchasedTokenBalanceStorage = PurchasedTokenBalanceStorage()) {
        self.networkManager = networkManager
        self.balanceStorage = balanceStorage
        self.transactionListenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handleUpdatedTransaction(result)
            }
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func fetchProducts() async throws -> [PurchasableProduct] {
        let catalog = try await fetchProductCatalog()
        let tokenAmountById = Dictionary(uniqueKeysWithValues: catalog.map { ($0.productId, $0.tokenAmount) })
        let storeProducts = try await Product.products(for: catalog.map(\.productId))

        return storeProducts.compactMap { storeProduct in
            guard let tokenAmount = tokenAmountById[storeProduct.id] else { return nil }
            return PurchasableProduct(id: storeProduct.id, tokenAmount: tokenAmount, displayPrice: storeProduct.displayPrice)
        }
    }

    func purchase(productId: String) async throws -> PurchaseResult {
        let accountTokenResponse = try await networkManager.request(
            PaymentEndpoint.fetchAccountToken,
            responseType: APIResponse<AccountTokenResponseDTO>.self
        )
        guard let appAccountToken = UUID(uuidString: accountTokenResponse.data.accountToken) else {
            return .failed(reason: "계정 토큰 형식이 올바르지 않습니다")
        }

        let storeProducts = try await Product.products(for: [productId])
        guard let storeProduct = storeProducts.first else {
            return .failed(reason: "상품을 찾을 수 없습니다")
        }

        let purchaseResult = try await storeProduct.purchase(options: [.appAccountToken(appAccountToken)])

        switch purchaseResult {
        case let .success(verificationResult):
            return try await handleVerifiedPurchase(verificationResult, productId: productId)
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed(reason: "알 수 없는 결제 상태입니다")
        }
    }

    func fetchTokenBalance() async throws -> PurchasedTokenBalance {
        PurchasedTokenBalance(balance: balanceStorage.currentBalance)
    }

    /// `/api/payments/products`에서 상품ID별 지급량을 조회한다. `fetchProducts()`(StoreKit 가격 머지)와
    /// `purchase(productId:)`(지급량 확인) 양쪽에서 쓰는 네트워크 전용 보조 로직이라 분리했다.
    /// internal로 열어 유닛테스트에서 StoreKit 없이 검증한다.
    func fetchTokenAmount(for productId: String) async throws -> Int? {
        let catalog = try await fetchProductCatalog()
        return catalog.first { $0.productId == productId }?.tokenAmount
    }

    private func fetchProductCatalog() async throws -> [PaymentProductResponseDTO] {
        let response = try await networkManager.request(
            PaymentEndpoint.fetchProducts,
            responseType: APIResponse<[PaymentProductResponseDTO]>.self
        )
        return response.data
    }

    private func handleVerifiedPurchase(
        _ verificationResult: VerificationResult<Transaction>,
        productId: String
    ) async throws -> PurchaseResult {
        switch verificationResult {
        case .unverified:
            return .unverified
        case let .verified(transaction):
            guard let tokenAmount = try await fetchTokenAmount(for: productId) else {
                return .failed(reason: "등록되지 않은 상품입니다")
            }
            return await credit(transaction: transaction, tokenAmount: tokenAmount)
        }
    }

    private func handleUpdatedTransaction(_ result: VerificationResult<Transaction>) async {
        guard case let .verified(transaction) = result else { return }
        guard let tokenAmount = try? await fetchTokenAmount(for: transaction.productID) else { return }
        _ = await credit(transaction: transaction, tokenAmount: tokenAmount)
    }

    /// 검증(verified) → 지급 → finish() 순서를 지킨다. 지급 단계는 현재 Mock이며,
    /// 이 위치가 나중에 POST /api/payments/apple 실제 호출로 교체될 유일한 지점이다.
    private func credit(transaction: Transaction, tokenAmount: Int) async -> PurchaseResult {
        // TODO: 백엔드 Apple 결제 검증 API(POST /api/payments/apple 등) 연동 — 현재는 Mock으로 지급 처리
        let newBalance = balanceStorage.addTokens(tokenAmount)
        await transaction.finish()
        return .success(creditedTokens: tokenAmount, newBalance: newBalance)
    }
}
