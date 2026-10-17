//
//  Views/DragDropSupport.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/12/26.
//
//  This file accomplishes: Shared types for drag-to-move card interaction — drop zone identifiers, the floating drag-preview model, and the overlay view that renders it above every pile — plus the analogous floating-card model/overlay used by the win-triggered auto-complete animation.
//

import SwiftUI

/// A place a dragged card (or run) can legally land. Deliberately mirrors
/// the destinations `moveSelectedCard` already supports via tap — waste and
/// the stock are drag SOURCES only, never drop targets, matching existing
/// tap rules.
enum DropZoneID: Hashable {
    case tableau(Int)
    case foundation(Suit)
}

/// Snapshot of an in-progress drag, purely for the floating visual preview.
/// The real game data (`SolitaireGameState.tableau`/`waste`/`foundations`) doesn't
/// change until the drag actually completes on a valid target — this is
/// just what gets drawn following the finger in the meantime.
struct DragPreview: Equatable {
    let source: CardSource
    /// One card, or — for a tableau run — the whole run bottom-to-top.
    let cards: [Card]
    let cardWidth: CGFloat
    /// Vertical stacking offset between cards in `cards`; zero for a
    /// single-card drag (waste/foundation), matches the origin pile's
    /// overlap for a tableau run.
    let overlapOffset: CGFloat
    /// Current finger position, in the shared "board" named coordinate
    /// space — see the `.coordinateSpace(name: "board")` applied to each
    /// layout's outer ZStack in SolitaireContentView.
    var location: CGPoint
} // DragPreview

/// Draws whatever's currently being dragged, floating above the finger.
/// Placed as the LAST child of the outermost board ZStack in SolitaireContentView so
/// it paints on top of every pile regardless of which column the drag
/// started or is currently passing over — a card nested deep inside one
/// tableau column can't reliably out-z a sibling column's cards on its own,
/// so the preview lives at the top level instead of trying to animate the
/// original card in place.
struct DragPreviewOverlay: View {
    let preview: DragPreview
    /// Ambient board zoom (iPad/macOS pinch-to-zoom) so the floating card
    /// visually matches the current on-screen card size even though this
    /// overlay itself sits outside the zoomed/panned content group.
    var scale: CGFloat = 1.0
    /// Mirrors `SolitaireGameState.colorsReversed` so a card being actively dragged
    /// doesn't flash back to its normal colors mid-drag while the "reverse
    /// red and black" cheat consequence is in effect.
    var colorsReversed: Bool = false

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(preview.cards.enumerated()), id: \.offset) { index, card in
                CardView(card: card, width: preview.cardWidth * scale, colorsReversed: colorsReversed)
                    .offset(y: CGFloat(index) * preview.overlapOffset * scale)
            } // ForEach
        } // ZStack
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 6)
        .scaleEffect(1.05) // slight "lifted off the table" grow, on top of any ambient zoom
        .position(x: preview.location.x, y: preview.location.y - 24) // small lift above the fingertip so the card isn't hidden under the touch
        .allowsHitTesting(false) // never steals the gesture from the card that's actually being dragged
    } // body
} // DragPreviewOverlay

/// Snapshot of a single card mid-flight during the win-triggered
/// auto-complete animation — see `SolitaireGameState.triggerAutoCompleteIfNeeded()`.
/// One of these exists at a time; the sequence animates one card, waits for
/// it to land, then moves to the next.
struct AutoCompleteFlight: Equatable {
    let card: Card
    /// Current animated position, in the shared "board" named coordinate
    /// space — same convention as `DragPreview.location` above. Animating
    /// this property inside a `withAnimation` block is what makes the card
    /// actually travel across the screen rather than jump.
    var position: CGPoint
    let size: CGSize
} // AutoCompleteFlight

/// Draws the currently-flying auto-complete card. Same "floats above
/// everything, ignores touches" approach as `DragPreviewOverlay` — placed as
/// the last child of the board ZStack in SolitaireContentView so it always paints on
/// top regardless of which pile it's currently passing over.
struct AutoCompleteFlightOverlay: View {
    let flight: AutoCompleteFlight
    var colorsReversed: Bool = false

    var body: some View {
        CardView(card: flight.card, width: flight.size.width, colorsReversed: colorsReversed)
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 6)
            .position(flight.position)
            .allowsHitTesting(false)
    } // body
} // AutoCompleteFlightOverlay
