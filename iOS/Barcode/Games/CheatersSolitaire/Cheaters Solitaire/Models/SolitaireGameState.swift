//
//  Models/SolitaireGameState.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Central ObservableObject driving all game logic: dealing, moves, cheat detection, consequence rolling, and derived status flags like isStuck/hasWon.
//

import Foundation
import Combine
import SwiftUI // for CGRect/CGPoint (drag-and-drop drop-zone math) and withAnimation (endDrag's cross-fade)

/// Drives the intro choreography: deck on table -> picked up -> shuffled -> dealt -> playing.
enum SolitaireGamePhase: Equatable {
    case deckOnTable
    case deckInHand      // picked up, sitting in dealer's off/resting hand, not yet shuffled
    case shuffling
    case dealing
    case playing
}

/// One of the seven tableau columns. Last element in `cards` = top of pile.
struct TableauPile: Identifiable {
    let id = UUID()
    var cards: [Card] = []
}

/// Identifies where a selected card currently lives, for the tap-to-select,
/// tap-to-move interaction model used throughout the UI.
enum CardSource: Equatable {
    case waste(Int)
    case tableau(pile: Int, index: Int)
    case foundation(Suit)
}

/// Identifies exactly one card slot for the face-down-flip cheat consequence
/// to report back to the view layer — see `SolitaireGameState.lastFlippedCard`.
struct FlippedCardLocation: Equatable {
    let pile: Int
    let index: Int
}

/// One undo checkpoint: the entire board exactly as it was immediately
/// before a move happened. `TableauPile`'s `id` is preserved across the
/// copy (struct assignment, not re-initialization), so restoring one
/// doesn't scramble SwiftUI's view identity for piles that didn't change.
private struct GameSnapshot {
    let stock: [Card]
    let waste: [Card]
    let tableau: [TableauPile]
    let foundations: [Suit: [Card]]
}

final class SolitaireGameState: ObservableObject {

    // MARK: Published game data

    @Published var phase: SolitaireGamePhase = .deckOnTable
    @Published var appearance: DealerAppearance = .rollNew()

    @Published var stock: [Card] = []
    @Published var waste: [Card] = []
    @Published var tableau: [TableauPile] = (0..<7).map { _ in TableauPile() }
    @Published var foundations: [Suit: [Card]] = [
        .hearts: [], .diamonds: [], .clubs: [], .spades: []
    ]

    /// Set briefly whenever a cheat consequence fires; the view layer observes
    /// this to trigger the matching animation/sound, then calls `clearConsequence()`.
    @Published var activeConsequence: CheatConsequence? = nil

    /// The currently tap-selected card, if any. Views read this to draw a
    /// selection highlight and to decide what a subsequent tap should do.
    @Published var selectedSource: CardSource? = nil

    /// Set alongside `activeConsequence` when a faceDownFlip fires, so the
    /// view layer knows exactly which card to flash — pile AND index, since
    /// the flip itself no longer always lands on a pile's exposed top card
    /// (see `flipAnExposedTopCardFaceDown`/`flipRandomExposedTableauTopCard`).
    /// Not part of the consequence enum itself since CheatEngine has no
    /// concept of piles.
    @Published var lastFlippedCard: FlippedCardLocation? = nil

    /// Live frames (in the shared "board" named coordinate space) of every
    /// tableau column and foundation slot, kept up to date by each pile view
    /// via `.onGeometryChange`. Read once, on drag release, to figure out
    /// which pile the finger let go over — see `endDrag(at:)`. Deliberately
    /// NOT `@Published`: nothing renders from this directly, and every pile
    /// view writes into it on nearly every scroll/zoom frame, so publishing
    /// it would trigger a full view refresh far more often than needed.
    var dropZoneFrames: [DropZoneID: CGRect] = [:]

    /// Live frame (in the "board" named coordinate space) of the waste fan,
    /// kept up to date by `WasteView` via `.onGeometryChange`, same idea as
    /// `dropZoneFrames` above but tracked separately since the waste pile is
    /// a drag SOURCE only — it's never a `DropZoneID` drop target. Used
    /// purely to know where an auto-complete flight animation should launch
    /// from when the card being placed came off the waste. Not `@Published`
    /// for the same reason as `dropZoneFrames`.
    var wasteFrame: CGRect? = nil

    /// Non-nil while the win-triggered auto-complete animation is flying a
    /// single card from its source pile to its foundation. Drives the
    /// floating `AutoCompleteFlightOverlay`. See `triggerAutoCompleteIfNeeded()`.
    @Published var autoCompleteFlight: AutoCompleteFlight? = nil

    /// True for the entire duration of the win-triggered auto-complete
    /// animation (see `triggerAutoCompleteIfNeeded()`), from the moment the
    /// tableau is first found fully exposed until the very last card lands.
    /// The view layer disables board interaction while this is true — with
    /// cards actively flying to their foundations one at a time, there's no
    /// legitimate move left to make anyway, and it avoids a tap or drag
    /// racing against the animation and mutating a pile out from under it.
    @Published private(set) var isAutoCompleting: Bool = false

    /// Non-nil while a drag-to-move gesture is in progress; drives the
    /// floating `DragPreviewOverlay` and tells the origin pile view to hide
    /// the real card(s) so they don't render twice. See `beginDrag(_:)` and
    /// `endDrag(at:)`.
    @Published var dragPreview: DragPreview? = nil

    /// True once no legal move remains anywhere — determined from the game's
    /// full knowledge of every card, including ones still buried in the
    /// stock/waste (see `hasAnyLegalMove()`), not just what's currently
    /// exposed. The view layer plays a soft foghorn cue on this transition.
    @Published private(set) var isStuck: Bool = false

    /// True once every card has legally reached its foundation (13 per suit) —
    /// the win condition. The view layer plays an applause cue on this transition.
    @Published private(set) var hasWon: Bool = false

    /// When the current game began — set once, at the top of `startNewGame()`.
    /// `GameTimerView` reads this to drive the live running clock.
    @Published private(set) var gameStartDate: Date? = nil

    /// Set the instant the game is over for ANY reason (won OR stuck), and
    /// cleared again if something — an undo, most likely — walks the board
    /// back out of being stuck. `GameTimerView` treats non-nil here as "freeze
    /// the clock"; `recalculateGameStatus()` is the only place that sets or
    /// clears it.
    @Published private(set) var gameEndDate: Date? = nil

    /// True the instant the player's first cheat of the current game is
    /// registered, and stays true for the rest of that game (reset back to
    /// false only by `startNewGame()`). Drives the timer's inverted-colors
    /// tell in `GameTimerView`, and whether a win gets logged as a cheated
    /// one.
    @Published private(set) var hasCheatedThisGame: Bool = false

    /// Increments once every time ANY cheat is registered — every single
    /// cheat move, not just the first. Unlike `hasCheatedThisGame` (which
    /// only ever flips once), this is meant to be observed via `onChange`
    /// to fire something on every cheat, e.g. the chicken sound in
    /// SolitaireContentView. Reset to 0 by `startNewGame()`.
    @Published private(set) var cheatEventCount: Int = 0

    /// True when the hidden "reverse red and black" cheat consequence is
    /// currently active — every red suit renders in the black pip color and
    /// every black suit renders in the red pip color (a purely visual
    /// swap; it does NOT change which suit a card actually is, so
    /// foundation/stacking rules are unaffected). Toggled — not just set —
    /// each time `cheatEventCount` lands on one of
    /// `colorReversalTriggerCounts` below, so repeated triggers keep
    /// flipping back and forth rather than latching on permanently. Reset
    /// to false by `startNewGame()`.
    @Published private(set) var colorsReversed: Bool = false

    /// The specific cumulative cheat counts (2nd cheat, 3rd, 5th, 7th,
    /// 11th, 13th, 17th, 19th ever committed in the current game) that
    /// toggle `colorsReversed`. Deliberately deterministic — unlike the
    /// probabilistic `CheatEngine` consequences (critter/frog, suit swap,
    /// face-down flip) — so it's checked directly against `cheatEventCount`
    /// in `registerCheatAndCheckConsequence` rather than going through
    /// `CheatEngine.rollForConsequence()`.
    private static let colorReversalTriggerCounts: Set<Int> = [2, 3, 5, 7, 11, 13, 17, 19]

    /// Increments on every single `startNewGame()` call, with no other
    /// purpose than giving views something unambiguous to `onChange` on to
    /// know a fresh deal just happened — unlike most of GameState's other
    /// @Published properties, which can easily start and end a new-game
    /// reset at the SAME value (e.g. `phase` goes `.playing` -> ... ->
    /// `.playing` again within one synchronous call, so `onChange(of:
    /// game.phase)` may never actually fire across a New Game tap).
    /// TableauColumnView uses this to clear its own local peeked-card
    /// state — see the comment there for why that view-level state doesn't
    /// otherwise get cleared just because the underlying game data reset.
    @Published private(set) var newGameToken: Int = 0

