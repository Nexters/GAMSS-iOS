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

    var path: String {
        switch self {
        case .fetchProducts:
            return "/api/payments/products"
        case .fetchAccountToken:
            return "/api/payments/account-token"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .fetchProducts, .fetchAccountToken:
            return .get
        }
    }

    var parameters: [RequestParameter] {
        switch self {
        case .fetchProducts, .fetchAccountToken:
            return []
        }
    }

    var header: HTTPHeader { .authorization }
}
