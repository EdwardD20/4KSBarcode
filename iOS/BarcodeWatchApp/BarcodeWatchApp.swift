//
//  BarcodeWatchApp/BarcodeWatchApp.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI

@main
struct BarcodeWatchApp: App {
    @StateObject private var receiver = WatchSessionReceiver.shared

    var body: some Scene {
        WindowGroup {
            WatchBarcodeView()
                .environmentObject(receiver)   // <-- required
        } // WindowGroup
    } // body
} // BarcodeWatchApp
