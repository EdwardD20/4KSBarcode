//
//  Barcode/PhoneWatchSessionReceiver.swift
//
//  Created by Ed Danley on 4/24/26.
//


import Foundation
import WatchConnectivity
import SwiftUI
import Combine
import UIKit

/// Receives barcode image + clientId from the watch (or sends/receives in future).
/// Attach this to your iOS App struct as a @StateObject and inject via .environmentObject(...)
final class PhoneWatchSessionReceiver: NSObject, WCSessionDelegate, ObservableObject {
    @Published var latestBarcodeImage: UIImage?
    @Published var clientId: String = ""

    private let session = WCSession.isSupported() ? WCSession.default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    // MARK: - File transfer: barcode PNG arrives here
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("Watch: didReceive file with metadata = \(file.metadata ?? [:])")
        // Optional: filter by metadata
        if let t = file.metadata?["type"] as? String, t != "barcode" { return }

        do {
            let data = try Data(contentsOf: file.fileURL)
            print("Watch: file size = \(data.count) bytes")
            if let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.latestBarcodeImage = image
                    print("Watch: latestBarcodeImage set")
                } // DispatchQueue.main.async
            } else {
                print("Watch: Could not make UIImage from data")
            } // if
        } catch {
            print("Failed to read incoming barcode file (iOS): \(error)")
        } // do/catch

        if let cid = file.metadata?["clientId"] as? String {
            DispatchQueue.main.async {
                self.clientId = cid
            } // DispatchQueue.main.async
        } // if
    } // session didReceive file

    // MARK: - Optional immediate key/value messages
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let cid = message["clientId"] as? String {
            DispatchQueue.main.async {
                self.clientId = cid
            } // DispatchQueue.main.async
        } // if
    } // session didReceiveMessage

    // MARK: - WCSessionDelegate lifecycle (iOS)
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("WCSession activation error (iOS): \(error)")
        } else {
            print("WCSession activated (iOS) with state: \(activationState.rawValue)")
        } // if
    } // session activationDidCompleteWith

    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS only – usually when switching watches
        print("WCSession didBecomeInactive (iOS)")
    } // sessionDidBecomeInactive

    func sessionDidDeactivate(_ session: WCSession) {
        // iOS only – after deactivation, you must reactivate
        print("WCSession didDeactivate (iOS) – reactivating")
        WCSession.default.activate()
    } // sessionDidDeactivate
} // class PhoneWatchSessionReceiver