    let cheatEngine = CheatEngine()
    let resultsStore = GameResultsStore()

    /// Checkpoints for Undo — see `pushUndoSnapshot()` and `undo()`.
    private var undoStack: [GameSnapshot] = []
    private let maxUndoDepth = 50 // one game won't realistically exceed this; keeps memory bounded

    /// View-friendly mirror of `!undoStack.isEmpty`, so the Undo button can
    /// disable itself without the view needing to reach into private state.
    @Published private(set) var canUndo: Bool = false

    // MARK: - New game / intro choreography

    func startNewGame() {
        appearance = .rollNew()
        var deck = Deck()
        deck.shuffle()
        stock = deck.cards
        waste = []
        tableau = (0..<7).map { _ in TableauPile() }
        foundations = [.hearts: [], .diamonds: [], .clubs: [], .spades: []]
        cheatEngine.resetAfterConsequence()
        activeConsequence = nil
        selectedSource = nil
        lastFlippedCard = nil
        isStuck = false
        hasWon = false
        hasCheatedThisGame = false
        cheatEventCount = 0
        colorsReversed = false
        gameStartDate = Date()
        gameEndDate = nil
        undoStack = []
        canUndo = false
        moveToken = 0
        isAutoCompleting = false
        autoCompleteFlight = nil
        phase = .deckOnTable
        newGameToken += 1

        // Setup now runs automatically — pickup, shuffle, and deal all happen
        // immediately rather than waiting for the old manual tap choreography.
        // (That multi-step tap sequence was designed around the hand
        // animations, which are hidden for now — see DealerHandOverlayView.)
        pickUpDeck()
        shuffleDeck() // the view layer plays the shuffle sound right after calling this
        dealTableau()
    } // startNewGame()

    /// Tap the deck on the table: right hand (or left, if left-handed dealer)
    /// picks it up and it ends up resting in the dealer's off hand.
    func pickUpDeck() {
        guard phase == .deckOnTable else { return }
        phase = .deckInHand
    }

    /// Shuffles the stock. Only ever called automatically once, during
    /// `startNewGame()`'s setup chain — not reachable via any tap once play
    /// has actually started (see DeckView: double-tap during play routes to
    /// `cheatQuietReshuffleStock()` instead, which IS a cheat).
    func shuffleDeck() {
        guard phase == .deckInHand else { return }
        phase = .shuffling
        var deck = Deck(cards: stock)
        deck.shuffle()
        stock = deck.cards
        // View layer: SoundManager.shared.playShuffle(volume: CheatSettings.shared.normalShuffleVolume)
    }

    /// Single tap the deck in-hand after shuffling: deal the standard Klondike
    /// tableau (piles of 1...7 cards, only the top card of each pile face up).
    func dealTableau() {
        guard phase == .shuffling || phase == .deckInHand else { return }
        phase = .dealing

        var remaining = stock
        var piles: [TableauPile] = []
        for pileIndex in 0..<7 {
            var pile = TableauPile()
            for cardSlot in 0...pileIndex {
                guard !remaining.isEmpty else { break }
                var card = remaining.removeLast()
                card.isFaceUp = (cardSlot == pileIndex)
                pile.cards.append(card)
            }
            piles.append(pile)
        }
        tableau = piles
        stock = remaining
        phase = .playing
    }

    /// Rebuilds a stock array from the current waste pile such that drawing
    /// three at a time reproduces the SAME sequence of groups, in the SAME
    /// internal order, every time the stock is recycled — not just the same
    /// group each round trip. A naive "flip the whole packet over"
    /// (`waste.reversed()`) gets the group-to-group order right but reverses
    /// the 3 cards WITHIN each group on every other recycle, which is what
    /// was visible to the player as the draw suddenly showing cards in the
    /// opposite order. Re-chunking the waste from the front into its
    /// original draw-sized groups (of up to 3) and reassembling those groups
    /// back-to-front avoids that: the resulting stock's suffixes replay the
    /// exact same groups, in the exact same internal order, indefinitely.
    private func recycledStock(from waste: [Card]) -> [Card] {
        var groups: [[Card]] = []
        var index = 0
        while index < waste.count {
            let end = min(index + 3, waste.count)
            groups.append(Array(waste[index..<end]))
            index = end
        } // while (re-chunk into the original draw-sized groups, front to back)

        var rebuilt: [Card] = []
        rebuilt.reserveCapacity(waste.count)
        for group in groups.reversed() {
            rebuilt.append(contentsOf: group) // group's own internal order stays untouched
        } // for group (groups back-to-front, so the first-drawn group is dealt again first)

        return rebuilt.map { card -> Card in
            var c = card
            c.isFaceUp = false
            return c
        } // map (face down, ready to be stock again)
    } // recycledStock(from:)

    /// Tap the deck (once dealt) during play to draw three for gameplay.
    func drawThree() {
        guard phase == .playing else { return }
        if stock.isEmpty {
            guard !waste.isEmpty else { return }
            pushUndoSnapshot()
            stock = recycledStock(from: waste)
            waste = []
            recalculateGameStatus()
            return
        }
        let n = min(3, stock.count)
        let drawn = stock.suffix(n).map { card -> Card in
            var c = card
            c.isFaceUp = true
            return c
        }
        pushUndoSnapshot()
        stock.removeLast(n)
        waste.append(contentsOf: drawn)
        recalculateGameStatus()
    } // drawThree()

    // MARK: - Tap-to-select, tap-to-move
    // One selection model handles BOTH normal play and the hidden cheats.
    // Selecting the true top card of the waste, or the top face-up card of a
    // tableau pile, is normal play. Selecting anything else (a buried waste
    // card, a face-down or non-top tableau card) is a hidden cheat and
    // quietly counts toward the consequence system — no UI difference either way.

    /// Looks up the actual card at a given source, if it still exists there.
    func card(at source: CardSource) -> Card? {
        switch source {
        case .waste(let idx):
            return waste.indices.contains(idx) ? waste[idx] : nil
        case .tableau(let pile, let idx):
            guard tableau.indices.contains(pile), tableau[pile].cards.indices.contains(idx) else { return nil }
            return tableau[pile].cards[idx]
        case .foundation(let suit):
            return foundations[suit]?.last
        } // switch source
    } // card(at:)

    /// True if the cards from `index` to the top of this pile form a legal,
    /// fully face-up, alternating-color descending run — i.e. a sequence
    /// that's normally movable together in Klondike (not just the top card).
    func isValidRunStart(pile: Int, index: Int) -> Bool {
        guard tableau.indices.contains(pile), tableau[pile].cards.indices.contains(index) else {
            #if DEBUG
            print("isValidRunStart: pile \(pile) or index \(index) out of range")
            #endif
            return false
        } // guard valid indices
        let cards = tableau[pile].cards
        guard cards[index].isFaceUp else {
            #if DEBUG
            print("isValidRunStart: pile \(pile) index \(index) (\(cards[index].rank.label) of \(cards[index].suit.rawValue)) is face-down")
            #endif
            return false
        } // guard face up
        guard index < cards.count - 1 else { return true } // already the top card — trivially a run of one
        for i in index..<(cards.count - 1) {
            let lower = cards[i]
            let upper = cards[i + 1]
            guard lower.isFaceUp, upper.isFaceUp, upper.canStack(on: lower) else {
                #if DEBUG
                print("isValidRunStart: pile \(pile) broke at i=\(i) — lower: \(lower.rank.label) of \(lower.suit.rawValue) (faceUp=\(lower.isFaceUp)), upper: \(upper.rank.label) of \(upper.suit.rawValue) (faceUp=\(upper.isFaceUp)), canStack=\(upper.canStack(on: lower))")
                #endif
                return false
            } // guard each adjacent pair stacks legally
        } // for i
        return true
    } // isValidRunStart(pile:index:)

    /// True if selecting this source bypasses the normal "only the top card,
    /// or a legally-ordered run, is playable" rule — i.e. it's a hidden cheat.
    private func isCheatSource(_ source: CardSource) -> Bool {
        switch source {
        case .waste(let idx):
            return idx != waste.count - 1
        case .tableau(let pile, let idx):
            guard tableau.indices.contains(pile), tableau[pile].cards.indices.contains(idx) else { return false }
            guard tableau[pile].cards[idx].isFaceUp else { return true } // face-down => the peek/grab cheat
            return !isValidRunStart(pile: pile, index: idx) // face-up but breaks the run => still a cheat
        case .foundation:
            return false // moving a card back to the tableau is standard, legal Klondike play
        } // switch source
    } // isCheatSource(_:)

