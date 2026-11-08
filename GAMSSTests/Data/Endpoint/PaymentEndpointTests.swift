//
//  PaymentEndpointTests.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import XCTest
@testable import GAMSS

final class PaymentEndpointTests: XCTestCase {
    func test_fetchProducts_hasCorrectPathAndMethod() {
        let endpoint = PaymentEndpoint.fetchProducts

        XCTAssertEqual(endpoint.path, "/api/payments/products")
        XCTAssertEqual(endpoint.method, .get)
    }

    func test_fetchAccountToken_hasCorrectPathAndMethod() {
        let endpoint = PaymentEndpoint.fetchAccountToken

        XCTAssertEqual(endpoint.path, "/api/payments/account-token")
        XCTAssertEqual(endpoint.method, .get)
    }

    func test_paymentProductResponseDTO_decodesFromServerJSON() throws {
        let json = Data("""
        {"success":true,"data":[{"productId":"token_300000","tokenAmount":300000}],"error":null}
        """.utf8)

        let response = try JSONDecoder().decode(APIResponse<[PaymentProductResponseDTO]>.self, from: json)

        XCTAssertEqual(response.data.first?.productId, "token_300000")
        XCTAssertEqual(response.data.first?.tokenAmount, 300_000)
    }

    func test_accountTokenResponseDTO_decodesFromServerJSON() throws {
        let json = Data("""
        {"success":true,"data":{"accountToken":"3f2b8c1e-7a4d-4e6b-9c0a-1d2e3f4a5b6c"},"error":null}
        """.utf8)

        let response = try JSONDecoder().decode(APIResponse<AccountTokenResponseDTO>.self, from: json)

        XCTAssertEqual(response.data.accountToken, "3f2b8c1e-7a4d-4e6b-9c0a-1d2e3f4a5b6c")
    }
}
