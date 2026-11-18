//
//  DefaultPurchaseRepository.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import Foundation
import StoreKit

actor DefaultPurchaseRepository: PurchaseRepository {
    private let networkManager: NetworkRequesting
    private let balanceStorage: PurchasedTokenBalanceStorage
    private var transactionListenerTask: Task<Void, Never>?
    private var unfinishedTransactionsTask: Task<Void, Never>?

    init(networkManager: NetworkRequesting, balanceStorage: PurchasedTokenBalanceStorage = PurchasedTokenBalanceStorage()) {
        self.networkManager = networkManager
        self.balanceStorage = balanceStorage
        self.transactionListenerTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handleUpdatedTransaction(result)
            }
        }
        // 지급 전/후 finish() 호출 전에 종료된 트랜잭션을 다음 실행 시 서버에 재전송한다.
        self.unfinishedTransactionsTask = Task { [weak self] in
            for await result in Transaction.unfinished {
                await self?.handleUpdatedTransaction(result)
            }
        }
    }

    deinit {
        transactionListenerTask?.cancel()
        unfinishedTransactionsTask?.cancel()
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
            return await handleVerifiedPurchase(verificationResult)
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

    private func fetchProductCatalog() async throws -> [PaymentProductResponseDTO] {
        let response = try await networkManager.request(
            PaymentEndpoint.fetchProducts,
            responseType: APIResponse<[PaymentProductResponseDTO]>.self
        )
        return response.data
    }

    private func handleVerifiedPurchase(_ verificationResult: VerificationResult<Transaction>) async -> PurchaseResult {
        switch verificationResult {
        case .unverified:
            return .unverified
        case let .verified(transaction):
            return await credit(verificationResult: verificationResult, transaction: transaction)
        }
    }

    private func handleUpdatedTransaction(_ result: VerificationResult<Transaction>) async {
        guard case .verified = result else { return }
        _ = await handleVerifiedPurchase(result)
    }

    /// 검증(verified) → `/api/payments/apple`로 영수증 검증·지급 → finish() 순서를 지킨다.
    /// finish() 여부는 서버 응답에 따라 갈린다 — 성공, 또는 거래 자체가 무효/취소라고 서버가 확신하는
    /// 경우만 finish()해서 Apple 대기열에서 정리하고, 그 외(인증/권한/상품/서버 오류 등 재시도하면
    /// 나아질 수 있는 실패)는 finish()하지 않아 다음 실행의 `Transaction.unfinished`가 재전송한다.
    private func credit(
        verificationResult: VerificationResult<Transaction>,
        transaction: Transaction
    ) async -> PurchaseResult {
        do {
            let response = try await networkManager.request(
                PaymentEndpoint.verifyPurchase(ApplePaymentRequestDTO(signedTransaction: verificationResult.jwsRepresentation)),
                responseType: APIResponse<ApplePaymentResponseDTO>.self
            )
            balanceStorage.setBalance(response.data.paidBalance)
            await transaction.finish()
            return .success(creditedTokens: response.data.grantedTokens, newBalance: response.data.paidBalance)
        } catch {
            let (result, shouldFinish) = Self.purchaseResult(for: error)
            if shouldFinish {
                await transaction.finish()
            }
            return result
        }
    }

    /// `credit(verificationResult:transaction:)`의 서버 응답 분기를 실제 StoreKit 타입 없이
    /// 유닛테스트할 수 있도록 뽑아낸 순수 함수. `nonisolated`로 actor 격리 없이 호출 가능하다.
    nonisolated static func purchaseResult(for error: Error) -> (result: PurchaseResult, shouldFinish: Bool) {
        guard case let NetworkError.httpError(_, code) = error else {
            return (.failed(reason: "구매 처리 중 오류가 발생했어요. 잠시 후 다시 시도해주세요"), false)
        }

        switch code {
        case "PURCHASE_INVALID":
            return (.failed(reason: "구매할 수 없는 거래예요"), true)
        case "PURCHASE_CANCELLED":
            return (.failed(reason: "취소되었거나 환불된 거래예요"), true)
        default:
            return (.failed(reason: "구매 처리 중 오류가 발생했어요. 잠시 후 다시 시도해주세요"), false)
        }
    }
}
