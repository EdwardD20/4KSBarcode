//
//  Views/TableauColumnView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Renders a tableau column, including the face-down peek/grab cheat interaction.
//

import SwiftUI

/// One of the seven columns.
///
/// Normal play: tap the top card, OR any buried face-up card that starts a
/// legally-ordered run beneath it (e.g. tapping a red 9 sitting under a
/// black 8 and a red 7), to select that card AND everything stacked on top
/// of it as one unit — the whole run highlights and moves together. Tapping
/// the same card again deselects. Tapping a different pile while something
/// is selected attempts a move there; if invalid, that pile's own top card
/// gets selected instead (so a mis-tap doesn't leave you stuck).
///
/// DOUBLE-tap a card to send it straight to its matching foundation, without
/// needing a second tap on the foundation itself (only works for a single
/// top card, same as real Klondike — a mid-pile run can't jump to a
/// foundation). If that same card could ALSO legally continue a tableau
/// run, the foundation move is skipped — double-tap won't decide that
/// trade-off for you.
///
/// Hidden cheat: HOLDING (2-second long press) any FACE-DOWN card (anywhere
/// in the pile) peeks it as a single card, bypassing the normal ordering
/// rule entirely — a plain tap on a face-down card does nothing, so it
/// can't happen by accident. A face-up card that does NOT start a legal
/// run is still a plain-tap cheat, since accidentally tapping a card
/// that's already visible is much less consequential.
struct TableauColumnView: View {
    @ObservedObject var game: SolitaireGameState
    let pileIndex: Int
    var cardWidth: CGFloat = 88
    var overlapOffset: CGFloat = 30
    /// When true, this column reports its OWN true height (cardHeight plus
    /// whatever the offset-stacked cards add below it) as its layout size,
    /// instead of the single-card height `.offset()` alone would otherwise
    /// imply. iPhone's `phoneGameArea` needs this — its tableau HStack sits
    /// inside a plain vertical `ScrollView`, which sizes its scrollable
    /// content from the layout heights of what's inside it, so an
    /// undersized report there was clipping off (and making unreachable)
    /// however much of the deepest pile hung past that phantom one-card
    /// boundary — and worse, computing that height as a separate ad hoc
    /// guess (max pile depth, then arbitrarily doubled "for buffer") turned
    /// out to be exactly what caused the scroll view's content bounds to
    /// shift unpredictably out from under an in-progress scroll, snapping
    /// it back to the top on release. Reporting the real height here
    /// instead removes the guess entirely.
    /// iPad/macOS's `desktopGameArea`, by contrast, DELIBERATELY relies on
    /// the old single-card-tall report: `compactLayout` and `tableauRow`
    /// each compute `overlapOffset` from a GeometryReader-measured, FIXED
    /// available height and expect cards to visually spill past that one-
    /// card baseline without counting toward layout — reporting the true
    /// height there instead would make the row measure far taller than
    /// intended and break both those layouts. Defaults to false to
    /// preserve that existing desktop behavior; only phoneGameArea opts in.
    var reportsFullHeight: Bool = false

    @State private var peekedCardIndex: Int? = nil
    @State private var isFlashing: Bool = false
    @State private var flashedIndex: Int? = nil

    private var cardHeight: CGFloat { cardWidth * 1.4 }

    var body: some View {
        let pile = game.tableau[pileIndex]

        ZStack(alignment: .top) {
            if pile.cards.isEmpty {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    ) // overlay (dashed border on top of the fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .contentShape(Rectangle()) // belt-and-suspenders, though the fill alone now makes this tappable
                    .onTapGesture {
                        _ = game.moveSelectedCard(toTableau: pileIndex) // empty pile — Kings only
                    } // onTapGesture (empty pile)
            } // if pile.cards.isEmpty

            ForEach(Array(pile.cards.enumerated()), id: \.element.id) { index, card in
                let source = CardSource.tableau(pile: pileIndex, index: index)
                let isTopCard = index == pile.cards.count - 1
                let isRunStart = card.isFaceUp && (isTopCard || game.isValidRunStart(pile: pileIndex, index: index))

                ZStack {
                    CardView(card: displayCard(card, at: index), width: cardWidth, colorsReversed: game.colorsReversed)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.accentColor, lineWidth: isPartOfSelection(index: index) ? 3 : 0)
                        ) // overlay (selection highlight — covers the whole selected run)
                        .overlay(
                            // Brief highlight so it's obvious THIS card just
                            // got hit by the "face-down flip" cheat
                            // consequence — specifically THIS index, since
                            // the flip no longer always lands on the pile's
                            // exposed top card (see `flashedIndex`).
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.orange.opacity(isFlashing && index == flashedIndex ? 0.5 : 0))
                        ) // overlay (consequence flash)

