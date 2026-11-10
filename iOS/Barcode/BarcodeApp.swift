//
//  Barcode/BarcodeApp.swift
//
//  Created by Ed Danley on 4/24/26.
//


import SwiftUI

enum Globals {
    #if DEBUG
    static let splashDuration: TimeInterval = 2
    #else
    static let splashDuration: TimeInterval = 4
    #endif
} // Globals

@main
struct BarcodeApp: App {
    // Activate Watch Connectivity at app launch so the saved Client ID is sent
    // even when the barcode screen does not otherwise use the session manager.
    @StateObject private var watchSessionManager = PhoneWatchSessionManager.shared
    @AppStorage("appLanguage") private var appLanguage: String = "en"
    @State private var showSplash = true
    @State private var revealStyle = SplashRevealStyle.random()
    @State private var revealProgress: CGFloat = 0
    @State private var hasScheduledReveal = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.red.ignoresSafeArea()

                ContentView()
                    .modifier(SplashRevealProgress(style: revealStyle, progress: revealProgress))
                    .animation(.easeInOut(duration: 0.9), value: revealProgress)
                    .allowsHitTesting(!showSplash)
                    .environment(\.locale, Locale(identifier: appLanguage))
                    .id(appLanguage)

                if showSplash {
                    SplashScreenView()
                        .onAppear {
                            guard !hasScheduledReveal else { return }
                            hasScheduledReveal = true
                            LanguageBundle.set(appLanguage)
                            DispatchQueue.main.asyncAfter(deadline: .now() + Globals.splashDuration) {
                                showSplash = false
                                DispatchQueue.main.async {
                                    revealProgress = 1
                                } // DispatchQueue.main.async
                            } // DispatchQueue.main.asyncAfter
                        } // onAppear
                        .environment(\.locale, Locale(identifier: appLanguage))
                        .id(appLanguage)
                } // if showSplash
            } // ZStack
            .foregroundStyle(.black)
            .preferredColorScheme(.light)
            .buttonStyle(MainAppButtonStyle())
        } // WindowGroup
        .onChange(of: appLanguage) { _, newValue in
            LanguageBundle.set(newValue)
        } // .onChange
    } // body
} // BarcodeApp
