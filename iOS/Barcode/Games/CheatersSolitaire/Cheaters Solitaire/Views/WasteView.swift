//
//  Views/WasteView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Renders the 3-card waste fan where any visible card is selectable, not just the top card (a cheat).
//

import SwiftUI
import Combine

/// Shows up to three drawn cards fanned out. A normal player's instinct is to
/// only be able to act on the top (frontmost) card — but every card here is
/// actually tappable and selectable. That's the core hidden cheat: any of the
/// three routes through the same `selectOrDeselect` as the true top card,
/// with no visible difference in how it behaves.
///
/// Double-tap any card to send it straight to its matching foundation —
/// unless that card could ALSO be legally played onto the tableau, in which
/// case it's left for you to decide manually.
struct WasteView: View {
    @ObservedObject var game: SolitaireGameState
    var cardWidth: CGFloat = 88
    var fanOffset: CGFloat = 22

    private var cardHeight: CGFloat { cardWidth * 1.4 }

    var body: some View {
        ZStack(alignment: .leading) {
            ForEach(Array(game.waste.suffix(3).enumerated()), id: \.element.id) { offset, card in
                let realIndex = game.waste.count - min(3, game.waste.count) + offset
                let source = CardSource.waste(realIndex)
                let isSelected = game.selectedSource == source

                ZStack {
                    CardView(card: card, width: cardWidth, colorsReversed: game.colorsReversed)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: isSelected ? 3 : 0)
                        ) // overlay (selection highlight)

                    CardTapView(
                        onSingleTap: { game.selectOrDeselect(source) },
                        onDoubleTap: { _ = game.autoMoveOnDoubleTap(source) }
                    ) // CardTapView (single = select, instant; double = auto-to-foundation)
                    .frame(width: cardWidth, height: cardHeight)
                } // ZStack (card + its tap-hit-testing overlay)
                .offset(x: CGFloat(offset) * fanOffset)
                .zIndex(Double(offset))
                .opacity(game.dragPreview?.source == source ? 0 : 1) // the floating DragPreviewOverlay stands in for this while it's airborne
                .simultaneousGesture(dragGesture(source: source, card: card)) // drag-to-move, alongside CardTapView's own tap handling
            } // ForEach
        } // ZStack
        .frame(width: cardWidth + fanOffset * 2, height: cardHeight, alignment: .leading)
        .onGeometryChange(for: CGRect.self) { geo in
            geo.frame(in: .named("board"))
        } action: { newFrame in
            game.wasteFrame = newFrame
        } // onGeometryChange (lets the win-triggered auto-complete animation know where to launch a waste card's flight from)
    } // body

    /// Waste is a drag SOURCE only — every visible card here is grabbable,
    /// matching the existing tap rule that any of the three fanned cards
    /// (not just the true top one) is selectable.
    private func dragGesture(source: CardSource, card: Card) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("board"))
            .onChanged { value in
                if game.dragPreview?.source != source {
                    guard game.beginDrag(source) else { return }
                    game.dragPreview = DragPreview(source: source, cards: [card], cardWidth: cardWidth, overlapOffset: 0, location: value.location)
                } // if this drag hasn't been registered with SolitaireGameState yet
                game.dragPreview?.location = value.location
            } // onChanged
            .onEnded { value in
                guard game.dragPreview?.source == source else { return }
                game.endDrag(at: value.location)
            } // onEnded
    } // dragGesture(source:card:)
} // WasteView