    /// Human-readable description of a source, for DEBUG-only cheat logging.
    private func describe(_ source: CardSource) -> String {
        let cardDesc = card(at: source).map { "\($0.rank.label) of \($0.suit.rawValue)" } ?? "unknown card"
        switch source {
        case .waste(let idx):
            return "waste index \(idx) (\(cardDesc))"
        case .tableau(let pile, let idx):
            return "pile \(pile) index \(idx) (\(cardDesc))"
        case .foundation(let suit):
            return "\(suit.rawValue) foundation (\(cardDesc))"
        } // switch source
    } // describe(_:)

    /// Tap a card: selects it (highlighting it in the UI), or deselects it if
    /// it was already selected. No longer registers a cheat here — merely
    /// selecting (or drag-picking-up, or tapping-then-deselecting) a
    /// not-normally-selectable card is never itself the cheat; only an
    /// actual completed placement is. See `moveSelectedCard(toTableau:)` /
    /// `moveSelectedCard(toFoundation:)`, which register the cheat at the
    /// point the move actually lands.
    func selectOrDeselect(_ source: CardSource) {
        guard card(at: source) != nil else { return }
        if isCheatSource(source), !cheatingEnabled {
            #if DEBUG
            print("CHEAT BLOCKED: \(describe(source)) is not normally selectable, and cheating is turned off.")
            #endif
            return
        } // guard — cheating disabled, so a not-normally-selectable source is simply ignored
        if selectedSource == source {
            selectedSource = nil
            return
        } // if already selected
        selectedSource = source
    } // selectOrDeselect(_:)

    /// Picks up a card (or, for a tableau run start, the whole run) at the
    /// start of a drag gesture. Deliberately unconditional, unlike
    /// `selectOrDeselect` — a drag always means "grab this," never "toggle
    /// off whatever I already had selected." Runs the exact same
    /// cheat-detection GATE as tap-to-select does (still blocking the pickup
    /// entirely when cheating is disabled), but — same as `selectOrDeselect`
    /// above — no longer registers the cheat itself here: a drag that gets
    /// picked up and then cancelled or dropped back where it came from
    /// (a `endDrag(at:)` miss, or landing back on its own pile) never
    /// actually moved the card anywhere, so it shouldn't count. The cheat is
    /// registered only once a move genuinely lands — see
    /// `moveSelectedCard(toTableau:)` / `moveSelectedCard(toFoundation:)`.
    @discardableResult
    func beginDrag(_ source: CardSource) -> Bool {
        guard card(at: source) != nil else { return false }
        if isCheatSource(source), !cheatingEnabled {
            #if DEBUG
            print("CHEAT BLOCKED: dragging \(describe(source)) is not normally allowed, and cheating is turned off.")
            #endif
            return false
        } // guard — cheating disabled, so a not-normally-draggable source can't be picked up
        selectedSource = source
        return true
    } // beginDrag(_:)

    /// Resolves a drag release: finds whichever drop zone the release point
    /// falls within (if any) and attempts the same move a tap-to-destination
    /// would make. Clears the selection on any outcome other than a
    /// successful move — a drag that misses every pile, or lands somewhere
    /// illegal, cancels back to nothing selected rather than leaving the
    /// card in a half-selected state the player didn't ask for. The floating
    /// preview is cleared inside a brief `withAnimation` either way, so the
    /// hand-off back to the real card (a successful move's new home, or the
    /// original spot on a cancelled drag) cross-fades instead of cutting.
    func endDrag(at point: CGPoint) {
        guard let zone = dropZoneFrames.first(where: { $0.value.contains(point) })?.key else {
            selectedSource = nil
            withAnimation(.easeOut(duration: 0.15)) { dragPreview = nil }
            return
        } // guard the release point landed inside some pile's frame
        let moved: Bool
        switch zone {
        case .tableau(let pile):
            moved = moveSelectedCard(toTableau: pile)
        case .foundation(let suit):
            moved = moveSelectedCard(toFoundation: suit)
        } // switch zone
        if !moved {
            selectedSource = nil
        } // if the move was rejected, cancel the selection too
        withAnimation(.easeOut(duration: 0.15)) { dragPreview = nil }
    } // endDrag(at:)

    /// Tap a tableau pile as a destination for the currently selected card
    /// (or, if the selection is a tableau run, the ENTIRE run moves together).
    @discardableResult
    func moveSelectedCard(toTableau destPile: Int) -> Bool {
        guard let source = selectedSource else { return false }

        switch source {
        case .waste:
            guard let card = card(at: source) else { return false }
            if canPlace(card, onTableauPile: destPile) {
                // Only reaches here as a cheat if `card` was a buried (non-top)
                // waste card that HAPPENS to also fit normally — flagCheatIfNeeded
                // is a no-op for the ordinary top-of-waste case.
                flagCheatIfNeeded(source)
                pushUndoSnapshot()
                removeCard(at: source)
                var placed = card
                placed.isFaceUp = true
                tableau[destPile].cards.append(placed)
                selectedSource = nil
                recalculateGameStatus()
                return true
            } else if canInsertBehindTableauTop(card, ontoTableau: destPile) {
                // Selecting a buried waste card is its own cheat, separate
                // from the insert-behind trick below — register both, same
                // as the buried-tableau-card path further down.
                flagCheatIfNeeded(source)
                pushUndoSnapshot()
                removeCard(at: source)
                insertRunBehindTableauTop([card], ontoTableau: destPile)
                selectedSource = nil
                #if DEBUG
                let destTop = tableau[destPile].cards.last.map { "\($0.rank.label) of \($0.suit.rawValue)" } ?? "?"
                print("CHEAT: inserted \(card.rank.label) of \(card.suit.rawValue) from the waste behind pile \(destPile)'s exposed \(destTop).")
                #endif
                registerCheatAndCheckConsequence()
                return true
            } else {
                return false
            } // if/else/else (normal placement, insert-behind cheat, or reject)

        case .tableau(let srcPile, let idx):
            guard srcPile != destPile else {
                selectedSource = nil // tapped the pile it's already in — treat as deselect
                return false
            } // guard different pile
            guard tableau.indices.contains(srcPile), tableau[srcPile].cards.indices.contains(idx) else { return false }

            if isValidRunStart(pile: srcPile, index: idx) {
                let run = Array(tableau[srcPile].cards[idx...])
                if let anchor = run.first, !canPlace(anchor, onTableauPile: destPile),
                   canInsertBehindTableauTop(anchor, ontoTableau: destPile) {
                    // Hidden cheat: same "insert behind" trick as the waste
                    // case above, now extended to a genuine multi-card run —
                    // not just a lone top card. Only the run's bottommost
                    // card (`anchor`) needs to satisfy the stacking check
                    // against the destination's exposed top; the rest of the
                    // run is already known to be a legal sequence on its own,
                    // and `insertRunBehindTableauTop` slots the whole thing
                    // in together, preserving its internal order.
                    pushUndoSnapshot()
                    tableau[srcPile].cards.removeSubrange(idx...)
                    invalidateSelectionIfStale(afterRemovingFromTableau: srcPile, at: idx)
                    autoRevealTopCard(ofPile: srcPile)
                    insertRunBehindTableauTop(run, ontoTableau: destPile)
                    selectedSource = nil
                    #if DEBUG
                    let destTop = tableau[destPile].cards.last.map { "\($0.rank.label) of \($0.suit.rawValue)" } ?? "?"
                    print("CHEAT: inserted \(run.count)-card run starting with \(anchor.rank.label) of \(anchor.suit.rawValue) from pile \(srcPile) behind pile \(destPile)'s exposed \(destTop).")
                    #endif
                    registerCheatAndCheckConsequence()
                    return true
                } // if the run doesn't fit normally but slots in behind instead
                // Normal play: the whole run (one card, or a legal
                // face-up alternating-color sequence) moves together.
                guard let anchor = run.first, canPlace(anchor, onTableauPile: destPile) else { return false }
                pushUndoSnapshot()
                tableau[srcPile].cards.removeSubrange(idx...)
                invalidateSelectionIfStale(afterRemovingFromTableau: srcPile, at: idx)
                tableau[destPile].cards.append(contentsOf: run) // whole run moves together, order preserved
                autoRevealTopCard(ofPile: srcPile)
                selectedSource = nil
                recalculateGameStatus()
                return true
            } else {
                // Cheat: `idx` is either a face-down peeked card (possibly
                // buried under other cards) or a face-up card that breaks
                // the ordering rule. Either way, ONLY this single card
                // moves — anything physically stacked on top of it in the
                // source pile is left completely alone and simply shifts
                // down by one to fill the gap left behind. It never comes
                // along for the ride, and the pile above it never gets
                // reordered or exposed early.
                let wasTop = idx == tableau[srcPile].cards.count - 1 // computed BEFORE removal — see the autoRevealTopCard calls below
                var single = tableau[srcPile].cards[idx]
                single.isFaceUp = true // reveal it face up either way — used by both branches below
                if canPlace(single, onTableauPile: destPile) {
                    // Reaching this `else` branch at all means `idx` broke
                    // the run/face-up rule, so this placement — now that it's
                    // actually landing somewhere — is the cheat being
                    // registered, not merely the earlier selection/pickup.
                    registerCheatAndCheckConsequence()
                    pushUndoSnapshot()
                    tableau[srcPile].cards.remove(at: idx)
                    invalidateSelectionIfStale(afterRemovingFromTableau: srcPile, at: idx)
                    // Only reveal a new top if we actually removed the OLD
                    // top (e.g. cheat-extracting a top card the face-down-
                    // flip consequence had deliberately hidden) — see the
                    // matching comment in moveSelectedCard(toFoundation:).
                    // Extracting a buried card leaves the real top (and its
                    // face-up/down state) completely untouched; calling this
                    // unconditionally would risk un-hiding a deliberately
                    // hidden top purely because something below it moved.
                    if wasTop { autoRevealTopCard(ofPile: srcPile) }
                    tableau[destPile].cards.append(single)
                    selectedSource = nil
                    recalculateGameStatus()
                    return true
                } else if canInsertBehindTableauTop(single, ontoTableau: destPile) {
                    registerCheatAndCheckConsequence() // cheat #1: the buried/out-of-order card, now actually placed
                    pushUndoSnapshot()
                    tableau[srcPile].cards.remove(at: idx)
                    invalidateSelectionIfStale(afterRemovingFromTableau: srcPile, at: idx)
                    if wasTop { autoRevealTopCard(ofPile: srcPile) } // see comment above
                    insertRunBehindTableauTop([single], ontoTableau: destPile)
                    selectedSource = nil
                    #if DEBUG
                    let destTop = tableau[destPile].cards.last.map { "\($0.rank.label) of \($0.suit.rawValue)" } ?? "?"
                    print("CHEAT: inserted \(single.rank.label) of \(single.suit.rawValue) from pile \(srcPile) behind pile \(destPile)'s exposed \(destTop).")
                    #endif
                    registerCheatAndCheckConsequence() // cheat #2, separate: the insert-behind trick itself
                    return true
                } else {
                    return false
                } // if/else/else (normal placement, insert-behind cheat, or reject)
            } // if/else isValidRunStart

        case .foundation:
            guard let card = card(at: source), canPlace(card, onTableauPile: destPile) else { return false }
            pushUndoSnapshot()
            removeCard(at: source)
            tableau[destPile].cards.append(card) // already face up on the foundation
            selectedSource = nil
            recalculateGameStatus()
            return true
        } // switch source
    } // moveSelectedCard(toTableau:)

