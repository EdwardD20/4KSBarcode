//
//  Barcode/ScannerViewController.swift
//
//  Created by Ed Danley on 4/24/26.
//


import UIKit
import AVFoundation

protocol ScannerViewControllerDelegate: AnyObject {
    func scannerDidScan(_ value: String)
    func scannerDidCancel()
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    // MARK: - Public
    weak var delegate: ScannerViewControllerDelegate?
    var metadataObjectTypes: [AVMetadataObject.ObjectType] = [.code128, .code39, .qr]

    // MARK: - Private
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var metadataOutput: AVCaptureMetadataOutput?
    private var isScanning = true

    // Zoom
    private var initialZoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 1.0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionsAndSetup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    deinit {
        stopSession()
    }

    // MARK: - Permissions & Setup
    private func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.setupSession() } else { self.showDeniedUI() }
                }
            }
        default:
            showDeniedUI()
        }
    }

    private func showDeniedUI() {
        // Simple message + localized Cancel button
        let label = UILabel()
        label.text = NSLocalizedString("camera_permission_message", comment: "Camera access required")
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let cancelButton = makeCancelButton()
        view.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            cancelButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupSession() {
        guard session.inputs.isEmpty else {
            startSession()
            return
        }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showDeniedUI()
            return
        }

        // Prefer a higher preset for better close-up detail (if supported)
        if session.canSetSessionPreset(.hd1280x720) { session.sessionPreset = .hd1280x720 }
        else if session.canSetSessionPreset(.photo) { session.sessionPreset = .photo }

        if session.canAddInput(input) { session.addInput(input) }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = metadataObjectTypes
            self.metadataOutput = metadataOutput
            // Optionally restrict rectOfInterest for faster recognition (commented)
            // metadataOutput.rectOfInterest = CGRect(x: 0.15, y: 0.25, width: 0.7, height: 0.5)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        // Compute zoom bounds
        computeZoomBounds(for: device)

        // Add overlay UI
        addScanningGuide()
        let cancelButton = makeCancelButton()
        view.addSubview(cancelButton)

        // Add gestures
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tap)

        startSession()
    }

    // MARK: - Zoom helpers
    private func computeZoomBounds(for device: AVCaptureDevice) {
        // iOS 13+ has minAvailableVideoZoomFactor/maxAvailableVideoZoomFactor
        minZoomFactor = max(device.minAvailableVideoZoomFactor, 1.0)
        maxZoomFactor = max(device.maxAvailableVideoZoomFactor, minZoomFactor)
        // clamp extreme values (optional nice limit)
        maxZoomFactor = min(maxZoomFactor, 5.0) // avoid ridiculous zoom on some devices
        initialZoomFactor = device.videoZoomFactor
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        switch recognizer.state {
        case .began:
            initialZoomFactor = device.videoZoomFactor
        case .changed:
            var newZoom = initialZoomFactor * recognizer.scale
            newZoom = max(minZoomFactor, min(newZoom, maxZoomFactor))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = newZoom
                device.unlockForConfiguration()
            } catch {
                // ignore
            }
        case .ended, .cancelled, .failed:
            // finalize
            var finalZoom = initialZoomFactor * recognizer.scale
            finalZoom = max(minZoomFactor, min(finalZoom, maxZoomFactor))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = finalZoom
                device.unlockForConfiguration()
            } catch { }
        default:
            break
        }
    }

    // MARK: - Focus & exposure on tap
    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let locationInView = recognizer.location(in: view)
        guard let preview = previewLayer, let device = AVCaptureDevice.default(for: .video) else { return }

        let pointOfInterest = preview.captureDevicePointConverted(fromLayerPoint: locationInView)

        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = pointOfInterest
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = pointOfInterest
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()
        } catch {
            // ignore
        }
    }

    // MARK: - UI Helpers
    private func addScanningGuide() {
        let box = UIView()
        box.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        box.layer.borderWidth = 2
        box.backgroundColor = UIColor.clear
        box.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(box)

        NSLayoutConstraint.activate([
            box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            box.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            box.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            box.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.25)
        ])
    }

    private func makeCancelButton() -> UIButton {
        let cancelButton = UIButton(type: .system)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.setTitle(NSLocalizedString("camera_cancel_button", comment: "Cancel"), for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            // we can't activate here until added as subview, do it at call site (we do add in setupSession)
        ])
        // Place constraints after adding to view in caller
        // For convenience, set accessibility
        cancelButton.accessibilityIdentifier = "ScannerCancelButton"
        return cancelButton
    }

    // MARK: - Start/Stop
    private func startSession() {
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        }
    }

    private func stopSession() {
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
            }
        }
    }

    @objc private func cancelTapped() {
        stopSession()
        delegate?.scannerDidCancel()
    }

    // MARK: - Metadata delegate
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard isScanning else { return }
        guard let metadata = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
              let value = metadata.stringValue else { return }

        isScanning = false
        stopSession()

        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            self.delegate?.scannerDidScan(value)
        }
    }
}
