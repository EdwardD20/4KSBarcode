//
//  Barcode/PhoneWatchSessionManager.swift
//
//  Created by Ed Danley on 4/24/26.
//


import Foundation
import WatchConnectivity
import UIKit
import Combine

final class PhoneWatchSessionManager: NSObject, WCSessionDelegate, ObservableObject {

    // Singleton
    static let shared = PhoneWatchSessionManager() // PhoneWatchSessionManager.shared

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    // MARK: - ObservableObject
    let objectWillChange = ObservableObjectPublisher() // objectWillChange

    private var lastSentBarcodeData: Data? = nil // Track last sent barcode to detect changes
    private var pendingBarcode: (image: UIImage, clientId: String)?

    private override init() {
        super.init() // super.init
        if let session = session {
            session.delegate = self
            session.activate()
        } // if

        // Observe model changes. The saved barcode is sent after WCSession activates.
        observeModelChanges()
    } // init

    // MARK: - Push current barcode on first launch
    private func sendCurrentBarcodeIfAvailable() {
        // Read barcode string and clientId from UserDefaults
        guard let barcodeString = UserDefaults.standard.string(forKey: "LastScannedBarcode") else { return } // guard
        let clientId = UserDefaults.standard.string(forKey: PassModel.clientKey) ?? "" // get clientId
        guard !clientId.isEmpty else { return } // guard

        let style = UserDefaults.standard.string(forKey: "clientDisplayStyle") ?? "barcode"
        switch style {
        case "qrcode":
            if let qr = generateQRCodeImage(from: barcodeString, size: CGSize(width: 300, height: 300)) {
                sendBarcodeIfChanged(barcodeImage: qr, clientId: clientId)
            }
        case "number":
            let numberImg = Self.renderNumberImage(text: barcodeString)
            sendBarcodeIfChanged(barcodeImage: numberImg, clientId: clientId)
        case "barcode": fallthrough
        default:
            if let code128 = generateCode128BarcodeImage(from: barcodeString, size: CGSize(width: 300, height: 100)) {
                sendBarcodeIfChanged(barcodeImage: code128, clientId: clientId)
            }
        }
    } // sendCurrentBarcodeIfAvailable

    // MARK: - Observe model changes
    private func observeModelChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleModelUpdate),
            name: .barcodeDidChange,
            object: nil
        ) // addObserver
    } // observeModelChanges

    @objc private func handleModelUpdate() {
        // Read latest barcode string and clientId from UserDefaults
        guard let barcodeString = UserDefaults.standard.string(forKey: "LastScannedBarcode") else { return } // guard
        let clientId = UserDefaults.standard.string(forKey: PassModel.clientKey) ?? "" // get clientId
        guard !clientId.isEmpty else { return } // guard

        let style = UserDefaults.standard.string(forKey: "clientDisplayStyle") ?? "barcode"
        switch style {
        case "qrcode":
            if let qr = generateQRCodeImage(from: barcodeString, size: CGSize(width: 300, height: 300)) {
                sendBarcodeIfChanged(barcodeImage: qr, clientId: clientId)
            }
        case "number":
            let numberImg = Self.renderNumberImage(text: barcodeString)
            sendBarcodeIfChanged(barcodeImage: numberImg, clientId: clientId)
        case "barcode": fallthrough
        default:
            if let code128 = generateCode128BarcodeImage(from: barcodeString, size: CGSize(width: 300, height: 100)) {
                sendBarcodeIfChanged(barcodeImage: code128, clientId: clientId)
            }
        }
    } // handleModelUpdate

    // MARK: - Send only if changed
    private func sendBarcodeIfChanged(barcodeImage: UIImage, clientId: String) {
        guard let session = session,
              session.isPaired,
              session.isWatchAppInstalled else { return } // guard

        guard session.activationState == .activated else {
            pendingBarcode = (image: barcodeImage, clientId: clientId)
            return
        } // guard session activation
        guard let data = barcodeImage.pngData() else { return } // guard

        // Only send if different from last sent
//        if data != lastSentBarcodeData {
            lastSentBarcodeData = data

            // Write to a temp file
            let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("barcode.png")
            do {
                try data.write(to: tmpURL)
            } catch {
                print("Phone: Could not write temp PNG: \(error)")
                return
            } // do/catch

            let metadata: [String: Any] = [
                "type": "barcode",
                "clientId": clientId
            ] // metadata

            session.transferFile(tmpURL, metadata: metadata)
            print("Phone: Sent barcode PNG + clientId to watch")
//        } // if data changed
    } // sendBarcodeIfChanged

    public func sendBarcodeAndClientId(barcodeImage: UIImage, clientId: String) {
        sendBarcodeIfChanged(barcodeImage: barcodeImage, clientId: clientId)
    } // sendBarcodeAndClientId

    // Queue the latest client ID for the paired Watch, even when it is not reachable.
    func sendClientIdText(_ clientId: String) {
        guard let session = session,
              session.isPaired,
              session.isWatchAppInstalled else { return } // guard

        do {
            try session.updateApplicationContext(["clientId": clientId])
            print("Phone: queued current clientId for Watch via applicationContext")
        } catch {
            print("Phone: failed to queue clientId: \(error)")
        } // do/catch
    } // sendClientIdText

    // Render a number-only image so the Watch can display the chosen style
    private static func renderNumberImage(text: String) -> UIImage {
        let rendererSize = CGSize(width: 800, height: 200)
        let renderer = UIGraphicsImageRenderer(size: rendererSize)
        return renderer.image { ctx in
            UIColor.systemBackground.setFill()
            ctx.fill(CGRect(origin: .zero, size: rendererSize))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 64, weight: .bold),
                .foregroundColor: UIColor.label,
                .paragraphStyle: paragraph
            ]

            let attributed = NSAttributedString(string: text, attributes: attrs)
            let textRect = CGRect(x: 0, y: (rendererSize.height - 72) / 2, width: rendererSize.width, height: 72)
            attributed.draw(in: textRect)
        }
    }

    // MARK: - WCSessionDelegate
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        if let error {
            print("Phone WC activation error: \(error)")
            return
        } // if

        print("Phone WC activation state: \(activationState.rawValue)")

        // After activation, push current state (clientId only)
        if activationState == .activated,
           session.isPaired,
           session.isWatchAppInstalled {
            pushCurrentClientIdToWatch()

            if let pendingBarcode {
                self.pendingBarcode = nil
                sendBarcodeIfChanged(
                    barcodeImage: pendingBarcode.image,
                    clientId: pendingBarcode.clientId
                )
            } else {
                sendCurrentBarcodeIfAvailable()
            }
        } // if
    } // session activationDidCompleteWith

    private func pushCurrentClientIdToWatch() {
        guard let session = session else { return } // guard
        guard session.isPaired, session.isWatchAppInstalled else { return } // guard

        let clientId = UserDefaults.standard.string(forKey: PassModel.clientKey) ?? "" // read clientId
        guard !clientId.isEmpty else { return } // guard

        do {
            try session.updateApplicationContext([
                "clientId": clientId
            ])
            print("Phone: pushed current clientId to watch via applicationContext")
        } catch {
            print("Phone: failed to update applicationContext: \(error)")
        } // do/catch
    } // pushCurrentClientIdToWatch

    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Phone WC sessionDidBecomeInactive")
    } // sessionDidBecomeInactive

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
        print("Phone WC sessionDidDeactivate -> activate()")
    } // sessionDidDeactivate
} // PhoneWatchSessionManager

extension Notification.Name {
    static let barcodeDidChange = Notification.Name("BarcodeDidChange")
} // Notification.Name extension

