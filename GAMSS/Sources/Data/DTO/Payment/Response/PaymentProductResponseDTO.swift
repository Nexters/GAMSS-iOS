//
//  PaymentProductResponseDTO.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import Foundation

struct PaymentProductResponseDTO: Decodable {
    let productId: String
    let tokenAmount: Int
}