    /// True if `card` (the bottommost/anchor card of a single card OR a
    /// whole multi-card run) can be quietly slipped in directly BEHIND (i.e.
    /// beneath) `pile`'s current top card, instead of on top of it — the
    /// hidden "insert behind" cheat: take any exposed face-up card or run
    /// (from the waste, or a normal/cheat-exposed tableau card/run) that
    /// doesn't legally fit anywhere as a new top, and forge it into a
    /// "missing link" just under an already-exposed tableau card instead.
    /// It's the REVERSE of normal placement — the pile's EXISTING top card
    /// must be able to legally stack ON `card` (one rank higher, opposite
    /// color), not the other way around. Requires a non-empty pile with a
    /// face-up top — nothing to insert behind on an empty column, and
    /// forging a link under a face-down top wouldn't make visual sense. Only
    /// `card`/the run's anchor needs to satisfy this — how many cards are
    /// already stacked face-up on top of that exposed pile card makes no
    /// difference, since `card` only ever needs to slot in immediately
    /// behind whatever the pile's actual top card currently is.
    private func canInsertBehindTableauTop(_ card: Card, ontoTableau pile: Int) -> Bool {
        guard tableau.indices.contains(pile),
              let top = tableau[pile].cards.last, top.isFaceUp else { return false }
        return top.canStack(on: card)
    } // canInsertBehindTableauTop(_:ontoTableau:)

    /// Performs the actual insertion for `canInsertBehindTableauTop` above —
    /// for a single card OR a whole multi-card run, slotted in together with
    /// its internal order preserved. The pile's current top card stays
    /// exactly where it is — still the last element, still the exposed/
    /// playable card — `run` just slots in as a block one position before
    /// it, each card becoming face up in its new home like any other cheat
    /// grab.
    private func insertRunBehindTableauTop(_ run: [Card], ontoTableau pile: Int) {
        let faceUpRun = run.map { card -> Card in
            var c = card
            c.isFaceUp = true
            return c
        } // map (every inserted card becomes face up, same as a lone cheat grab)
        let insertIndex = tableau[pile].cards.count - 1 // just before the current top — canInsertBehindTableauTop already guaranteed this pile is non-empty
        tableau[pile].cards.insert(contentsOf: faceUpRun, at: insertIndex)
    } // insertRunBehindTableauTop(_:ontoTableau:)



    /// Tap a foundation suit slot. Only a SINGLE card can go to a foundation —
    /// if the current selection is a multi-card run, this correctly refuses.
    @discardableResult
    func moveSelectedCard(toFoundation suit: Suit) -> Bool {
        guard let source = selectedSource else { return false }

        switch source {
        case .waste:
            guard let card = card(at: source), card.suit == suit,
                  card.canPlaceOnFoundation(topCard: foundations[suit]?.last) else { return false }
            // Only a cheat, and only actually registered now, if `card` was
            // a buried (non-top) waste card that happens to also be
            // foundation-eligible — flagCheatIfNeeded is a no-op otherwise.
            flagCheatIfNeeded(source)
            pushUndoSnapshot()
            removeCard(at: source)
            var placed = card
            placed.isFaceUp = true
            foundations[suit, default: []].append(placed)
            selectedSource = nil
            recalculateGameStatus()
            return true

        case .tableau(let pile, let idx):
            guard tableau.indices.contains(pile), tableau[pile].cards.indices.contains(idx) else { return false }
            let isTop = idx == tableau[pile].cards.count - 1
            // A legal, in-order run can only ever send its OWN top card to a
            // foundation — one card at a time, same as normal play. The one
            // exception is a cheat source (face-down, or breaking the
            // ordering rule): exactly like the tableau-destination path
            // above, that single card can be extracted straight out of the
            // middle of the pile, leaving everything stacked on top of it
            // completely undisturbed.
            guard isTop || !isValidRunStart(pile: pile, index: idx) else { return false } // reject a legal multi-card run's non-top card
            var card = tableau[pile].cards[idx]
            guard card.suit == suit, card.canPlaceOnFoundation(topCard: foundations[suit]?.last) else { return false }
            // Same idea as the waste case: only registers if `source` is
            // actually a cheat source (face-down or out-of-order), and only
            // now that the placement is genuinely landing.
            flagCheatIfNeeded(source)
            pushUndoSnapshot()
            tableau[pile].cards.remove(at: idx)
            invalidateSelectionIfStale(afterRemovingFromTableau: pile, at: idx)
            if isTop {
                // The normal case: this WAS the pile's actual top card, so
                // whatever was sitting beneath it (if anything) is now
                // newly exposed and may need flipping face up — same as
                // any other top-card removal.
                autoRevealTopCard(ofPile: pile)
            } // else: `idx` was buried mid-pile (a cheat extraction) — pulling
              // from the middle never changes what's already on top, so
              // there's nothing new to reveal. Calling autoRevealTopCard
              // here anyway would risk un-hiding a pile's top card that was
              // deliberately turned face-down by the face-down-flip cheat
              // consequence, which is why this stays conditional on isTop
              // rather than calling it unconditionally.
            card.isFaceUp = true
            foundations[suit, default: []].append(card)
            selectedSource = nil
            recalculateGameStatus()
            return true
        case .foundation:
            return false // a card already on a foundation has nowhere meaningful to go via this path
        } // switch source
    } // moveSelectedCard(toFoundation:)

