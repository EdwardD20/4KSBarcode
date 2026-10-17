//
//  Barcode/BarcodeView.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct BarcodeView: View {
    let code: String
    @Environment(\.displayScale) private var displayScale: CGFloat

    var body: some View {
        GeometryReader { geo in
            if let img = generateBarcode(from: code, targetSize: geo.size, scale: displayScale) {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()  // Changed from .scaledToFit()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(Text("No barcode"))
            } // if/else
        } // GeometryReader
    } // body

    /// Generate UIImage that fills the target size (respects container's aspect ratio)
    func generateBarcode(from string: String, targetSize: CGSize, scale: CGFloat) -> UIImage? {
        guard !string.isEmpty else { return nil }

        // 1) Create CI output (Code128)
        let data = Data(string.utf8)
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = data
        guard let output = filter.outputImage else { return nil }

        // 2) Calculate scale to fill the target size
        let scaleX = targetSize.width / output.extent.size.width
        let scaleY = targetSize.height / output.extent.size.height
        
        // Use the smaller scale to ensure barcode fits within bounds
        let scale = min(scaleX, scaleY)

        // 3) Scale CI image uniformly
        let uniformlyScaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let ciContext = CIContext()
        guard let cg = ciContext.createCGImage(uniformlyScaled, from: uniformlyScaled.extent) else { return nil }

        // 4) Render into exact target size
        let format = UIGraphicsImageRendererFormat()
        format.scale = self.displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)

        let img = renderer.image { ctx in
            let destRect = CGRect(origin: .zero, size: targetSize)
            ctx.cgContext.interpolationQuality = .none
            ctx.cgContext.setAllowsAntialiasing(false)
            ctx.cgContext.draw(cg, in: destRect)
        } // renderer.image

        return img
    } // generateBarcode
} // BarcodeView