                    CardTapView(
                        onSingleTap: { handleSingleTap(at: index, card: card, source: source) },
                        onDoubleTap: { _ = game.autoMoveOnDoubleTap(source) },
                        // Face-down cards need a deliberate 2-second hold to
                        // peek/grab (the hidden cheat) instead of a plain
                        // tap, so it can't be triggered by accident. Cards
                        // that are already face-up don't get a long-press
                        // handler at all and keep responding instantly.
                        onLongPress: card.isFaceUp ? nil : { handleLongPress(at: index, card: card) }
                    ) // CardTapView (single = select/move, instant; double = auto-to-foundation; long-press = face-down peek cheat)
                    .frame(width: cardWidth, height: cardHeight)
                } // ZStack (card + its tap-hit-testing overlay)
                .offset(y: CGFloat(index) * overlapOffset)
                .zIndex(Double(index))
                .opacity(isBeingDragged(index: index) ? 0 : 1) // the floating DragPreviewOverlay stands in for this while it's airborne
                .simultaneousGesture(
                    dragGesture(source: source, index: index, card: card, isRunStart: isRunStart, pileCards: pile.cards)
                ) // simultaneousGesture (drag-to-move, alongside CardTapView's own tap handling)
            } // ForEach
        } // ZStack
        .frame(
            width: cardWidth,
            // See `reportsFullHeight`'s doc comment above for why this is
            // conditional rather than always the true height.
            height: reportsFullHeight ? cardHeight + overlapOffset * CGFloat(max(pile.cards.count - 1, 0)) : nil,
            alignment: .top
        )
        .onGeometryChange(for: CGRect.self) { geo in
            // `.offset()` on each card below is purely visual — it doesn't
            // grow this ZStack's own layout size, so the geometry SwiftUI
            // reports here is only ever a single card tall (matching just
            // the un-offset top card). Build the real, full-stack rect by
            // hand instead, so a drop anywhere over the visible pile — not
            // just its very top card — registers as landing in this column.
            // A little extra slack past the last card makes it easier to
            // hit, especially on a short pile.
            let origin = geo.frame(in: .named("board")).origin
            let stackHeight = cardHeight + overlapOffset * CGFloat(max(pile.cards.count - 1, 0))
            let slack = cardHeight * 0.5
            return CGRect(x: origin.x, y: origin.y, width: cardWidth, height: stackHeight + slack)
        } action: { newFrame in
            game.dropZoneFrames[.tableau(pileIndex)] = newFrame
        } // onGeometryChange (keeps GameState's drop-zone map current as this column's size/position/card-count changes)
        .onChange(of: game.lastFlippedCard) { _, flipped in
            guard let flipped, flipped.pile == pileIndex else { return }
            flashedIndex = flipped.index
            isFlashing = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isFlashing = false
            } // async fade-out
        } // onChange (flash the exact card that just got hit)
        .onChange(of: game.moveToken) { _, _ in
            // A cheat-revealed face-down card should only stay visible until
            // the NEXT move — draw, card placement, undo, or a stock cheat —
            // not linger indefinitely until this same pile happens to get
            // tapped or dragged again. `moveToken` increments exactly once
            // per real move (see its doc comment in SolitaireGameState), so this
            // fires reliably regardless of which pile the move touched.
            peekedCardIndex = nil
        } // onChange (any move anywhere clears this pile's lingering peek)
        .onChange(of: game.newGameToken) { _, _ in
            // BUG FIX: this view's identity (tied to `pileIndex`, not to
            // any particular dealt cards) survives a New Game tap — only
            // `game.tableau` itself gets replaced. Left alone, a
            // `peekedCardIndex` set by peeking/cheat-grabbing a face-down
            // card in the OLD deal would keep pointing at that same index
            // in the brand-new pile dealt into this same column, silently
            // revealing whatever card now happens to sit there. Every
            // per-view bit of transient display state tied to the old
            // deal needs clearing here, not just the obvious one.
            peekedCardIndex = nil
            isFlashing = false
            flashedIndex = nil
        } // onChange (new game — clear all locally-held display state)
    } // body

    /// True if this card sits at or above the index of whatever's currently
    /// being drag-lifted FROM THIS pile — i.e. it's part of the floating
    /// run and should hide in place while `DragPreviewOverlay` shows it
    /// following the finger instead.
    private func isBeingDragged(index: Int) -> Bool {
        guard case .tableau(let dragPile, let dragIndex) = game.dragPreview?.source, dragPile == pileIndex else {
            return false
        } // guard the active drag originated in this pile
        return index >= dragIndex
    } // isBeingDragged(index:)

    /// A drag always grabs a definite thing — a legal run if this card
    /// starts one, otherwise a single-card cheat grab exactly like tapping a
    /// face-down or out-of-order card does — without the tap flow's
    /// separate "peek first, then a second tap to actually pick it up" step;
    /// one continuous drag gesture reads naturally as the grab itself.
    private func dragGesture(source: CardSource, index: Int, card: Card, isRunStart: Bool, pileCards: [Card]) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("board"))
            .onChanged { value in
                if game.dragPreview?.source != source {
                    guard game.beginDrag(source) else { return }
                    peekedCardIndex = nil // starting a drag supersedes any lingering peek state
                    let cards: [Card]
                    if isRunStart {
                        cards = Array(pileCards[index...])
                    } else {
                        var revealed = card
                        revealed.isFaceUp = true // show what was actually grabbed, same spirit as the tap peek cheat
                        cards = [revealed]
                    } // if/else
                    game.dragPreview = DragPreview(source: source, cards: cards, cardWidth: cardWidth, overlapOffset: overlapOffset, location: value.location)
                } // if this drag hasn't been registered with SolitaireGameState yet
                game.dragPreview?.location = value.location
            } // onChanged
            .onEnded { value in
                guard game.dragPreview?.source == source else { return } // a stray end with no matching begin — nothing to resolve
                game.endDrag(at: value.location)
            } // onEnded
    } // dragGesture(source:index:card:isRunStart:pileCards:)

    /// Shows the real face if the card is naturally face up OR currently being peeked.
    private func displayCard(_ card: Card, at index: Int) -> Card {
        guard !card.isFaceUp, peekedCardIndex == index else { return card }
        var revealed = card
        revealed.isFaceUp = true
        return revealed
    } // displayCard(_:at:)

    /// True if this card is at or above the selected run's starting index in
    /// THIS pile — i.e. it's one of the cards that would move together.
    private func isPartOfSelection(index: Int) -> Bool {
        guard case .tableau(let selPile, let selIndex) = game.selectedSource, selPile == pileIndex else {
            return false
        } // guard selection is in this pile
        return index >= selIndex
    } // isPartOfSelection(index:)

    private func handleSingleTap(at index: Int, card: Card, source: CardSource) {
        let isTopCard = index == game.tableau[pileIndex].cards.count - 1
        let isLegalRunStart = card.isFaceUp && (isTopCard || game.isValidRunStart(pile: pileIndex, index: index))

        if isLegalRunStart {
            if let selected = game.selectedSource, selected != source {
                if game.moveSelectedCard(toTableau: pileIndex) {
                    return
                } // if move succeeded
                // Invalid move — fall through and select this run instead.
            } // if let selected
            game.selectOrDeselect(source)
            return
        } // if isLegalRunStart

        // Hidden cheat path: a face-up card that breaks the ordering rule
        // bypasses normal play entirely via a plain tap. A face-down card
        // does NOT respond to a plain tap at all anymore — see
        // `handleLongPress` below — except for the second tap that
        // confirms a selection once it's already been peeked.
        if peekedCardIndex == index {
            game.selectOrDeselect(source) // second tap while peeking = select it
            peekedCardIndex = nil
        } else if !card.isFaceUp {
            return // require a 2-second hold instead of a casual tap — see handleLongPress
        } else {
            game.selectOrDeselect(source) // already visible — just select it directly
        } // if/else peeking
    } // handleSingleTap(at:card:source:)

    /// Hidden cheat: a 2-second hold on a face-down card peeks/grabs it,
    /// bypassing the normal ordering rule. Deliberately gated behind a long
    /// press (rather than the plain tap this used to respond to) so it
    /// can't be triggered by an accidental tap on the tableau.
    private func handleLongPress(at index: Int, card: Card) {
        guard !card.isFaceUp else { return } // only face-down cards use this path
        guard game.cheatPeekTableauCard(pile: pileIndex, cardIndex: index) != nil else { return } // nil = cheating is turned off
        peekedCardIndex = index
    } // handleLongPress(at:card:)
} // TableauColumnView