    /// Double-tap convenience: sends this card — or, for a tableau source,
    /// the full run starting there — straight to its matching foundation if
    /// eligible, or to a tableau column if there's EXACTLY ONE legal
    /// destination for it. With 2+ valid tableau destinations, it's ambiguous
    /// which one you meant, so that part stays hands-off and leaves it to the
    /// normal tap-to-select, tap-to-move flow. This naturally covers a King
    /// (alone or with a valid run stacked on it) moving to a sole empty
    /// column, not just a lone top King — the same single-destination rule
    /// handles both.
    ///
    /// Foundation eligibility is checked FIRST and takes priority: a lone
    /// top card that could legally go to its foundation goes there, even if
    /// it could also continue building a tableau run elsewhere. The
    /// foundation is always the more "final," lower-risk destination, so
    /// double-tap defaults to it whenever it's on the table — the tableau
    /// fallback only kicks in once the foundation genuinely isn't an option.
    @discardableResult
    func autoMoveOnDoubleTap(_ source: CardSource) -> Bool {
        guard let card = card(at: source) else { return false }

        let isTopOfPile: Bool
        if case .tableau(let pile, let idx) = source {
            isTopOfPile = idx == tableau[pile].cards.count - 1
        } else {
            isTopOfPile = true
        } // if/else

        // A run (or single card) can move to a tableau column — needed only
        // as the fallback below, once foundation eligibility (checked first)
        // has already been ruled out.
        let isRunStart: Bool
        switch source {
        case .tableau(let pile, let idx):
            isRunStart = isValidRunStart(pile: pile, index: idx)
        case .waste, .foundation:
            isRunStart = true // always a "run of one"
        } // switch source

        // Foundation: only ever a single top card, never a mid-pile run.
        // Checked FIRST and wins whenever it's legal — see the doc comment
        // above for why the foundation gets priority over the tableau.
        if isTopOfPile, card.canPlaceOnFoundation(topCard: foundations[card.suit]?.last) {
            flagCheatIfNeeded(source)
            pushUndoSnapshot()
            removeCard(at: source)
            var placed = card
            placed.isFaceUp = true
            foundations[card.suit, default: []].append(placed)
            if selectedSource == source {
                selectedSource = nil
            } // if this card was selected, clear it
            recalculateGameStatus()
            return true
        } // if foundation-eligible

        guard isRunStart else { return false }
        let tableauCandidates: [Int] = tableau.indices.filter { destPile in
            if case .tableau(let srcPile, _) = source, srcPile == destPile {
                return false
            } // exclude the pile it's already in
            return canPlace(card, onTableauPile: destPile)
        } // tableauCandidates — only computed now that the foundation wasn't an option
        guard tableauCandidates.count == 1, let destPile = tableauCandidates.first else { return false }

        flagCheatIfNeeded(source)
        pushUndoSnapshot()
        switch source {
        case .waste:
            removeCard(at: source)
            var placed = card
            placed.isFaceUp = true
            tableau[destPile].cards.append(placed)
        case .tableau(let pile, let idx):
            let run = Array(tableau[pile].cards[idx...])
            tableau[pile].cards.removeSubrange(idx...)
            invalidateSelectionIfStale(afterRemovingFromTableau: pile, at: idx)
            autoRevealTopCard(ofPile: pile)
            tableau[destPile].cards.append(contentsOf: run)
        case .foundation:
            removeCard(at: source)
            tableau[destPile].cards.append(card) // already face up on the foundation
        } // switch source
        if selectedSource == source {
            selectedSource = nil
        } // if this card was selected, clear it
        recalculateGameStatus()
        return true
    } // autoMoveOnDoubleTap(_:)

    /// Shared cheat-flagging logic for the double-tap auto-move shortcuts.
    private func flagCheatIfNeeded(_ source: CardSource) {
        guard isCheatSource(source) else { return }
        #if DEBUG
        print("CHEAT: double-tap sent \(describe(source)) straight to its destination — not normally selectable there.")
        #endif
        registerCheatAndCheckConsequence()
    } // flagCheatIfNeeded(_:)

    /// Clears a stale selection if the card it points to just got swept up
    /// in a different removal (e.g. selecting card A, then double-tapping
    /// card B further down the SAME pile, which shifts A's index).
    private func invalidateSelectionIfStale(afterRemovingFromTableau pile: Int, at idx: Int) {
        guard case .tableau(let selPile, let selIndex) = selectedSource, selPile == pile, selIndex >= idx else {
            return
        } // guard stale
        selectedSource = nil
    } // invalidateSelectionIfStale(afterRemovingFromTableau:at:)

    private func canPlace(_ card: Card, onTableauPile pile: Int) -> Bool {
        guard tableau.indices.contains(pile) else { return false }
        if let top = tableau[pile].cards.last {
            return card.canStack(on: top)
        } else {
            return card.rank == .king
        } // if/else
    } // canPlace(_:onTableauPile:)

    /// Every card that a real player could EVER see as a waste top from
    /// here on, without any move actually being made: first by continuing
    /// to draw through the rest of the current stock, then — since a real
    /// recycle only becomes possible once the stock is fully drained —
    /// from ONE recycle of the FULL waste pile as it will exist AT that
    /// point (today's remaining waste, plus every group the current stock
    /// still has left to give up, in the same draw order `drawThree()`
    /// would produce). A second recycle after that would just repeat the
    /// same groups again, since nothing changes if no move happens — so
    /// checking the current stock's draw-out plus this one recycle is a
    /// complete answer, not an approximation.
    private func allReachableWasteTops() -> [Card] {
        var tops: [Card] = []

        var simulatedStock = stock // same convention as real stock: next-to-draw = .last
        var fullWasteOnceStockIsDrained = waste // what the waste pile grows into as stock empties
        while !simulatedStock.isEmpty {
            let n = min(3, simulatedStock.count)
            let group = simulatedStock.suffix(n)
            if let top = group.last {
                tops.append(top)
            } // if group non-empty
            fullWasteOnceStockIsDrained.append(contentsOf: group) // mirrors drawThree()'s real append
            simulatedStock.removeLast(n)
        } // while (rest of the current pass)

        var simulatedRecycle = recycledStock(from: fullWasteOnceStockIsDrained) // the recycle a real player would actually get
        while !simulatedRecycle.isEmpty {
            let n = min(3, simulatedRecycle.count)
            if let top = simulatedRecycle.suffix(n).last {
                tops.append(top)
            } // if group non-empty
            simulatedRecycle.removeLast(n)
        } // while (one full simulated recycle — a second would just repeat this)

        return tops
    } // allReachableWasteTops()

    /// True if a legal move exists ANYWHERE — based on the game's complete
    /// knowledge of every card, not just what's currently exposed. Checks
    /// every waste-top that drawing/recycling could EVER reveal (via
    /// `allReachableWasteTops()`), plus all tableau-internal moves. This is a
    /// definitive answer, not a heuristic — if this returns false, no amount
    /// of further drawing or recycling can help either.
    private func hasAnyLegalMove() -> Bool {
        for candidate in allReachableWasteTops() {
            if candidate.canPlaceOnFoundation(topCard: foundations[candidate.suit]?.last) {
                #if DEBUG
                print("hasAnyLegalMove: YES — reachable waste top \(candidate.rank.label) of \(candidate.suit.rawValue) -> foundation")
                #endif
                return true
            } // if candidate can go to foundation
            for pile in tableau.indices where canPlace(candidate, onTableauPile: pile) {
                #if DEBUG
                print("hasAnyLegalMove: YES — reachable waste top \(candidate.rank.label) of \(candidate.suit.rawValue) -> tableau pile \(pile)")
                #endif
                return true
            } // for pile (candidate to tableau)
        } // for candidate

        for pile in tableau.indices {
            let cards = tableau[pile].cards
            for index in cards.indices where cards[index].isFaceUp {
                let card = cards[index]
                if index == cards.count - 1, card.canPlaceOnFoundation(topCard: foundations[card.suit]?.last) {
                    #if DEBUG
                    print("hasAnyLegalMove: YES — pile \(pile) top \(card.rank.label) of \(card.suit.rawValue) -> foundation")
                    #endif
                    return true
                } // if top card can go to foundation
                if isValidRunStart(pile: pile, index: index) {
                    // Does moving this run away from `pile` accomplish
                    // anything real? Only if it reveals a hidden card
                    // underneath, or fully empties the pile. Otherwise it's
                    // just relocating an already-fully-visible run between
                    // two equally-valid resting spots — not real progress.
                    let revealsHiddenCard = index > 0 && !cards[index - 1].isFaceUp
                    let emptiesSourcePile = index == 0
                    guard revealsHiddenCard || emptiesSourcePile else {
                        continue // cosmetic shuffle — keep checking other cards/piles
                    } // guard genuine progress

                    for destPile in tableau.indices where destPile != pile && canPlace(card, onTableauPile: destPile) {
                        // Still exclude relocating an already-isolated run
                        // (the whole pile) into ANOTHER empty column — that's
                        // just trading one dead end for another.
                        if emptiesSourcePile && tableau[destPile].cards.isEmpty {
                            continue
                        } // if vacuous king-shuffle move
                        #if DEBUG
                        print("hasAnyLegalMove: YES — pile \(pile) index \(index) (\(card.rank.label) of \(card.suit.rawValue)) -> pile \(destPile)")
                        #endif
                        return true
                    } // for destPile
                } // if isValidRunStart
            } // for index
        } // for pile

        #if DEBUG
        let tableauDesc = tableau.map { pile -> String in
            guard let top = pile.cards.last else { return "empty" }
            let faceState = top.isFaceUp ? "up" : "DOWN"
            return "\(top.rank.label) of \(top.suit.rawValue) (\(faceState), \(pile.cards.count) cards)"
        }.joined(separator: " | ")
        print("hasAnyLegalMove: NO — Stock=\(stock.count) Waste=\(waste.count) TableauTops=[\(tableauDesc)]")
        #endif
        return false
    } // hasAnyLegalMove()

