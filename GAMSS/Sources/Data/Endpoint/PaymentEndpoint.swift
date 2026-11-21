//
//  PaymentEndpoint.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import Foundation

enum PaymentEndpoint: Endpoint {
    case fetchProducts
    case fetchAccountToken
    case verifyPurchase(ApplePaymentRequestDTO)

    var path: String {
        switch self {
        case .fetchProducts:
            return "/api/payments/products"
        case .fetchAccountToken:
            return "/api/payments/account-token"
        case .verifyPurchase:
            return "/api/payments/apple"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetchProducts, .fetchAccountToken:
            return .get
        case .verifyPurchase:
            return .post
        }
    }

    var parameters: [RequestParameter] {
        switch self {
        case .fetchProducts, .fetchAccountToken:
            return []
        case let .verifyPurchase(request):
            return [.body(request)]
        }
    }

    var header: HTTPHeader { .authorization }
}
