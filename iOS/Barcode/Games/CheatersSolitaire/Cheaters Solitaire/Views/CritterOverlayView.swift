//
//  Views/CritterOverlayView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Bug-crawl-to-frog-snap animation shown as one of the cheat consequence events.
//

import SwiftUI

enum CritterKind: CaseIterable {
    case ladybug, walkingStick, grasshopper

    /// Swap for real art; SF Symbols used only so this compiles out of the box.
    var systemImageFallback: String {
        switch self {
        case .ladybug: return "ladybug.fill"
        case .walkingStick: return "line.diagonal"
        case .grasshopper: return "hare.fill" // placeholder glyph — replace with real art
        }
    }
}

/// Plays the "critter crawls across the screen, frog snaps it up" sequence
/// used as a lighthearted (not scary) tell that the player has been cheating.
/// Deliberately cartoonish per the design brief — nothing that looks real.
struct CritterOverlayView: View {
    @Binding var isActive: Bool
    var onFinished: () -> Void

    @State private var critterX: CGFloat = -60
    @State private var critterKind: CritterKind = .ladybug
    @State private var frogVisible = false
    @State private var frogX: CGFloat = -120
    @State private var showSnap = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isActive {
                    Image(systemName: critterKind.systemImageFallback)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .foregroundColor(.red)
                        .position(x: critterX, y: geo.size.height * 0.85)

                    if frogVisible {
                        Image(systemName: "leaf.fill") // placeholder for a frog sprite
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .foregroundColor(.green)
                            .position(x: frogX, y: geo.size.height * 0.85)
                    }
                }
            }
            .onChange(of: isActive) { _, active in
                guard active else { return }
                runSequence(screenWidth: geo.size.width)
            }
        }
        .allowsHitTesting(false)
    }

    private func runSequence(screenWidth: CGFloat) {
        critterKind = CritterKind.allCases.randomElement() ?? .ladybug
        critterX = -60
        frogVisible = false
        frogX = -120

        withAnimation(.linear(duration: 2.2)) {
            critterX = screenWidth * 0.55
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            frogVisible = true
            withAnimation(.easeIn(duration: 0.7)) {
                frogX = screenWidth * 0.5
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            SoundManager.shared.playFrogSnap()
            withAnimation(.easeOut(duration: 0.6)) {
                frogX = screenWidth + 80
                critterX = screenWidth + 80
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            isActive = false
            frogVisible = false
            onFinished()
        }
    }
}
