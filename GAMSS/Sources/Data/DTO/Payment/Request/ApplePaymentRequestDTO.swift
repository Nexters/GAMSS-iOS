//
//  ApplePaymentRequestDTO.swift
//  GAMSS
//
//  Created by cchanmi on 11/18/26.
//

import Foundation

struct ApplePaymentRequestDTO: Encodable {
    let signedTransaction: String
}
