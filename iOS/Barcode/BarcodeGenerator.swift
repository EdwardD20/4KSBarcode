//
//  Barcode/BarcodeGenerator.swift
//
//  Created by Ed Danley on 4/24/26.
//


import UIKit
import CoreImage

/// Generate a Code128 barcode UIImage sized to requested size (points).
/// Returns nil on failure.
func generateCode128BarcodeImage(from string: String, size: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
    guard let data = string.data(using: .ascii),
          let filter = CIFilter(name: "CICode128BarcodeGenerator") else {
        return nil
    }

    filter.setValue(data, forKey: "inputMessage")
    // You can adjust quietSpace (left/right margin) if needed:
    // filter.setValue(7.0, forKey: "inputQuietSpace")

    guard let ciImage = filter.outputImage else { return nil }

    // Scale CI image to desired pixel size
    let pixelWidth = size.width * scale
    let pixelHeight = size.height * scale
    let extent = ciImage.extent.integral
    let scaleX = pixelWidth / extent.width
    let scaleY = pixelHeight / extent.height
    let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

    let context = CIContext(options: nil)
    if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
    return nil
} // generateCode128BarcodeImage

/// Generate a QR Code UIImage sized to requested size (points).
/// Returns nil on failure.
func generateQRCodeImage(from string: String,
                         size: CGSize,
                         scale: CGFloat = UIScreen.main.scale) -> UIImage? {
    guard let data = string.data(using: .utf8),
          let filter = CIFilter(name: "CIQRCodeGenerator") else {
        return nil
    } // guard

    filter.setValue(data, forKey: "inputMessage")
    filter.setValue("M", forKey: "inputCorrectionLevel") // L, M, Q, H

    guard let ciImage = filter.outputImage else {
        return nil
    } // guard

    let extent = ciImage.extent.integral

    // Integer pixel target size
    let targetPixels = Int(min(size.width, size.height) * scale)

    let scaleFactor = CGFloat(targetPixels) / extent.width

    let transformed = ciImage.transformed(
        by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
    )

    let context = CIContext(options: [
        .useSoftwareRenderer: false
    ])

    guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
        return nil
    } // guard

    // HARD raster (prevents interpolation later)
    let uiImage = UIImage(cgImage: cgImage, scale: scale, orientation: .up)

    return uiImage
} // generateQRCodeImage

/// Convenience: generate PNG data (lossless) for a given string and size
func generateBarcodePNGData(from string: String, size: CGSize) -> UIImage? {
    guard let img = generateCode128BarcodeImage(from: string, size: size) else { return nil }
    return img
} // generateBarcodePNGData
