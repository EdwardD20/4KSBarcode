//
//  Views/SolitaireContentView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Root view; lays out the table, wires SolitaireGameState to all subviews, and handles platform-specific sizing and layout fixes.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SolitaireContentView: View {
    
    let onExitToHost: (() -> Void)?

    init(onExitToHost: (() -> Void)? = nil) {
        self.onExitToHost = onExitToHost
    }

    @StateObject private var game = SolitaireGameState()
    @State private var critterActive = false
    @State private var showHelp = false
    @State private var showResults = false
    private let showHands = false // see note above DealerHandOverlayView's call site
    private let showDebugBanner = false // dev-only diagnostic strip — flip on locally when debugging

    /// Fixed ratios derived from the original hand-picked sizes (88pt cards,
    /// 30pt tableau overlap, 22pt waste fan) so resizing preserves proportions.
    private let overlapRatio: CGFloat = 30.0 / 88.0
    private let fanRatio: CGFloat = 22.0 / 88.0
    private let assumedMaxStackDepth: CGFloat = 13 // sizing assumption for "fits vertically" — iPad/macOS only now, see computeCardWidth

    /// True on iPhone specifically (not iPad) — used to pick the scrollable,
    /// no-zoom layout below (portrait AND landscape both use it). Same idiom
    /// check AppDelegate uses for the orientation lock, kept consistent with
    /// it on purpose.
    #if os(iOS)
    private var isPhoneIdiom: Bool { UIDevice.current.userInterfaceIdiom == .phone }
    #else
    private var isPhoneIdiom: Bool { false }
    #endif

    // MARK: - Pinch-to-zoom / pan state (iPad/macOS only — iPhone dropped
    // this in favor of a plain scrollable layout, portrait or landscape; see phoneGameArea)
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 3.0

    var body: some View {
        Group {
            #if os(iOS)
            if isPhoneIdiom {
                // iPhone bypasses NavigationStack/.toolbar entirely — that's
                // what spins up the new iOS 26 "floating bar" system
                // (FloatingBarHostingView), which turned out to be reserving
                // unexplained leading space and shifting the whole board
                // right. Drawing our own plain top bar sidesteps that system
                // altogether instead of trying to work around its behavior.
                phoneRoot
            } else {
                // iOS toolbar items (.navigationBarTrailing) need a
                // NavigationStack ancestor to have an actual nav bar to
                // attach to — without this, "New Game" and the help button
                // silently don't render at all. iPad keeps this; only
                // iPhone dropped it (see above).
                NavigationStack {
                    desktopGameArea
                        .toolbar { toolbarContent }
                        .safeAreaInset(edge: .top) { if showDebugBanner { debugBanner } }
                        // The system nav bar is opaque white by default,
                        // which paints over the felt that's already
                        // extending underneath it (via ignoresSafeArea in
                        // desktopGameArea) — that's the white strip along
                        // the top edge. Hiding the bar's own background lets
                        // the felt show through, with only the toolbar
                        // buttons floating on top of it.
                        .toolbarBackground(.hidden, for: .navigationBar)
                } // NavigationStack
            } // if/else
            #else
            desktopGameArea
                .toolbar { toolbarContent }
                .safeAreaInset(edge: .top) { if showDebugBanner { debugBanner } }
                .toolbarBackground(.hidden, for: .windowToolbar)
            #endif
        } // Group
        .onAppear { startNewGameWithSound() }
        .onChange(of: game.activeConsequence) { _, consequence in
            handle(consequence)
        } // onChange (cheat consequence)
        .onChange(of: game.isStuck) { _, stuck in
            guard stuck else { return } // only cue on the transition INTO stuck, not out of it
            SoundManager.shared.playFoghorn(volume: CheatSettings.shared.stuckForeghornVolume)
        } // onChange (stuck detection)
        .onChange(of: game.cheatEventCount) { _, count in
            guard count > 0 else { return } // 0 only happens right after startNewGame() resets it — not an actual cheat
            SoundManager.shared.playChicken()
        } // onChange (fires on EVERY cheat move, not just the first)
        .onChange(of: game.hasWon) { _, won in
            guard won else { return }
            SoundManager.shared.playApplause()
        } // onChange (win detection)
        .sheet(isPresented: $showHelp) {
            HelpView()
        } // sheet (help)
        .sheet(isPresented: $showResults) {
            ResultsView(resultsStore: game.resultsStore)
        } // sheet (top results)
    } // body

    /// iPhone's root view — no NavigationStack, no .toolbar. Just the game
    /// board with our own plain top bar attached via safeAreaInset, so the
    /// scrollable content is pushed down below it rather than needing to
    /// coexist with whatever the system's floating-bar layout does.
    private var phoneRoot: some View {
        phoneGameArea
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    phoneTopBar
                    if showDebugBanner { debugBanner }
                } // VStack
            } // safeAreaInset
    } // phoneRoot

    /// Hand-drawn replacement for the system toolbar on iPhone: timer on the
    /// left, the same New Game / Undo / Trophy / Help actions on the right.
    /// No reset-zoom button — iPhone dropped pinch-zoom already.
    private var phoneTopBar: some View {
        HStack(spacing: 12) {
            if let onExitToHost {
                Button(LocalizedStringKey("Return to app"), action: onExitToHost)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.4), in: Capsule())
            } // if let onExitToHost
            GameTimerView(game: game)
            Spacer()
            Button("New Game") {
                startNewGameWithSound()
            } // Button
            Button {
                game.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            } // Button
            .disabled(!game.canUndo)
            Button {
                showResults = true
            } label: {
                Image(systemName: "trophy")
            } // Button
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            } // Button
        } // HStack
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 12)
        .padding(.top, 8)
    } // phoneTopBar

    /// iPhone layout: the SAME structure in both portrait and landscape —
    /// top bar, then deck/waste/foundations, then the tableau below that —
    /// and the whole thing scrolls vertically, so however deep a tableau
    /// pile gets (or however short landscape's height is), the user scrolls
    /// down to see the rest of it rather than the app needing to shrink
    /// cards to guarantee everything fits inside a fixed height. No
    /// pinch-to-zoom/pan here (see desktopGameArea) since scrolling now
    /// covers the same underlying need (seeing content that doesn't fit in
    /// one screenful) without it.
    private var phoneGameArea: some View {
        GeometryReader { geo in
            let cardWidth = computePhoneCardWidth(in: geo.size)
            let fanOffset = cardWidth * fanRatio
            let overlapOffset = cardWidth * overlapRatio

            ZStack {
                // Table background — sits outside the ScrollView so it
                // always fills the full screen regardless of scroll
                // position or how tall the scrollable content grows.
                Image("TableFelt")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        // Hands hidden for now — the placeholder art isn't
                        // tied to anything functional yet, and it was in
                        // the way visually.
                        if showHands {
                            DealerHandOverlayView(appearance: game.appearance, phase: game.phase)
                        } // if showHands

                        HStack(alignment: .top, spacing: 12) {
                            DeckView(game: game, width: cardWidth)
                            WasteView(game: game, cardWidth: cardWidth, fanOffset: fanOffset)
                            FoundationsView(game: game, cardWidth: cardWidth)
                        } // HStack (deck, waste, foundations — foundations sit directly next to the waste, not pushed to the trailing edge)
                        .padding(.horizontal, 12)

                        HStack(alignment: .top, spacing: 6) {
                            ForEach(0..<7, id: \.self) { pileIndex in
                                TableauColumnView(game: game, pileIndex: pileIndex, cardWidth: cardWidth, overlapOffset: overlapOffset, reportsFullHeight: true)
                            } // ForEach
                        } // HStack (7 tableau columns — each one now reports its OWN correct height via TableauColumnView's .frame, so this HStack sizes itself naturally to whichever pile is deepest; no manual height guess needed here anymore)
                        .padding(.horizontal, 12)
                        // A full extra viewport's worth of buffer, not just
                        // one card — landscape's viewport is short enough
                        // that a deep pile (say, a long cheat-built run) can
                        // still end up needing more headroom below it than
                        // a single card's height provides to comfortably
                        // clear the bottom edge. This guarantees the last
                        // card in ANY pile, at ANY depth, in EITHER
                        // orientation, can always be scrolled clear up past
                        // the viewport's bottom edge with real room to
                        // spare — a smaller buffer keeps needing to be
                        // exactly right; a generous one just costs some
                        // harmless empty scroll space past the cards.
                        .padding(.bottom, geo.size.height*2)
                    } // VStack (top row, then tableau — the "tableau below stock/foundations" layout)
                    .padding(.top, 16)
                    // ScrollView doesn't guarantee its content is laid out
                    // leading-aligned against the width it's given — it can
                    // end up centered (or, as this turned out to be,
                    // trailing-aligned) instead, which is what was pushing
                    // the whole board right and running the far edge
                    // off-screen even though cardWidth itself was already
                    // correct. maxWidth: .infinity + alignment: .leading
                    // forces this content itself to fill and anchor left,
                    // which is more reliable here than pinning an exact
                    // width.
                    .frame(maxWidth: .infinity, alignment: .leading)
                } // ScrollView

                CritterOverlayView(isActive: $critterActive) {
                    game.clearConsequence()
                } // CritterOverlayView

                if let preview = game.dragPreview {
                    DragPreviewOverlay(preview: preview, colorsReversed: game.colorsReversed) // no ambient zoom on iPhone — default scale of 1.0
                } // if a drag is in progress

                if let flight = game.autoCompleteFlight {
                    AutoCompleteFlightOverlay(flight: flight, colorsReversed: game.colorsReversed)
                } // if the win-triggered auto-complete animation is currently flying a card
            } // ZStack
            .coordinateSpace(name: "board") // shared reference frame for every pile's drop-zone frame AND every drag gesture's reported location
            .allowsHitTesting(!game.isAutoCompleting) // no legitimate move exists once auto-complete starts — this also avoids a stray tap/drag racing the animation
        } // GeometryReader
    } // phoneGameArea

    /// iPad/macOS layout — unchanged from before: pinch-to-zoom/pan still
    /// available, compact (single-row) arrangement still kicks in for a
    /// wide-but-short window, everything still sized to fit without
    /// scrolling.
    private var desktopGameArea: some View {
        GeometryReader { geo in
            // Compact layout (deck/waste/tableau/foundations all in ONE row,
            // top-aligned) kicks in when height is genuinely tight relative
            // to width. Taller layouts (iPad, macOS's default window) keep
            // the original two-row arrangement.
            let isCompact = geo.size.height < 500 && geo.size.width > geo.size.height
            let isPortrait = geo.size.height >= geo.size.width
            let cardWidth = computeCardWidth(in: geo.size, isCompact: isCompact)
            let fanOffset = cardWidth * fanRatio

            ZStack {
                // Table background — TableFelt is an IMAGE asset (Table-Felt.png),
                // so it's drawn with Image, not Color. This lives OUTSIDE the
                // zoom/pan/clip group below on purpose: that group's
                // .clipped() clamps to this GeometryReader's own frame,
                // which (being inside a NavigationStack, and inset for the
                // landscape notch/rounded corners on the sides) is smaller
                // than the true screen bounds — so when the felt used to
                // live INSIDE that clipped group, ignoresSafeArea() would
                // bleed it out to the real edges only for .clipped() to
                // immediately crop it right back down to the safe frame,
                // leaving plain white showing at the true top/side edges.
                // Sitting out here, the felt's ignoresSafeArea() is never
                // undone by that clip and reaches every physical edge.
                Image("TableFelt")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()

                ZStack {
                    // Hands hidden for now — the placeholder art isn't tied
                    // to anything functional yet, and it was in the way
                    // visually.
                    if showHands {
                        DealerHandOverlayView(appearance: game.appearance, phase: game.phase)
                    } // if showHands

                    Group {
                        if isCompact {
                            compactLayout(cardWidth: cardWidth, overlapOffset: cardWidth * overlapRatio, fanOffset: fanOffset)
                        } else {
                            stackedLayout(cardWidth: cardWidth, fanOffset: fanOffset, isPortrait: isPortrait)
                        } // if/else
                    } // Group (layout choice)

                    CritterOverlayView(isActive: $critterActive) {
                        game.clearConsequence()
                    } // CritterOverlayView
                } // ZStack (zoomable/pannable game content — felt is NOT part of this)
                .scaleEffect(zoomScale)
                .offset(panOffset)
                // Deliberately OUTSIDE the scaleEffect/offset above, so
                // `.named("board")` frames captured from inside that group
                // (both the piles' drop-zone frames and each drag gesture's
                // reported location) are automatically expressed in this
                // OUTER, unscaled reference frame — SwiftUI's coordinate
                // conversion walks the real render tree, so it accounts for
                // the zoom/pan transform for us rather than needing to undo
                // it by hand.
                // Pinching in and panning have no clipping of their own — a
                // scaled/offset view still paints wherever the transform puts
                // it, with nothing stopping it from bleeding up past this
                // GeometryReader's own top edge and rendering underneath
                // whatever chrome sits above it (a debug banner, if one's ever
                // re-enabled; "New Game" and the other toolbar buttons on both
                // platforms). The pan clamp above is meant to stop that in the
                // first place, but clipping to our own frame here is a hard
                // guarantee regardless: nothing this view draws can ever escape
                // its own bounds, so there's nothing left to get lost behind.
                // Scoped to just the cards/critter — NOT the felt (see above).
                .clipped()

                if let preview = game.dragPreview {
                    // Deliberately OUTSIDE the scaled/clipped group above —
                    // this way its `.position()` matches the same unscaled
                    // "board" coordinates the drag gesture reported, with no
                    // double-transform to account for. `scale: zoomScale` is
                    // passed through purely so the drawn card size still
                    // matches whatever the board is currently zoomed to.
                    DragPreviewOverlay(preview: preview, scale: zoomScale, colorsReversed: game.colorsReversed)
                } // if a drag is in progress

                if let flight = game.autoCompleteFlight {
                    // Same "outside the scaled/clipped group" reasoning as
                    // DragPreviewOverlay above — matches the unscaled "board"
                    // coordinates dropZoneFrames/wasteFrame were captured in.
                    AutoCompleteFlightOverlay(flight: flight, colorsReversed: game.colorsReversed)
                        .scaleEffect(zoomScale)
                } // if the win-triggered auto-complete animation is currently flying a card
            } // ZStack (felt + zoomable content + drag preview)
            .coordinateSpace(name: "board") // shared reference frame for every pile's drop-zone frame AND every drag gesture's reported location
            // .simultaneousGesture (not .gesture) so pinch/pan don't steal
            // taps away from the cards underneath — both recognizers get a
            // chance to see the touch rather than one exclusively consuming
            // it. Attached to the WHOLE table (felt included), not just the
            // card content, so pinching anywhere on screen works, not only
            // directly over cards.
            .simultaneousGesture(magnificationGesture(boardSize: geo.size))
            .simultaneousGesture(panGesture(boardSize: geo.size))
            .allowsHitTesting(!game.isAutoCompleting) // no legitimate move exists once auto-complete starts — this also avoids a stray tap/drag racing the animation
        } // GeometryReader
    } // desktopGameArea

    /// Compact (iPad/macOS-only) arrangement: deck, waste, all 7 tableau
    /// columns, and the foundations share one horizontal band, top-aligned
    /// with each other. Foundations are pushed to the right edge via the
    /// trailing Spacer. Frees up the entire vertical space a separate top
    /// row would otherwise need, for a window that's wide but short.
    private func compactLayout(cardWidth: CGFloat, overlapOffset: CGFloat, fanOffset: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                DeckView(game: game, width: cardWidth)
                WasteView(game: game, cardWidth: cardWidth, fanOffset: fanOffset)
                HStack(alignment: .top, spacing: 8) {
                    ForEach(0..<7, id: \.self) { pileIndex in
                        TableauColumnView(game: game, pileIndex: pileIndex, cardWidth: cardWidth, overlapOffset: overlapOffset)
                    } // ForEach
                } // HStack (7 tableau columns)
                Spacer(minLength: 0) // pushes foundations to the right edge
                FoundationsView(game: game, cardWidth: cardWidth)
            } // HStack (everything, one row, top-aligned)
            .padding(.horizontal)

            Spacer() // absorbs any leftover space at the bottom
        } // VStack
        .padding(.top, 12)
    } // compactLayout(cardWidth:overlapOffset:fanOffset:)

    /// Original two-row arrangement: deck/waste/foundations on top, tableau
    /// spanning full width below. `cardWidth` (see computeCardWidth) is
    /// capped by BOTH available width and available height, so a wide-but-
    /// short screen (iPad landscape) doesn't end up with cards too tall for
    /// a full 13-deep tableau column to fit. `tableauRow` still measures its
    /// OWN actual allotted height directly (via its nested GeometryReader)
    /// rather than trusting the estimate above blindly, so this stays
    /// correct even if the top row's real height doesn't quite match the
    /// estimate, and adapts to any device, toolbar height, or Dynamic Type
    /// size without needing further tuned constants.
    private func stackedLayout(cardWidth: CGFloat, fanOffset: CGFloat, isPortrait: Bool) -> some View {
        // .leading is the key part here — the top-row HStack can now be
        // NARROWER than the full width (the portrait branch below caps how
        // far its Spacer can expand), and a VStack's default .center
        // alignment would otherwise center that shorter row in the space
        // left over, dragging the deck away from the left edge and pushing
        // the foundations even further right than intended (clipping the
        // 4th one off-screen). Pinning both rows to .leading keeps the deck
        // flush with the tableau's own left edge no matter how much of the
        // width that top row actually uses.
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                DeckView(game: game, width: cardWidth)
                WasteView(game: game, cardWidth: cardWidth, fanOffset: fanOffset)
                // In portrait, a fully-expanding Spacer has the whole width
                // of the screen to push into, since only 2 of the row's
                // eventual 6 "slots" (deck+waste) sit to its left — that
                // shoves the foundations out past where they comfortably
                // read as part of the same row. Landscape has enough width
                // that this isn't visually an issue, so it keeps the old
                // edge-aligned placement; portrait instead caps how far the
                // gap can grow, keeping the foundations near the stock the
                // way landscape already effectively reads.
                if isPortrait {
                    Spacer(minLength: 24)
                        .frame(maxWidth: cardWidth * 0.6)
                } else {
                    Spacer()
                } // if/else (portrait gets a capped gap, landscape keeps the old push-to-edge one)
                FoundationsView(game: game, cardWidth: cardWidth)
            } // HStack (deck/waste/foundations row)
            .padding(.horizontal)

            tableauRow(cardWidth: cardWidth) // fills all remaining vertical space itself
        } // VStack (main game layout)
        .padding(.top, 20) // hands hidden for now, so less reserved space needed up top
    } // stackedLayout(cardWidth:fanOffset:isPortrait:)

    /// The 7 tableau columns, wrapped in their OWN GeometryReader so
    /// overlapOffset is computed from the ACTUAL vertical space SwiftUI
    /// allocates here — not a guess made before the top row, toolbar, or
    /// debug banner even rendered. This is what makes the layout correctly
    /// self-adjust on any device (including ones with lots of height to
    /// spare, like iPad, where cards should size generously rather than
    /// being pre-emptively shrunk for a worst case that isn't happening).
    private func tableauRow(cardWidth: CGFloat) -> some View {
        GeometryReader { tableauGeo in
            let cardHeight = cardWidth * 1.4
            let desiredOverlap = cardWidth * overlapRatio
            let maxOverlapForMeasuredHeight = max(8, (tableauGeo.size.height - cardHeight) / (assumedMaxStackDepth - 1))
            let overlapOffset = min(desiredOverlap, maxOverlapForMeasuredHeight)

            HStack(alignment: .top, spacing: 8) {
                ForEach(0..<7, id: \.self) { pileIndex in
                    TableauColumnView(game: game, pileIndex: pileIndex, cardWidth: cardWidth, overlapOffset: overlapOffset)
                } // ForEach
            } // HStack (7 tableau columns)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal)
        } // GeometryReader (measures its own real allotted height)
    } // tableauRow(cardWidth:)

    // MARK: - Zoom / pan gestures

    /// How far the board is allowed to pan at a given zoom level before its
    /// edge would pull in from the screen edge and expose empty space
    /// beyond it. `.scaleEffect` grows the board around its own center, so
    /// at zoom `z` each edge sits `size * (z - 1) / 2` past where it was —
    /// that's exactly how far `.offset` (applied on top, in the same
    /// unscaled point space) is allowed to shift it back before the
    /// opposite edge would clear the screen.
    private func maxPanOffset(for zoom: CGFloat, in boardSize: CGSize) -> CGSize {
        CGSize(
            width: max(0, boardSize.width * (zoom - 1) / 2),
            height: max(0, boardSize.height * (zoom - 1) / 2)
        ) // CGSize
    } // maxPanOffset(for:in:)

    private func clamped(_ offset: CGSize, to maxOffset: CGSize) -> CGSize {
        CGSize(
            width: min(max(offset.width, -maxOffset.width), maxOffset.width),
            height: min(max(offset.height, -maxOffset.height), maxOffset.height)
        ) // CGSize
    } // clamped(_:to:)

    private func magnificationGesture(boardSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = min(max(lastZoomScale * value, minZoom), maxZoom)
                // Re-clamp on every change, not just at the end — zooming
                // OUT while panned to an edge would otherwise reveal empty
                // space for the duration of the gesture, not just after.
                panOffset = clamped(panOffset, to: maxPanOffset(for: zoomScale, in: boardSize))
            } // onChanged
            .onEnded { _ in
                lastZoomScale = zoomScale
                panOffset = clamped(panOffset, to: maxPanOffset(for: zoomScale, in: boardSize))
                lastPanOffset = panOffset
                if zoomScale <= minZoom {
                    withAnimation {
                        panOffset = .zero
                        lastPanOffset = .zero
                    } // withAnimation
                } // if fully zoomed out, recenter
            } // onEnded
    } // magnificationGesture(boardSize:)

    private func panGesture(boardSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoomScale > minZoom else { return } // only pan while actually zoomed in
                let proposed = CGSize(
                    width: lastPanOffset.width + value.translation.width,
                    height: lastPanOffset.height + value.translation.height
                ) // CGSize
                panOffset = clamped(proposed, to: maxPanOffset(for: zoomScale, in: boardSize))
            } // onChanged
            .onEnded { _ in
                lastPanOffset = panOffset
            } // onEnded
    } // panGesture(boardSize:)

    private func resetZoom() {
        withAnimation {
            zoomScale = 1.0
            lastZoomScale = 1.0
            panOffset = .zero
            lastPanOffset = .zero
        } // withAnimation
    } // resetZoom()

    /// TEMP DEBUG SUMMARY — remove once real hand art makes phase transitions
    /// visually obvious on their own. Kept terse since it's shown in a thin banner.
    private var debugSummary: String {
        let tableauCounts = game.tableau.map { String($0.cards.count) }.joined(separator: ",")
        let elapsed = game.gameStartDate.map { Int(Date().timeIntervalSince($0)) } ?? 0
        return "P:\(String(describing: game.phase)) St:\(game.stock.count) W:\(game.waste.count) T:[\(tableauCounts)] Sel:\(String(describing: game.selectedSource)) Stk:\(game.isStuck ? "Y" : "n") Won:\(game.hasWon ? "Y" : "n") T+\(elapsed)s Undo:\(game.canUndo ? "Y" : "n")"
    } // debugSummary

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .automatic) {
            GameTimerView(game: game)
        } // ToolbarItem (running game-length timer)
        ToolbarItem(placement: .automatic) {
            Button("New Game") { startNewGameWithSound() }
        }
        ToolbarItem(placement: .automatic) {
            Button {
                game.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            } // Button
            .disabled(!game.canUndo)
        } // ToolbarItem (undo)
        ToolbarItem(placement: .automatic) {
            Button {
                resetZoom()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            } // Button
        } // ToolbarItem (reset zoom)
        ToolbarItem(placement: .automatic) {
            Button {
                showResults = true
            } label: {
                Image(systemName: "trophy")
            } // Button
        } // ToolbarItem (top results)
        ToolbarItem(placement: .automatic) {
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            } // Button
        } // ToolbarItem (help)
        #else
        // This #else branch (iOS) is now only ever reached for iPad — iPhone
        // uses phoneTopBar/phoneRoot instead, bypassing NavigationStack's
        // .toolbar entirely. No isPhoneIdiom check needed here anymore.
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 12) {
                if let onExitToHost {
                    Button(LocalizedStringKey("Return to app"), action: onExitToHost)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.4), in: Capsule())
                }
                GameTimerView(game: game)
            }
        } // ToolbarItem (return action and running game-length timer)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("New Game") { startNewGameWithSound() }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                game.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            } // Button
            .disabled(!game.canUndo)
        } // ToolbarItem (undo)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                resetZoom()
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
            } // Button
        } // ToolbarItem (reset zoom)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showResults = true
            } label: {
                Image(systemName: "trophy")
            } // Button
        } // ToolbarItem (top results)
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
            } // Button
        } // ToolbarItem (help)
        #endif
    } // toolbarContent

    /// Dedicated full-width strip below the nav bar/toolbar — this reserves
    /// its OWN space (pushing game content down, not overlaying it) so the
    /// text has real room instead of getting squeezed into a toolbar item
    /// (which is what was collapsing into an unreadable round bubble before).
    private var debugBanner: some View {
        Text(debugSummary)
            .font(.caption2)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .textSelection(.enabled)
    } // debugBanner

    /// Derives a single card width for the iPad/macOS layout. The compact
    /// layout still needs a height-based check here (everything shares one
    /// row with no natural "measure what's left" point).
    ///
    /// The stacked layout USED to be purely width-based, on the theory that
    /// `tableauRow` measuring its own real allotted height would handle
    /// vertical fit on its own. That's true as far as it goes — but on a
    /// screen that's wide relative to its height (an iPad in landscape,
    /// especially with the toolbar/debug banner eating into the top), a
    /// purely width-driven card ends up tall enough that there isn't enough
    /// leftover vertical room for a full 13-deep tableau stack even at
    /// `tableauRow`'s minimum 8pt overlap floor — so the pile quietly runs
    /// off the bottom of the screen. Capping cardWidth here by the SAME
    /// vertical budget `tableauRow` will need (top row + tableau row, at the
    /// full desired overlap, not the clamped one) keeps that floor from ever
    /// being hit in the first place.
    private func computeCardWidth(in size: CGSize, isCompact: Bool) -> CGFloat {
        let horizontalPadding: CGFloat = 32 // matches .padding(.horizontal), 16 per side
        let columnSpacing: CGFloat = 8

        if isCompact {
            // One row: deck (1) + waste (~1) + 7 tableau + foundations (4),
            // plus the small gaps between sections and FoundationsView's own
            // internal 12pt spacing between its 4 slots.
            let totalSlots: CGFloat = 1 + 1 + 7 + 4
            let sectionGaps: CGFloat = 16 * 3 // deck->waste, waste->tableau, tableau->foundations
            let tableauGaps: CGFloat = columnSpacing * 6
            let foundationGaps: CGFloat = 12 * 3
            let availableWidth = size.width - horizontalPadding - sectionGaps - tableauGaps - foundationGaps
            let widthBasedCardWidth = availableWidth / totalSlots

            let reservedVertical: CGFloat = 60 // just the debug banner + minimal top/bottom padding
            let availableHeight = max(0, size.height - reservedVertical)
            let heightBasedCardWidth = availableHeight / (1.4 + (assumedMaxStackDepth - 1) * overlapRatio)

            return max(40, min(widthBasedCardWidth, heightBasedCardWidth))
        } else {
            let availableWidth = size.width - horizontalPadding
            let widthBasedCardWidth = (availableWidth - columnSpacing * 6) / 7

            // Vertical budget: the top row (deck/waste/foundations, its own
            // height being one cardHeight) plus its top padding, plus the
            // tableau row sized to fit assumedMaxStackDepth cards at the
            // FULL desired overlap (not the clamped floor — solving for
            // that directly is what keeps the floor from ever being needed).
            let topRowPadding: CGFloat = 20 // matches stackedLayout's .padding(.top, 20)
            let reservedVertical = topRowPadding
            let availableHeight = max(0, size.height - reservedVertical)
            // availableHeight == topRowHeight + tableauHeight
            //                  == (1.4*cw) + (1.4*cw + (depth-1)*overlapRatio*cw)
            //                  == cw * (2*1.4 + (depth-1)*overlapRatio)
            let heightDivisor = 2 * 1.4 + (assumedMaxStackDepth - 1) * overlapRatio
            let heightBasedCardWidth = availableHeight / heightDivisor

            return max(40, min(widthBasedCardWidth, heightBasedCardWidth))
        } // if/else
    } // computeCardWidth(in:isCompact:)

    /// Derives a single card width for the iPhone layout — used in both
    /// portrait and landscape, since it's driven purely by whatever width
    /// `geo.size.width` happens to report for the current orientation.
    /// Deliberately WIDTH-only — unlike computeCardWidth above, there's no
    /// height-based cap here, because the tableau now lives inside a
    /// vertical ScrollView: however deep a pile gets (or however short
    /// landscape's height runs), the user scrolls to see the rest of it, so
    /// there's no reason to preemptively shrink cards to guarantee a full
    /// 13-deep stack fits inside a fixed height.
    ///
    /// NOTE ON "50% bigger": the 7 tableau columns still have to fit
    /// side by side, uncropped, across whatever width this is called with —
    /// that width is the hard ceiling on how big a card can be here, no
    /// matter what multiplier gets applied on top of it (a bigger multiplier
    /// just pushes the later columns off the right edge of the screen,
    /// unreachable). This returns the biggest size that still fits all 7
    /// columns in one row; see the chat reply for why an exact 50% bump
    /// isn't achievable without either the columns overlapping each other
    /// or wrapping the tableau into more than one row.
    ///
    /// Two DIFFERENT rows share this same cardWidth, and each has its own
    /// "does it fit?" arithmetic — the tableau row (7 bare columns) isn't
    /// the only one that can overflow. The top row (deck + waste, which
    /// fans out wider than a single card + foundations, which has its own
    /// internal 12pt gaps between its 4 slots) adds up to MORE total width
    /// per "slot" than the tableau row does, so a cardWidth that fits the
    /// tableau perfectly can still overflow the top row — which is exactly
    /// what was pushing FoundationsView off the trailing edge, invisible,
    /// on narrower phones. Solving for both and taking the smaller keeps
    /// every row on-screen.
    private func computePhoneCardWidth(in size: CGSize) -> CGFloat {
        let horizontalPadding: CGFloat = 24 // tighter than iPad/macOS's 32 — every point helps here
        let availableWidth = max(0, size.width - horizontalPadding)

        let columnSpacing: CGFloat = 6 // tighter than iPad/macOS's 8, likewise
        let tableauCardWidth = (availableWidth - columnSpacing * 6) / 7

        // Top row width(cw) = cw (deck)
        //                    + gap + cw*(1 + 2*fanRatio) (waste, fanned)
        //                    + gap + (4*cw + 3*12) (foundations, 4 slots + their own internal gaps)
        //                    = cw*(6 + 2*fanRatio) + (2*gap + 36)
        let topRowGap: CGFloat = 12
        let topRowMultiplier = 6 + 2 * fanRatio
        let topRowConstant = topRowGap * 2 + 36
        let topRowCardWidth = (availableWidth - topRowConstant) / topRowMultiplier

        // Ceiling on card size, not just a bug guard: on any real iPhone in
        // PORTRAIT the formulas above already land well under this. In
        // LANDSCAPE, `size.width` is the phone's much longer dimension, so
        // both formulas above would otherwise return a card noticeably
        // bigger than portrait's — capping it here keeps card size
        // consistent across both orientations instead of ballooning
        // whenever there happens to be extra width to spend, and leaves
        // landscape's comparatively short height for the ScrollView to
        // absorb via scrolling rather than via ever-taller cards.
        let sanityCeiling: CGFloat = 65

        return max(40, min(min(tableauCardWidth, topRowCardWidth), sanityCeiling))
    } // computePhoneCardWidth(in:)

    /// Starts a new game and plays the shuffle sound to match — used on both
    /// first launch and every subsequent New Game tap, since setup (pickup,
    /// shuffle, deal) now all happens automatically inside startNewGame().
    private func startNewGameWithSound() {
        game.startNewGame()
        SoundManager.shared.playShuffle(volume: CheatSettings.shared.normalShuffleVolume)
    } // startNewGameWithSound()

    private func handle(_ consequence: CheatConsequence?) {
        guard let consequence else { return }
        switch consequence {
        case .critterAndFrog:
            critterActive = true // CritterOverlayView calls clearConsequence() when it finishes
        case .suitSwap:
            SoundManager.shared.playDeepCroak()
            game.clearConsequence()
        case .faceDownFlip:
            SoundManager.shared.playRibbit()
            game.clearConsequence()
        } // switch consequence
    } // handle(_:)
} // SolitaireContentView

#Preview {
    SolitaireContentView()
}
