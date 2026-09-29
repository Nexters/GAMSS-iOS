//
//  NetworkManager.swift
//  GAMSS
//
//  Created by 이건준 on 7/19/26.
//

import Foundation

protocol NetworkRequesting {
    func request<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        isRetryAfterReissue: Bool
    ) async throws -> T
}

extension NetworkRequesting {
    func request<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        try await request(endpoint, responseType: responseType, isRetryAfterReissue: false)
    }
}

final class NetworkManager: NetworkRequesting {
    static let shared = NetworkManager()

    private static let connectivityErrorCodes: Set<URLError.Code> = [
        .notConnectedToInternet,
        .networkConnectionLost,
        .timedOut,
        .cannotConnectToHost,
        .cannotFindHost,
        .dataNotAllowed
    ]

    private let session: URLSession
    private let decoder: JSONDecoder
    
    private init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.decoder = decoder
    }
    
    func request<T: Decodable & Sendable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        isRetryAfterReissue: Bool
    ) async throws -> T {

        let urlRequest = try endpoint.asURLRequest()

        let bodyString = urlRequest.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "-"
        Log.debug("📤 \(endpoint.method.rawValue) \(endpoint.path) body: \(bodyString)")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError where Self.connectivityErrorCodes.contains(urlError.code) {
            throw NetworkError.noConnection
        }

        if let jsonString = String(data: data, encoding: .utf8) {
            Log.debug("📦 \(endpoint.path) response: \(jsonString)")
        }

        guard let response = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard 200..<300 ~= response.statusCode else {
            let apiError = try? decoder.decode(
                APIResponse<EmptyResponseDTO>.self,
                from: data
            ).error

            if response.statusCode == 401, !isRetryAfterReissue {
                do {
                    try await TokenStorage.shared.restoreSession()
                } catch {
                    Log.error("Session restore failed: \(error)")
                    TokenStorage.shared.clearSession()
                    await MainActor.run {
                        LoginSession.shared.updateFromStorage()
                    }
                    throw NetworkError.expiredToken
                }

                return try await request(endpoint, responseType: responseType, isRetryAfterReissue: true)
            }

            Log.error("""
                    ❌ API Error
                    StatusCode: \(response.statusCode)
                    Code: \(apiError?.code ?? "UNKNOWN")
                    Message: \(apiError?.message ?? "No error message")
                    """)

            throw NetworkError.httpError(statusCode: response.statusCode)
        }

        do {
            return try decoder.decode(
                T.self,
                from: data
            )
        } catch {
            throw NetworkError.decodingError
        }
    }
}
