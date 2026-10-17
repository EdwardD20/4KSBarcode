//
//  BarcodeWatchApp/WatchBarcodeView.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI

struct WatchBarcodeView: View {
    @EnvironmentObject var phoneWatchReceiver: WatchSessionReceiver

    var body: some View {
        VStack(spacing: 8) {
            // --- Logo at the top ---
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .padding(.top, 4)
                .accessibilityLabel("Logo")

            // --- Barcode (if received) ---
            if let image = phoneWatchReceiver.latestBarcodeImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 6)
                    .accessibilityLabel("Client barcode")

//                if !phoneWatchReceiver.clientId.isEmpty {
//                    Text(phoneWatchReceiver.clientId)
//                        .font(.footnote.weight(.semibold))
//                        .lineLimit(1)
//                } // if
            } else {
                if !phoneWatchReceiver.clientId.isEmpty {
                    // We have clientId text but no barcode image yet
                    Text(phoneWatchReceiver.clientId)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }

                Text("Waiting for barcode...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Waiting for barcode from phone")
            } // if/else chain

            Spacer(minLength: 0)
        } // VStack
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    } // body
} // struct WatchBarcodeView