    /// True once a full pass through the stock has ended with no non-draw
    /// move available, AND no genuine progress has happened since. This is
    /// what actually proves further recycling is pointless: without any
    /// tableau/foundation change in between, a repeat pass through the exact
    /// same cards in the exact same order will show the exact same thing.
    /// Reaching this point once is normal and common — it's reaching it
    /// TWICE with nothing in between that means the game is truly stuck.
    /// Once every card in the tableau is face up, the rest of the game
    /// reduces to mechanical sorting — there's no strategic reason to make
    /// the player manually walk every remaining card home. Rather than
    /// snapping the whole board to its finished state in one instant frame,
    /// this animates it: one card flies to its foundation, a brief pause,
    /// then the next — "slowly" in the sense of watching it happen a card at
    /// a time, but each individual flight is a normal-speed animation, not
    /// slow motion.
    ///
    /// Kicked off from `recalculateGameStatus()` instead of running
    /// synchronously there, since the whole point is to spread this out
    /// over real time. `isAutoCompleting` guards against a second overlapping
    /// run starting while one is already in flight.
    private func triggerAutoCompleteIfNeeded() {
        guard !isAutoCompleting,
              foundations.values.reduce(0, { $0 + $1.count }) < Rank.allCases.count * Suit.allCases.count, // guard: nothing left to do once every foundation is already full
              !tableau.isEmpty, tableau.allSatisfy({ pile in pile.cards.allSatisfy { $0.isFaceUp } }) else {
            return
        } // guard tableau fully exposed, not already running, and there's still something to move
        isAutoCompleting = true
        let startedDuringGame = newGameToken // if a new game begins mid-flight, this animation must NOT keep operating on the fresh deal
        Task { @MainActor [weak self] in
            await self?.runAutoCompleteAnimation(startedDuringGame: startedDuringGame)
            guard let self, self.newGameToken == startedDuringGame else { return } // a new game started mid-animation — abandon quietly, startNewGame() already reset isAutoCompleting/autoCompleteFlight
            self.isAutoCompleting = false
            // Deliberately `updateDerivedStatus()`, NOT `recalculateGameStatus()`
            // — see that function's doc comment for why calling the full
            // version here was an infinite-loop bug. This still flips
            // `hasWon`, freezes the timer, and logs the win at the right
            // moment (when the last card visually lands), it just doesn't
            // re-arm `triggerAutoCompleteIfNeeded()` in the process.
            self.updateDerivedStatus()
        } // Task
    } // triggerAutoCompleteIfNeeded()

    /// The actual card-by-card sequence — see `triggerAutoCompleteIfNeeded()`
    /// above for why this is async instead of the single synchronous loop
    /// this replaced. Mirrors that old loop's logic exactly (try the waste
    /// top, then each tableau pile top, then draw or recycle if nothing was
    /// directly placeable) but performs exactly one placement per iteration,
    /// animated, with a short pause afterward — never touches
    /// `recalculateGameStatus()`/`hasWon` itself; the caller does that once
    /// at the very end.
    @MainActor
    private func runAutoCompleteAnimation(startedDuringGame: Int) async {
        let flightDuration = 0.22
        let pauseAfterLanding: UInt64 = 90_000_000 // 0.09s in nanoseconds

        var safetyLimit = 500 // generous guard against any unforeseen infinite loop
        while safetyLimit > 0 {
            safetyLimit -= 1
            guard newGameToken == startedDuringGame else { return } // a new game started mid-animation — bail immediately, don't touch the fresh deal

            if let (source, card) = nextAutoCompleteMove() {
                await flyCard(card, from: source, duration: flightDuration)
                try? await Task.sleep(nanoseconds: pauseAfterLanding)
                continue
            } // if a card was directly placeable this round

            // Nothing placeable right now — surface more cards the same way
            // the old synchronous version did, then loop again.
            if !stock.isEmpty {
                let n = min(3, stock.count)
                let drawn = stock.suffix(n).map { card -> Card in
                    var c = card
                    c.isFaceUp = true
                    return c
                } // map
                stock.removeLast(n)
                waste.append(contentsOf: drawn)
            } else if !waste.isEmpty {
                stock = recycledStock(from: waste)
                waste = []
            } else {
                break // truly nothing left to try
            } // if/else (draw more, or recycle, to keep trying)
        } // while

        #if DEBUG
        print("runAutoCompleteAnimation: finished — foundations now \(foundations.mapValues { $0.count })")
        #endif
    } // runAutoCompleteAnimation()

    /// Finds ONE card that could go straight to its foundation right now —
    /// waste top first, then each tableau pile's top, left to right — without
    /// mutating anything. Mirrors the priority order of the old synchronous
    /// `autoCompleteIfFullyExposed()` loop exactly.
    private func nextAutoCompleteMove() -> (CardSource, Card)? {
        if let wasteTop = waste.last, wasteTop.canPlaceOnFoundation(topCard: foundations[wasteTop.suit]?.last) {
            return (.waste(waste.count - 1), wasteTop)
        } // if the waste top can go straight home
        for pile in tableau.indices {
            guard let top = tableau[pile].cards.last,
                  top.canPlaceOnFoundation(topCard: foundations[top.suit]?.last) else { continue }
            return (.tableau(pile: pile, index: tableau[pile].cards.count - 1), top)
        } // for pile
        return nil
    } // nextAutoCompleteMove()

    /// Animates `card` flying from wherever `source` currently sits to its
    /// foundation slot, THEN actually removes it from the source and appends
    /// it to the foundation once the flight visually finishes landing.
    /// Removing it from the source pile happens right away (so the pile
    /// underneath updates immediately, matching a real card being lifted off
    /// it) — only the foundation append waits for the animation.
    @MainActor
    private func flyCard(_ card: Card, from source: CardSource, duration: TimeInterval) async {
        guard let destFrame = dropZoneFrames[.foundation(card.suit)] else {
            // Frame not known yet (shouldn't normally happen once the board
            // has laid out at least once) — place it instantly rather than
            // animating from/to nowhere.
            removeCard(at: source)
            foundations[card.suit, default: []].append(card)
            return
        } // guard we know where this card is actually headed

        let startFrame: CGRect
        switch source {
        case .waste:
            startFrame = wasteFrame ?? destFrame
        case .tableau(let pile, _):
            startFrame = dropZoneFrames[.tableau(pile)] ?? destFrame
        case .foundation:
            startFrame = destFrame // shouldn't occur — a card already on a foundation is never an auto-complete source
        } // switch source

        removeCard(at: source) // lift it off the source pile right away — the pile updates underneath the flying copy immediately
        autoCompleteFlight = AutoCompleteFlight(
            card: card,
            position: CGPoint(x: startFrame.midX, y: startFrame.midY),
            size: CGSize(width: destFrame.width, height: destFrame.height)
        )

        withAnimation(.easeInOut(duration: duration)) {
            autoCompleteFlight?.position = CGPoint(x: destFrame.midX, y: destFrame.midY)
        } // withAnimation
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        foundations[card.suit, default: []].append(card)
        autoCompleteFlight = nil
    } // flyCard(_:from:duration:)

    /// Recomputes both derived game-status flags — call after any action that
    /// could change move availability or complete the game.
    private func recalculateGameStatus() {
        triggerAutoCompleteIfNeeded()
        updateDerivedStatus()
    } // recalculateGameStatus()

