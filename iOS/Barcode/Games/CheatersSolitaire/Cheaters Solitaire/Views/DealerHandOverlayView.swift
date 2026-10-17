//
//  Views/DealerHandOverlayView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Renders the dealer's hand overlay (currently placeholder art) reflecting the current game phase and gesture.
//

import SwiftUI

/// Draws just the two hands (never a full dealer figure), positioned per the
/// randomized handedness for this game. Add your hand artwork to
/// Assets.xcassets under the names produced by `DealerAppearance.imageName`.
/// Each image set should have its own light/dark or "Any" appearance variant
/// as needed so hands read correctly against the table background.
struct DealerHandOverlayView: View {
    let appearance: DealerAppearance
    let phase: SolitaireGamePhase

    var body: some View {
        GeometryReader { geo in
            ZStack {
                handImage(for: .left)
                    .position(x: geo.size.width * 0.15, y: geo.size.height * 0.08)

                handImage(for: .right)
                    .position(x: geo.size.width * 0.85, y: geo.size.height * 0.08)
            }
        }
        .allowsHitTesting(false) // hands are decorative; gestures live on DeckView/card views
    }

    /// NOTE: the `.scaleEffect(x: -1)` mirror below is a placeholder-art trick —
    /// it lets one SF Symbol stand in for both hands. Once you swap in real
    /// hand illustrations (separate left/right artwork), remove that mirror;
    /// otherwise your actual right-hand image will get double-flipped.
    private func handImage(for side: HandSide) -> some View {
        let gesture = gesture(for: side)
        // Swap Image(systemName:) for Image("\(appearance.imageName(...))") once
        // real hand art is in the asset catalog. Placeholder keeps this compiling.
        return Image(systemName: "hand.raised.fill")
            .resizable()
            .scaledToFit()
            .frame(width: appearance.gender == .masculine ? 90 : 72)
            .foregroundStyle(.primary)
            .scaleEffect(x: side == .right ? -1 : 1, y: 1) // mirror, not rotate — keeps fingers pointing up
            .opacity(shouldShow(side) ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: phase)
            .accessibilityHidden(true)
            .id(appearance.imageName(for: side, gesture: gesture)) // forces refresh when the asset key changes
    }

    private func gesture(for side: HandSide) -> HandGesture {
        switch phase {
        case .deckOnTable:
            return .resting
        case .deckInHand:
            return side == appearance.restingHandSide ? .holdingDeck : .resting
        case .shuffling:
            return side == appearance.restingHandSide ? .holdingDeck : .resting
        case .dealing:
            return side == appearance.dealingHandSide ? .dealing : .holdingDeck
        case .playing:
            return side == appearance.dealingHandSide ? .drawingThree : .holdingDeck
        }
    }

    private func shouldShow(_ side: HandSide) -> Bool {
        // Both hands are visible throughout; only their gesture/pose changes.
        true
    }
}
