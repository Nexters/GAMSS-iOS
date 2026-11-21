//
//  NetworkError.swift
//  GAMSS
//
//  Created by 이건준 on 7/19/26.
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, code: String?)
    case decodingError
    case expiredToken
    case noConnection
}
