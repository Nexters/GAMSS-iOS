//
//  ApplePaymentResponseDTO.swift
//  GAMSS
//
//  Created by cchanmi on 11/18/26.
//

import Foundation

struct ApplePaymentResponseDTO: Decodable {
    let productId: String
    let grantedTokens: Int
    let paidBalance: Int
}
