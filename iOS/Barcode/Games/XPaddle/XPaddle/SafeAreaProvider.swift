//
// SafeAreaProvider.swift
//
// My original XPaddle game conceived in 2009 and was written in Objective C.
// Unfortunately the original source was lost.
//
// In 2026, I found this project on GitHub.com and adapted it back to my original game.
// Adapted from: https://github.com/rickyjonesus/pong
//

import SwiftUI
import UIKit
import Combine

/// Reads the real safe-area insets straight from the key window's UIKit
/// layer. SwiftUI's `GeometryReader.safeAreaInsets` can report zero for a
/// beat (or unreliably) right after launch/rotation; going straight to
/// UIKit — the same source iOS itself uses to place the Dynamic Island /
/// notch cutout — is the one value we can fully trust.
final class SafeAreaProvider: ObservableObject {
    @Published private(set) var insets: UIEdgeInsets = .zero

    private var pollTimer: Timer?
    private var pollCount = 0

    /// Refreshes immediately, then keeps polling briefly — the window's
    /// safe area isn't always final on the very first layout pass.
    func begin() {
        refresh()
        pollCount = 0
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.refresh()
            self.pollCount += 1
            if self.pollCount > 20 { timer.invalidate() }
        } // Timer.scheduledTimer
    } // func begin

    func stop() {
        pollTimer?.invalidate()
    } // func stop

    func refresh() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        guard let window = windowScene.windows.first(where: \.isKeyWindow) else { return }

        // UIWindow.safeAreaInsets is the same source iOS itself uses to place
        // the Dynamic Island / notch cutout, and on real hardware it's
        // already correctly asymmetric in landscape (non-zero only on the
        // edge that's actually cut out) — so trust it as-is. The one wrinkle
        // is that some configurations (seen on Simulator) report the same
        // non-zero value on BOTH edges; only in that ambiguous tie do we
        // fall back to the current orientation to decide which edge is real.
        let raw = window.safeAreaInsets
        var newInsets = raw
        if raw.left == raw.right, raw.left > 0 {
            switch windowScene.interfaceOrientation {
            case .landscapeLeft:
                newInsets.right = 0
            case .landscapeRight:
                newInsets.left = 0
            default:
                break
            }
        }

        if newInsets != insets {
            insets = newInsets
        }
    } // func refresh
} // XPaddleSafeAreaProvider
