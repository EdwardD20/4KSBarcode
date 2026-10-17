//
//  Barcode/Wallet/APIError.swift
//
//  Created by Ed Danley on 4/24/26.
//

import Foundation

public enum APIError: Error, LocalizedError {
    case invalidURL
    case transport(Error)
    case invalidStatus(code: Int, body: String?)
    case decoding(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "APIError: Invalid URL."
        case let .transport(error):
            return "APIError: Transport error - \(error.localizedDescription)"
        case let .invalidStatus(code, body):
            if let body, !body.isEmpty {
                return "APIError: HTTP \(code). Body: \(body)"
            } else {
                return "APIError: HTTP \(code)."
            }
        case let .decoding(error):
            return "APIError: Decoding failed - \(error.localizedDescription)"
        }
    }
}
