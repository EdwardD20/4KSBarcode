//
//  Barcode/Wallet/APIRequestBuilder.swift
//
//  Created by Ed Danley on 4/24/26.
//

import Foundation

struct APIRequestBuilder {
    let baseURL: URL

    func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil,
        timeout: TimeInterval = 30
    ) -> URLRequest {

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            fatalError("Invalid URL")
        } // guard

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = body

        return request
    } // func makeRequest
} // struct APIRequestBuilder
