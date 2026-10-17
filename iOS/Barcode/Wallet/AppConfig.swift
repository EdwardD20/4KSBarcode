//
//  Barcode/Wallet/AppConfig.swift
//
//  Created by Ed Danley on 4/24/26.
//

import Foundation

enum AppConfig {
    // In a real project, consider sourcing this from build settings or an xcconfig
    static var baseURL: URL {
        // Force-unwrap is safe here because this is a constant you control.
        return URL(string: walletURL)!
    } // static var baseURL
} // enum AppConfig
