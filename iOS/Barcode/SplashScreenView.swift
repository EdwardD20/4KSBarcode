//
//  Barcode/SplashScreenView.swift
//
//  Created by Ed Danley on 4/24/26.
//

import SwiftUI
import Combine

struct SplashScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var isVisible = false
    @State private var countdown: Int = Int(Globals.splashDuration)
    @State private var isAnimating: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.red)
                    .ignoresSafeArea()

                VStack(alignment: .center, spacing: 16) {

                    Image("FeelGoodDealsLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: geo.size.width,
                            maxHeight: geo.size.height * 0.25
                        )
                        .accessibilityLabel("Feel Good Deals logo")
                        .opacity(isVisible ? 1 : 0)
                        .scaleEffect(isVisible ? 1 : 0.9)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.6), value: isVisible)

                    let text = NSLocalizedString("splash_text", comment: "")

                    let markdownText = text.replacingOccurrences(
                        of: "\n",
                        with: "  \n"
                    )

                    let attributed = try! AttributedString(markdown: markdownText)

                    let addressMarkdown = NSLocalizedString("splash_address", comment: "")
                    let addressAttributed = try! AttributedString(markdown: addressMarkdown)

                    let addressPlainText = addressMarkdown
                        .replacingOccurrences(of: "**", with: "")
                        .replacingOccurrences(of: "_", with: "")

                    let encodedAddress = addressPlainText.addingPercentEncoding(
                        withAllowedCharacters: .urlQueryAllowed
                    ) ?? ""

                    VStack(spacing: 8) {
                        Text(attributed)
                            .font(.system(size: geo.size.height * 0.06, weight: .regular, design: .default)).italic()
                            .foregroundColor(Color(.black))
                            .minimumScaleFactor(0.5)
                            .lineLimit(nil)
                            .accessibilityLabel("Feel Good Deals information")
                            .opacity(isVisible ? 1 : 0)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.3), value: isVisible)

                        Link(destination: URL(string: mapsURL + "/?q=\(encodedAddress)")!) {
                            Text(addressAttributed)
                                .font(.system(size: geo.size.height * 0.03, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(
                                    layoutDirection == .rightToLeft
                                    ? .trailing
                                    : .leading
                                )
                                .frame(
                                    maxWidth: geo.size.width * 0.9,
                                    alignment: layoutDirection == .rightToLeft
                                    ? .trailing
                                    : .leading
                                )
                                .minimumScaleFactor(0.5)
                                .lineLimit(nil)
                                .accessibilityLabel("Feel Good Deals address")
                        } // Link
                    } // VStack
                    
                } // VStack
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Feel Good Deals splash screen")
                .frame(maxHeight: .infinity, alignment: .top)

                if countdown > 0 {
                    // Not so subtle countdown in lower-right corner
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("\(countdown)")
                                .font(.system(size: geo.size.height * 0.10, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange, .yellow],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .red.opacity(0.8), radius: 6)
                                .shadow(color: .orange.opacity(0.6), radius: 12)
                                .scaleEffect(isAnimating ? 1.15 : 0.95)
                                .animation(
                                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                    value: isAnimating
                                )
                                .onAppear {
                                    isAnimating = true
                                } // onAppear
                        } // HStack
                    } // VStack
                } // if countdown > 0

            } // ZStack
        } // GeometryReader
        .onAppear {
            isVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(notification: .screenChanged, argument: nil)
                UIAccessibility.post(notification: .announcement, argument: "Feel Good Deals")
            } // dispatch
        } // .onAppear
        .onReceive(timer) { _ in
            if countdown > 0 {
                countdown -= 1
            } // if countdown
        } // .onReceive
    } // body
} // SplashScreenView
