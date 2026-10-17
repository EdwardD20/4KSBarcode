//
//  Views/FoundationsView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Renders the four suit foundation piles.
//

import SwiftUI

/// Tap a foundation slot to place the currently selected card there, or — if
/// nothing else is selected and there's a card there — to select it and move
/// it back to the tableau (standard, legal Klondike play, not a cheat).
struct FoundationsView: View {
    @ObservedObject var game: SolitaireGameState
    var cardWidth: CGFloat = 88

    // Fixed suit colors — same values as CardView's pip colors, kept
    // deliberately non-adaptive (a suit's ink color shouldn't shift with
    // light/dark mode any more than the cards themselves do).
    // Shifted toward orange-red (vs. a pure crimson) so it stays
    // distinguishable from the green felt for red-green colorblind users.
    private let cardRed = Color(red: 0.92, green: 0.22, blue: 0.05)
    private let cardBlack = Color(red: 0.08, green: 0.08, blue: 0.09)

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Suit.allCases, id: \.self) { suit in
                let source = CardSource.foundation(suit)
                let isSelected = game.selectedSource == source

                ZStack {
                    if let top = game.foundations[suit]?.last {
                        CardView(card: top, width: cardWidth, colorsReversed: game.colorsReversed)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                            ) // overlay (selection highlight)
                    } else {
                        // Placeholder only rendered when the slot is actually
                        // empty — previously this dashed white rect sat behind
                        // every card too, and CardView's image doesn't
                        // perfectly fill its frame (aspect-fit letterboxing),
                        // so slivers of the placeholder's outline peeked out
                        // from behind a placed card. Matches the same
                        // empty-only pattern TableauColumnView already uses.
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            ) // overlay (dashed border on top of the fill)
                            .frame(width: cardWidth, height: cardWidth * 1.4)

                        Text(suit.symbol)
                            .font(.system(size: cardWidth * 0.4))
                            .foregroundColor((suit.isRed != game.colorsReversed) ? cardRed : cardBlack)
                    } // if/else (top card vs. empty)
                } // ZStack (one foundation slot)
                .contentShape(Rectangle()) // guarantees the whole slot is tappable, not just the visible content
                .onTapGesture {
                    handleTap(suit: suit, source: source)
                } // onTapGesture
                .opacity(game.dragPreview?.source == source ? 0 : 1) // the floating DragPreviewOverlay stands in for this while it's airborne
                .simultaneousGesture(dragGesture(suit: suit, source: source)) // drag-to-move a foundation card back to the tableau, alongside the tap handling above
                .onGeometryChange(for: CGRect.self) { geo in
                    geo.frame(in: .named("board"))
                } action: { newFrame in
                    game.dropZoneFrames[.foundation(suit)] = newFrame
                } // onGeometryChange (keeps GameState's drop-zone map current as this slot's size/position changes)
            } // ForEach
        } // HStack
    } // body

    private func handleTap(suit: Suit, source: CardSource) {
        if let selected = game.selectedSource, selected != source {
            if game.moveSelectedCard(toFoundation: suit) {
                return
            } // if move succeeded
            // Invalid move — fall through and try selecting this foundation's card instead.
        } // if let selected
        game.selectOrDeselect(source)
    } // handleTap(suit:source:)

    /// Only meaningful when there's actually a card sitting on this
    /// foundation — dragging an empty slot is a no-op. Standard, legal
    /// Klondike play (see the type's doc comment above), not a cheat.
    private func dragGesture(suit: Suit, source: CardSource) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("board"))
            .onChanged { value in
                guard let top = game.foundations[suit]?.last else { return }
                if game.dragPreview?.source != source {
                    guard game.beginDrag(source) else { return }
                    game.dragPreview = DragPreview(source: source, cards: [top], cardWidth: cardWidth, overlapOffset: 0, location: value.location)
                } // if this drag hasn't been registered with SolitaireGameState yet
                game.dragPreview?.location = value.location
            } // onChanged
            .onEnded { value in
                guard game.dragPreview?.source == source else { return }
                game.endDrag(at: value.location)
            } // onEnded
    } // dragGesture(suit:source:)
} // FoundationsView
