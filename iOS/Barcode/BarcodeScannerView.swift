//
//  Barcode/BarcodeScannerView.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI
import AVFoundation

struct BarcodeScannerView: UIViewControllerRepresentable {
    var metadataObjectTypes: [AVMetadataObject.ObjectType] = [.code128, .code39, .qr]
    var onScanned: (String) -> Void
    var onCancel: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) } // makeCoordinator

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.metadataObjectTypes = metadataObjectTypes
        vc.delegate = context.coordinator
        return vc
    } // makeUIViewController

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // nothing to update for now
    } // updateUIViewController

    // Coordinator: bridge delegate calls into SwiftUI closures
    class Coordinator: NSObject, ScannerViewControllerDelegate {
        let parent: BarcodeScannerView
        init(_ parent: BarcodeScannerView) { self.parent = parent } // init

        func scannerDidScan(_ value: String) {
            // Save scanned value to UserDefaults
            UserDefaults.standard.set(value, forKey: "LastScannedBarcode")

            // Notify the Watch manager about the change
            NotificationCenter.default.post(name: .PassModelDidUpdate, object: nil)

            // Call SwiftUI closure
            parent.onScanned(value)
        } // scannerDidScan

        func scannerDidCancel() {
            parent.onCancel?()
        } // scannerDidCancel
    } // Coordinator
} // BarcodeScannerView

// Notification for Watch manager
extension Notification.Name {
    static let PassModelDidUpdate = Notification.Name("PassModelDidUpdate")
} // Notification.Name extension
