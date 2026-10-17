//
//  Barcode/Wallet/PassService.swift
//
//  Created by Ed Danley on 4/24/26.
//

import Foundation
import OSLog

// MARK: - Protocol for dependency injection
protocol PassServicing {
    func fetchPass(clientID: String) async throws -> Data
}

final class PassService: PassServicing {
    
    private let logger = Logger(subsystem: passIdentifier, category: "PassService")

    static let shared = PassService()

    private init() { } // init

    /// Fetch a signed pass for a given client identifier
    /// - Parameter clientID: The client identifier to send to the server
    /// - Returns: Raw pass data (e.g., .pkpass)
    func fetchPass(clientID: String) async throws -> Data {
        let builder = APIRequestBuilder(baseURL: AppConfig.baseURL)
        let headers = [
            "Content-Type": "application/json"
        ]
        let body: [String: String] = [
            "clientID": clientID,
            "teamID": teamIdentifier
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body, options: [])

        // clientDisplayStyle: qrcode, or barcode
        var barcodeStyle = "code128"
        if (UserDefaults.standard.string(forKey: "clientDisplayStyle") ?? "barcode" == "qrcode") {
            barcodeStyle = "qrcode"
        }

        let request = builder.makeRequest(
            path: "/sign",
            queryItems: [
                URLQueryItem(name: "pass", value: "4kidssake-pass"),
                URLQueryItem(name: "env", value: "prod"),
                URLQueryItem(name: "barcode", value: barcodeStyle)
            ],
            method: "POST",
            headers: headers,
            body: bodyData,
            timeout: 30
        )

        logger.debug("FINAL URL: \(request.url?.absoluteString ?? "nil")")
        logger.debug("POST /sign clientID=\(clientID, privacy: .private) teamID=\(teamIdentifier, privacy: .private)")

        // Respect cancellation before starting network work
        try Task.checkCancellation()

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            // Respect cancellation after network call
            try Task.checkCancellation()

            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport(URLError(.badServerResponse))
            } // guard

            guard (200...299).contains(http.statusCode) else {
                let bodyString = String(data: data, encoding: .utf8)
                logger.debug("http request: \(request.description)")
                logger.debug("http failure: \(bodyString!)")
                throw APIError.invalidStatus(code: http.statusCode, body: bodyString)
            } // guard (200..299)

            // Optional: Validate MIME type if server returns pkpass
            if let mime = http.value(forHTTPHeaderField: "Content-Type"),
               !mime.contains("application/vnd.apple.pkpass") {
                // Not throwing by default; you can choose to enforce this
                logger.warning("Unexpected MIME type: \(mime)")
            } // if

            return data
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            // Wrap other transport errors as-is; callers can decide how to present
            throw error
        } // do, try/catch
    } // func fetchPass
} // class PassService
