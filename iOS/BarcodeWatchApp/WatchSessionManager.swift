//
//  BarcodeWatchApp/WatchSessionManager.swift
//
//  Created by Ed Danley on 4/24/26.
//


import Foundation
import WatchConnectivity
import SwiftUI
import Combine

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#else
typealias PlatformImage = Data
#endif

final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    // ObservableObject publisher
    let objectWillChange = ObservableObjectPublisher()

    // Stored state
    private(set) var clientId: String = "" {
        willSet { objectWillChange.send() }
    }

    private(set) var barcodeImageData: Data? = nil {
        willSet { objectWillChange.send() }
    }

    private override init() {
        super.init()
        loadCachedBarcode()
        activateSession()
    } // init

    private func activateSession() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - Persistence

    private func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    } // documentsURL

    private func cachedBarcodeURL() -> URL {
        documentsURL().appendingPathComponent("cached_barcode.png")
    } // cachedBarcodeURL

    private func loadCachedBarcode() {
        let url = cachedBarcodeURL()
        if let data = try? Data(contentsOf: url) {
            barcodeImageData = data
        }
        if let storedId = UserDefaults.standard.string(forKey: "cachedClientId") {
            clientId = storedId
        }
    } // loadCachedBarcode

    private func persistBarcodeData(_ data: Data, clientId: String?) {
        let url = cachedBarcodeURL()
        try? FileManager.default.removeItem(at: url)
        try? data.write(to: url)

        if let id = clientId {
            UserDefaults.standard.set(id, forKey: "cachedClientId")
        }
    } // persistBarcodeData

    // MARK: - Update Logic (only update if different)

    private func updateFromPayload(_ payload: [String: Any]) {
        DispatchQueue.main.async {
            var newClientId: String? = nil
            var shouldPersist = false

            // Only update clientId if different
            if let id = payload["clientId"] as? String, id != self.clientId {
                self.clientId = id
                newClientId = id
                shouldPersist = true
            }

            // Only update barcode if different
            if let imgData = payload["image"] as? Data,
               imgData != self.barcodeImageData {
                self.barcodeImageData = imgData
                shouldPersist = true
            }

            // Persist only if something changed
            if shouldPersist, let dataToSave = self.barcodeImageData {
                self.persistBarcodeData(dataToSave, clientId: newClientId ?? self.clientId)
            }
        }
    } // updateFromPayload

    // Public accessors
    func currentClientId() -> String { clientId }
    func currentBarcodeImageData() -> Data? { barcodeImageData }
}

// MARK: - WCSessionDelegate
extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let err = error { print("Watch WC activation error: \(err.localizedDescription)") }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        updateFromPayload(message)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        updateFromPayload(applicationContext)
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let tempURL = file.fileURL

        guard let data = try? Data(contentsOf: tempURL) else { return }

        let metadataClientId = file.metadata?["clientId"] as? String

        DispatchQueue.main.async {
            // Only update if different
            if data != self.barcodeImageData || metadataClientId != self.clientId {
                self.barcodeImageData = data
                if let id = metadataClientId, id != self.clientId {
                    self.clientId = id
                }
                self.persistBarcodeData(data, clientId: metadataClientId)
            }
        }
    } // session didReceive file

    #if os(watchOS)
    func sessionReachabilityDidChange(_ session: WCSession) { /* no-op */ }
    #endif
}