    /// The actual won/stuck computation — split out from `recalculateGameStatus()`
    /// specifically so the auto-complete animation's own completion handler
    /// (in `triggerAutoCompleteIfNeeded()`) can call THIS instead of
    /// `recalculateGameStatus()` itself. Calling the full function there was
    /// a real bug: once the animation genuinely runs out of moves (a fully
    /// exposed tableau isn't a *guaranteed* win — Klondike's color/rank
    /// constraints can still lock it up), `triggerAutoCompleteIfNeeded()`'s
    /// own guard was STILL satisfied (tableau still fully face-up,
    /// foundations still not full — nothing about that guard changes just
    /// because a run found zero moves), so it kept spawning a fresh
    /// `Task` that immediately found nothing to do and finished, which
    /// triggered another one, forever — an infinite loop of empty runs, each
    /// one printing `runAutoCompleteAnimation: finished` with identical,
    /// unchanging foundation counts. This split ensures the completion
    /// handler only ever finalizes won/stuck once, without re-arming itself.
    private func updateDerivedStatus() {
        // Compute won FIRST — winning and being stuck are mutually exclusive,
        // and checking stuck first was the actual bug: the instant the last
        // card lands on a foundation, hasAnyLegalMove() correctly finds
        // nothing left to do (the game is OVER, not stuck), which briefly
        // flipped isStuck true in the same moment hasWon also went true,
        // firing both the foghorn and the applause together.
        let won = foundations.values.allSatisfy { $0.count == Rank.allCases.count }

        // Only even consider "stuck" once every card in the stock has actually
        // been turned face-up (i.e. the stock itself is empty) — the player
        // should never hear the foghorn while there are still face-down stock
        // cards left to draw, even if the full-knowledge lookahead already
        // proves none of them would help. `hasAnyLegalMove()` still folds in
        // one recycle of the waste beyond that point, since recycling is the
        // real next action once the stock runs dry, not a reason to stay
        // silent forever.
        let stuck = !won && stock.isEmpty && !hasAnyLegalMove()

        // The running timer freezes the instant the game is over for ANY
        // reason — won or stuck — and resumes ticking if something (an undo,
        // most likely) walks the board back out of being stuck. `gameEndDate`
        // alone drives that: nil means "still ticking," non-nil means "frozen
        // as of here."
        let wasOver = hasWon || isStuck
        let isOverNow = won || stuck
        if isOverNow && !wasOver {
            gameEndDate = Date()
        } else if !isOverNow && wasOver {
            gameEndDate = nil
        } // if/else (crossing the game-over line, either direction)

        if stuck != isStuck {
            #if DEBUG
            print("updateDerivedStatus: isStuck \(isStuck) -> \(stuck)")
            #endif
            isStuck = stuck
        } // if changed

        if won != hasWon {
            #if DEBUG
            print("updateDerivedStatus: hasWon \(hasWon) -> \(won)")
            #endif
            hasWon = won
            if won, let start = gameStartDate, let end = gameEndDate {
                resultsStore.record(duration: end.timeIntervalSince(start), datePlayed: end, cheated: hasCheatedThisGame)
            } // if just won, log it to the top-results history
        } // if changed
    } // updateDerivedStatus()

    /// Removes a card from wherever it currently lives, auto-revealing the
    /// new top card of a tableau pile if one was just exposed — standard
    /// Klondike behavior, not a cheat.
    private func removeCard(at source: CardSource) {
        switch source {
        case .waste(let idx):
            guard waste.indices.contains(idx) else { return }
            waste.remove(at: idx)
        case .tableau(let pile, let idx):
            guard tableau.indices.contains(pile), tableau[pile].cards.indices.contains(idx) else { return }
            tableau[pile].cards.remove(at: idx)
            invalidateSelectionIfStale(afterRemovingFromTableau: pile, at: idx)
            autoRevealTopCard(ofPile: pile)
        case .foundation(let suit):
            guard !(foundations[suit]?.isEmpty ?? true) else { return }
            foundations[suit]?.removeLast()
        } // switch source
    } // removeCard(at:)

    private func autoRevealTopCard(ofPile pile: Int) {
        guard tableau.indices.contains(pile),
              let top = tableau[pile].cards.last,
              !top.isFaceUp else { return }
        tableau[pile].cards[tableau[pile].cards.count - 1].isFaceUp = true
    } // autoRevealTopCard(ofPile:)

    // MARK: - Undo (not a cheat, for now)

    /// Increments exactly once per real move — every call site that calls
    /// `pushUndoSnapshot()` (draws, recycles, card placements, the
    /// stock-touching cheats) plus `undo()` itself. Nothing renders from
    /// this number directly; it exists purely as an `onChange` signal so a
    /// view can react to "some move just happened," most notably
    /// `TableauColumnView` clearing its temporary face-down peek reveal —
    /// a cheat-revealed card should only stay visible until the next move,
    /// not linger indefinitely. Same "published counter, not published
    /// state" trick as `newGameToken`.
    @Published private(set) var moveToken: Int = 0

    /// Captures the board exactly as it is right now, before a move is about
    /// to change it. Called at the point in each move function where every
    /// guard has already passed — i.e. only for moves that are ACTUALLY about
    /// to happen — so a rejected/no-op tap never pollutes the undo stack with
    /// a checkpoint that's identical to the one already on top of it.
    private func pushUndoSnapshot() {
        let snapshot = GameSnapshot(stock: stock, waste: waste, tableau: tableau, foundations: foundations)
        undoStack.append(snapshot)
        if undoStack.count > maxUndoDepth {
            undoStack.removeFirst(undoStack.count - maxUndoDepth)
        } // if trimming the oldest checkpoints
        canUndo = true
        moveToken += 1
    } // pushUndoSnapshot()

    /// Rewinds the board to exactly how it was before the last move. Draws,
    /// recycles, card placements, and the stock-touching cheats all push a
    /// checkpoint via `pushUndoSnapshot()`. NOT a cheat for now — sits next to
    /// New Game as an ordinary, above-board feature. (Revisit this once the
    /// rest of the consequence system has settled; making it a hidden cheat
    /// later is a one-line change — just add the `registerCheatAndCheckConsequence()`
    /// call back in below.)
    @discardableResult
    func undo() -> Bool {
        guard let snapshot = undoStack.popLast() else { return false }
        stock = snapshot.stock
        waste = snapshot.waste
        tableau = snapshot.tableau
        foundations = snapshot.foundations
        canUndo = !undoStack.isEmpty
        selectedSource = nil // whatever was selected may not exist in this shape anymore
        moveToken += 1
        #if DEBUG
        print("Undo rewound the board — \(undoStack.count) checkpoint(s) left.")
        #endif
        recalculateGameStatus()
        return true
    } // undo()

    // MARK: - Cheats without a UI-driven destination (peek-only, and stock access)

    /// Cheat: peek at a face-down tableau card without flipping it in the model.
    /// The view layer shows a temporary "ghost" reveal overlay for this card;
    /// a second tap on the same card then selects it via `selectOrDeselect`.
    func cheatPeekTableauCard(pile: Int, cardIndex: Int) -> Card? {
        guard cheatingEnabled else {
            #if DEBUG
            print("CHEAT BLOCKED: peek at pile \(pile) index \(cardIndex) — cheating is turned off.")
            #endif
            return nil
        } // guard cheating is enabled
        guard tableau.indices.contains(pile),
              tableau[pile].cards.indices.contains(cardIndex) else { return nil }
        #if DEBUG
        let peeked = tableau[pile].cards[cardIndex]
        print("CHEAT: peeked at pile \(pile) index \(cardIndex) — it's the \(peeked.rank.label) of \(peeked.suit.rawValue).")
        #endif
        registerCheatAndCheckConsequence()
        return tableau[pile].cards[cardIndex]
    } // cheatPeekTableauCard(pile:cardIndex:)

    /// Cheat: peek into the stock (draw pile) and see every card in it.
    func cheatPeekStock() -> [Card] {
        guard cheatingEnabled else {
            #if DEBUG
            print("CHEAT BLOCKED: peek into the stock — cheating is turned off.")
            #endif
            return []
        } // guard cheating is enabled
        #if DEBUG
        print("CHEAT: peeked into the entire stock (\(stock.count) cards).")
        #endif
        registerCheatAndCheckConsequence()
        return stock
    } // cheatPeekStock()

