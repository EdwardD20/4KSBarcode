//
//  BarcodeWatchApp/WatchSessionReceiver.swift
//
//  Created by Ed Danley on 4/24/26.
//


import Foundation
import WatchConnectivity
import SwiftUI
import Combine
import UIKit

final class WatchSessionReceiver: NSObject, WCSessionDelegate, ObservableObject {

    static let shared = WatchSessionReceiver()   // Singleton instance

    @Published var latestBarcodeImage: UIImage?
    @Published var clientId: String = ""

    private let session = WCSession.isSupported() ? WCSession.default : nil
    private let clientIdDefaultsKey = "cachedClientId"

    override private init() {
        super.init()
        clientId = UserDefaults.standard.string(forKey: clientIdDefaultsKey) ?? ""
        session?.delegate = self
        session?.activate()
    } // init

    private func storeClientId(_ clientId: String) {
        DispatchQueue.main.async {
            UserDefaults.standard.set(clientId, forKey: self.clientIdDefaultsKey)
            self.clientId = clientId
        } // DispatchQueue.main.async
    } // storeClientId

    // MARK: - File transfer (PNG + clientId)
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("Watch: didReceive file with metadata = \(file.metadata ?? [:])")
        if let t = file.metadata?["type"] as? String, t != "barcode" {
            print("Watch: Ignoring file, type=\(t)")
            return
        } // if

        do {
            let data = try Data(contentsOf: file.fileURL)
            print("Watch: file size = \(data.count) bytes")
            if let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.latestBarcodeImage = img
                    print("Watch: latestBarcodeImage set")
                } // DispatchQueue.main.async
            } else {
                print("Watch: Could not make UIImage from data")
            } // if
        } catch {
            print("Watch: Failed reading barcode file: \(error)")
        } // do/catch

        if let cid = file.metadata?["clientId"] as? String {
            storeClientId(cid)
        } // if
    } // session didReceive file

    // MARK: - Text-only message
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        if let cid = message["clientId"] as? String {
            storeClientId(cid)
        } // if
    } // session didReceiveMessage

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        if let cid = applicationContext["clientId"] as? String {
            storeClientId(cid)
        } // if
    } // session didReceiveApplicationContext

    // MARK: - Activation
    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            print("Watch WC activation error: \(error)")
            return
        } // if

        if let cid = session.receivedApplicationContext["clientId"] as? String {
            storeClientId(cid)
        } // if
    } // session activationDidCompleteWith
} // WatchSessionReceiver
