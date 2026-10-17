//
//  Barcode/BottomBannerView.swift
//
//  Created by Ed Danley on 2/21/26.
//

import SwiftUI
import Combine

struct BottomBannerView: View {
    @State private var showFlyer = false
    @State private var showPantryBanner = true

    private let bannerTimer = Timer
        .publish(every: 10, on: .main, in: .common)
        .autoconnect()

    var body: some View {
        let titleKey: LocalizedStringKey =
            showPantryBanner ? "pantry_information" : "feel_good_deals_label"

        let iconName: String? =
            showPantryBanner ? nil : "Facebook_Logo_Primary"

        ZStack {
            ShadedBottomBarGeometry(height: 30)

            ShadedBottomBarTapLayer(
                height: 30,
                titleKey: titleKey,
                iconName: iconName
            ) {
                if showPantryBanner {
                    showFlyer = true
                } else {
                    openFeelGoodDeals()
                } // if showPantryBanner
            } // ShadedBottomBarTapLayer
            .onReceive(bannerTimer) { _ in
                withAnimation(.easeInOut(duration: 0.25)) {
                    showPantryBanner.toggle()
                } // withAnimation
            } // .onReceive
        }
        .sheet(isPresented: $showFlyer) {
            GraphicSheet(title: "pantry_information", graphic: "FlyerGraphic")
        } // .sheet
    }

    private func openFeelGoodDeals() {
        if let url = URL(string: feelGoodDealsURL) {
            UIApplication.shared.open(url)
        } // if url
    } // openFeelGoodDeals
}