    /// Cheat: grab any specific card out of the stock, not just the next three.
    @discardableResult
    func cheatGrabFromStock(cardID: UUID, ontoTableau destPile: Int) -> Bool {
        guard cheatingEnabled else {
            #if DEBUG
            print("CHEAT BLOCKED: grab from stock into pile \(destPile) — cheating is turned off.")
            #endif
            return false
        } // guard cheating is enabled
        guard let idx = stock.firstIndex(where: { $0.id == cardID }) else { return false }
        var card = stock[idx]
        card.isFaceUp = true
        pushUndoSnapshot()
        stock.remove(at: idx)
        tableau[destPile].cards.append(card)
        #if DEBUG
        print("CHEAT: grabbed \(card.rank.label) of \(card.suit.rawValue) directly out of the stock into pile \(destPile).")
        #endif
        registerCheatAndCheckConsequence()
        return true
    } // cheatGrabFromStock(cardID:ontoTableau:)

    /// Hidden cheat: long-press the deck during play (2 seconds). Quietly
    /// reshuffles the REMAINING stock, with a much quieter shuffle sound.
    func cheatQuietReshuffleStock() {
        guard phase == .playing else { return }
        guard cheatingEnabled else {
            #if DEBUG
            print("CHEAT BLOCKED: quiet reshuffle of the stock — cheating is turned off.")
            #endif
            return
        } // guard cheating is enabled
        pushUndoSnapshot()
        var deck = Deck(cards: stock)
        deck.shuffle()
        stock = deck.cards
        #if DEBUG
        print("CHEAT: quietly reshuffled the remaining \(stock.count) stock cards.")
        #endif
        registerCheatAndCheckConsequence()
        // View layer: SoundManager.shared.playShuffle(volume: CheatSettings.shared.cheatShuffleVolume)
    } // cheatQuietReshuffleStock()

    // MARK: - Consequence system

    /// Single source of truth for whether ANY hidden cheat is allowed to
    /// fire right now. Every cheat entry point above (and the isCheatSource
    /// gate in selectOrDeselect/beginDrag) checks this before doing
    /// anything, so flipping `CheatSettings.shared.cheatingEnabled` off is
    /// a one-place kill switch for the whole system. Defaults to on.
    private var cheatingEnabled: Bool { CheatSettings.shared.cheatingEnabled }

    /// Every 3rd cheat (3, 6, 9, 12, ...) — separate from, and in addition
    /// to, the probabilistic `.faceDownFlip` consequence `CheatEngine` can
    /// also roll independently. Deterministic like `colorReversalTriggerCounts`
    /// above, so it's checked directly here rather than through
    /// `CheatEngine.rollForConsequence()`.
    private static let faceDownFlipEveryNCheats = 3

    private func registerCheatAndCheckConsequence(caller: String = #function) {
        hasCheatedThisGame = true
        cheatEventCount += 1
        if Self.colorReversalTriggerCounts.contains(cheatEventCount) {
            colorsReversed.toggle()
            #if DEBUG
            print("CHEAT CONSEQUENCE: cheat #\(cheatEventCount) reversed red and black — colors are now \(colorsReversed ? "REVERSED (red suits render black, black suits render red)" : "back to normal").")
            #endif
        } // if this cheat count is one of the deterministic color-reversal triggers
        if cheatEventCount % Self.faceDownFlipEveryNCheats == 0 {
            flipRandomExposedTableauTopCard(reason: "cheat #\(cheatEventCount) (every \(Self.faceDownFlipEveryNCheats))")
        } // if this cheat count is a multiple of the deterministic flip-back trigger
        cheatEngine.registerCheatUsed()
        #if DEBUG
        print("Cheat registered via \(caller) — cumulative cheat points: \(cheatEngine.cheatPoints)")
        #endif
        if let consequence = cheatEngine.rollForConsequence() {
            apply(consequence)
        } // if a consequence rolled

        // Every cheat entry point funnels through here, and some of them
        // mutate the board on their own (a faceDownFlip consequence hides an
        // exposed card; cheatGrabFromStock/cheatQuietReshuffleStock change
        // the stock directly) without any OTHER call to recalculateGameStatus()
        // nearby. Left unrecalculated, isStuck/hasWon go stale until some
        // later, completely unrelated action (e.g. a routine draw with a full
        // stock still on the table) happens to trigger the next recalculation
        // and only then discovers the board went stuck — making the foghorn
        // sound like it fired at random, with the stock nowhere near played
        // out. Recalculating right here, at the one place every cheat passes
        // through, keeps both flags honest immediately after whatever just
        // happened, no matter which cheat path caused it.
        recalculateGameStatus()
    } // registerCheatAndCheckConsequence(caller:)

    private func apply(_ consequence: CheatConsequence) {
        switch consequence {
        case .critterAndFrog:
            break // purely a view-layer animation; no game-state change

        case .suitSwap(let scope):
            swapSuits(scope: scope)

        case .faceDownFlip:
            flipAnExposedTopCardFaceDown()
        } // switch consequence
        activeConsequence = consequence
        cheatEngine.resetAfterConsequence()
    } // apply(_:)

    private func swapSuits(scope: SwapScope) {
        func shouldSwap(_ card: Card) -> Bool {
            switch scope {
            case .redOnly: return card.isRed
            case .blackOnly: return !card.isRed
            case .both: return true
            } // switch scope
        } // shouldSwap(_:)
        for i in tableau.indices {
            for j in tableau[i].cards.indices where tableau[i].cards[j].isFaceUp && shouldSwap(tableau[i].cards[j]) {
                tableau[i].cards[j].swapSuitWithinColor()
            } // for j
        } // for i
        for i in waste.indices where shouldSwap(waste[i]) {
            waste[i].swapSuitWithinColor()
        } // for i
    } // swapSuits(scope:)

    /// Only ever flips a pile's TOPMOST face-up card — meaning the face-up
    /// card closest to the still-face-down cards beneath it (the "back" of
    /// the visible run, lowest array index among face-up cards, rendered
    /// highest on screen) — back down. Deliberately NOT the exposed/frontmost
    /// playable card at the bottom of the screen: re-hiding just that one
    /// card is barely a setback, whereas hiding the one right at the
    /// boundary re-buries the whole face-up run above it, which is the
    /// actual point of this being a punishing cheat consequence.
    private func flipAnExposedTopCardFaceDown() {
        let candidates = tableau.indices.filter { tableau[$0].cards.contains(where: { $0.isFaceUp }) }
        guard let pile = candidates.randomElement(),
              let flipIndex = tableau[pile].cards.firstIndex(where: { $0.isFaceUp }) else { return }
        let flipped = tableau[pile].cards[flipIndex]
        tableau[pile].cards[flipIndex].isFaceUp = false
        lastFlippedCard = FlippedCardLocation(pile: pile, index: flipIndex)
        #if DEBUG
        print("Cheat consequence: face-down flip hit pile \(pile) index \(flipIndex) — \(flipped.rank.label) of \(flipped.suit.rawValue) is now hidden again.")
        #endif
    } // flipAnExposedTopCardFaceDown()

    /// The deterministic every-3rd-cheat sibling of `flipAnExposedTopCardFaceDown()`
    /// above (called via `CheatEngine`'s probabilistic roll). This one is
    /// triggered directly from `registerCheatAndCheckConsequence` instead —
    /// see `faceDownFlipEveryNCheats` — and uses a STRICTER eligibility rule:
    /// only a pile with at least 2 face-up cards total qualifies, so a pile
    /// is never left with zero visible cards, and a pile with only its
    /// single exposed card face-up (nothing to re-bury above it) is
    /// correctly skipped rather than flipping its only visible card.
    /// Reuses the exact same `activeConsequence`/`lastFlippedCard` signals
    /// as the probabilistic version, so the existing flash animation and
    /// ribbit sound fire identically with no view-layer changes — it
    /// deliberately does NOT touch `cheatEngine`/`cheatPoints`, since this
    /// trigger is entirely independent of that probabilistic system.
    private func flipRandomExposedTableauTopCard(reason: String) {
        let candidates = tableau.indices.filter { pile in
            tableau[pile].cards.filter(\.isFaceUp).count >= 2
        } // filter — genuinely "2 or more cards faced up", so hiding one still leaves at least one visible
        guard let pile = candidates.randomElement(),
              let flipIndex = tableau[pile].cards.firstIndex(where: { $0.isFaceUp }) else { return }
        let flipped = tableau[pile].cards[flipIndex]
        tableau[pile].cards[flipIndex].isFaceUp = false
        lastFlippedCard = FlippedCardLocation(pile: pile, index: flipIndex)
        activeConsequence = .faceDownFlip
        #if DEBUG
        print("CHEAT CONSEQUENCE: \(reason) flipped pile \(pile) index \(flipIndex) (the topmost/back face-up card) face down again — \(flipped.rank.label) of \(flipped.suit.rawValue) is now hidden.")
        #endif
    } // flipRandomExposedTableauTopCard(reason:)

    /// Call once the view has finished animating/playing sound for a consequence.
    func clearConsequence() {
        activeConsequence = nil
    }
}
