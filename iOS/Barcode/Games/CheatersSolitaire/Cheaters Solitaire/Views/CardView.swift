//
//  Views/CardView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Renders a single card's face or back, including rank, suit, and pip colors.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Renders one card using the user-supplied `CardFront` / `CardBack` image
/// assets as the base layer (corners already rounded in the art itself —
/// no SwiftUI clipping/stroke needed). Rank + suit are drawn on top of
/// `CardFront` in code, so only ONE blank front image is needed for all 52
/// combinations. Pip colors (`cardRed`/`cardBlack` below) are fixed, NOT
/// pulled from Assets.xcassets — a card's suit ink color is a print
/// convention that shouldn't shift with the system's light/dark setting,
/// and defining them in code avoids depending on a correctly-configured
/// Dark-appearance variant in the asset catalog.
///
/// Layout on a face-up card:
///   - top-left corner index (rank + suit)
///   - bottom-right corner index, MIRRORED 180° (standard playing-card
///     convention so the card reads right-side-up from either end of a fan)
///   - big center content: the suit symbol for an Ace, a big colored number
///     for 2–10, or a face-card image ("Jack-Spades", "Queen-Hearts", etc.)
///     for Jack/Queen/King. IMPORTANT: these must be added to Assets.xcassets
///     as Image Sets (right-click > New Image Set), not dragged in as loose
///     .png files — Image(_:) by name only reliably finds asset catalog
///     entries. If a name doesn't resolve, the console logs exactly which
///     one and the card falls back to showing the rank letter instead.
struct CardView: View {
    let card: Card
    var width: CGFloat = 88
    /// When true, this card's pip color is inverted relative to its actual
    /// suit — a red suit renders in the black ink color and vice versa.
    /// Purely visual: `card.isRed`/`card.suit` are untouched, so stacking
    /// and foundation rules elsewhere are unaffected by this. Driven by
    /// `SolitaireGameState.colorsReversed`, the "reverse red and black" cheat
    /// consequence (see `registerCheatAndCheckConsequence`).
    var colorsReversed: Bool = false

    /// Matches the aspect ratio of your CardFront/CardBack art. Adjust this
    /// if your images aren't the standard ~0.714 (5:7) card ratio.
    private var height: CGFloat { width * 1.4 }

    // Fixed pip colors — deliberately NOT Color("CardRed")/Color("CardBlack").
    // Tune these two values directly if you want a different exact shade.
    // Shifted toward orange-red (vs. a pure crimson) so it stays
    // distinguishable from the green felt for red-green colorblind users.
    private let cardRed = Color(red: 0.92, green: 0.22, blue: 0.05)
    private let cardBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    private var pipColor: Color { (card.isRed != colorsReversed) ? cardRed : cardBlack }

    var body: some View {
        ZStack {
            Image(card.isFaceUp ? "CardFront" : "CardBack")
                .resizable()
                .aspectRatio(contentMode: .fit)

            if card.isFaceUp {
                cornerIndex
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(width * 0.08)

                cornerIndex
                    .rotationEffect(.degrees(180)) // mirrored, standard playing-card convention
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(width * 0.08)

                centerContent
            } // if card.isFaceUp
        } // ZStack
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
        .accessibilityLabel(card.isFaceUp ? "\(card.rank.label) of \(card.suit.rawValue)" : "Face-down card")
    } // body

    private var cornerIndex: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(card.rank.label)
                .font(.system(size: width * 0.22, weight: .bold))
            Text(card.suit.symbol)
                .font(.system(size: width * 0.22))
        } // VStack (rank/suit text)
        .foregroundColor(pipColor)
    } // cornerIndex

    @ViewBuilder
    private var centerContent: some View {
        if card.rank == .ace {
            Text(card.suit.symbol)
                .font(.system(size: width * 0.5))
                .foregroundColor(pipColor)
        } else if let faceName = card.rank.faceName {
            faceCardImage(named: "\(faceName)-\(card.suit.name)")
        } else {
            Text(card.rank.label)
                .font(.system(size: width * 0.42, weight: .bold))
                .foregroundColor(pipColor)
        } // if/else (ace vs. face card vs. number)
    } // centerContent

    /// Loads a face-card image by name from Assets.xcassets. Unlike plain
    /// `Image("name")`, this checks whether the asset actually exists first —
    /// if it doesn't (wrong name, or it was added as a loose file instead of
    /// an Image Set), this logs exactly which name failed and falls back to
    /// the rank letter instead of leaving the card silently blank.
    @ViewBuilder
    private func faceCardImage(named name: String) -> some View {
        #if os(iOS)
        if let uiImage = UIImage(named: name) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height * 0.42) // height-only: lets width scale naturally, avoiding letterbox padding
        } else {
            missingFaceCardFallback(name: name)
        } // if/else
        #elseif os(macOS)
        if let nsImage = NSImage(named: name) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height * 0.42)
        } else {
            missingFaceCardFallback(name: name)
        } // if/else
        #endif
    } // faceCardImage(named:)

    private func missingFaceCardFallback(name: String) -> some View {
        Text(card.rank.label)
            .font(.system(size: width * 0.42, weight: .bold))
            .foregroundColor(pipColor)
            .onAppear {
                print("CardView: face-card asset '\(name)' not found — make sure it's added to Assets.xcassets as an Image Set (not a loose file), with that EXACT name.")
            } // onAppear
    } // missingFaceCardFallback(name:)
} // CardView

#Preview {
    HStack {
        CardView(card: Card(suit: .hearts, rank: .queen, isFaceUp: true))
        CardView(card: Card(suit: .spades, rank: .ace, isFaceUp: true))
        CardView(card: Card(suit: .clubs, rank: .seven, isFaceUp: true))
        CardView(card: Card(suit: .diamonds, rank: .king, isFaceUp: false))
    } // HStack
    .padding()
}
