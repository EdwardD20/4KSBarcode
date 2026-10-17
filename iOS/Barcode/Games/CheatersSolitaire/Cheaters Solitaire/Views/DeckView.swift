//
//  Views/DeckView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Stock pile view handling single-tap draw and the long-press quiet-reshuffle cheat.
//

import SwiftUI

/// The stock pile. Setup (pickup, shuffle, deal) now happens automatically
/// when a new game starts — see `SolitaireGameState.startNewGame()` — so the deck's
/// tap gestures only matter once actual play has begun:
///   single tap        -> drawThree()
///   2-second long press -> cheatQuietReshuffleStock() — hidden cheat, reorders
///                  ONLY the remaining stock (never touches waste/tableau/
///                  foundations), and only ever counts as a cheat once
///                  `phase == .playing` (which, since setup is automatic, is
///                  the only time the player can interact with the deck at
///                  all anyway). Gated behind a deliberate hold — rather
///                  than a double-tap — so it can't fire from someone just
///                  drawing quickly.
struct DeckView: View {
    @ObservedObject var game: SolitaireGameState
    var width: CGFloat = 88

    var body: some View {
        ZStack {
            if game.stock.isEmpty && game.phase == .playing {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    ) // overlay (dashed border on top of the fill)
                    .frame(width: width, height: width * 1.4)
            } else if !game.stock.isEmpty {
                CardView(card: Card(suit: .spades, rank: .ace, isFaceUp: false), width: width)
            } // if/else (empty stock placeholder vs. face-down deck)

            MultiTapView(
                onSingleTap: handleSingleTap,
                onDoubleTap: {}, // retired — the reshuffle cheat now lives on a 2-second long press
                onTripleTap: {}, // retired
                onLongPress: handleLongPress
            ) // MultiTapView
            .frame(width: width, height: width * 1.4)
        } // ZStack
    } // body

    private func handleSingleTap() {
        guard game.phase == .playing else { return } // setup is automatic — nothing to do before then
        game.drawThree()
    } // handleSingleTap()

    private func handleLongPress() {
        guard game.phase == .playing, CheatSettings.shared.cheatingEnabled else { return } // cheatQuietReshuffleStock() also no-ops if cheating's off; checked here too so the shuffle sound doesn't play for nothing
        game.cheatQuietReshuffleStock()
        SoundManager.shared.playShuffle(volume: CheatSettings.shared.cheatShuffleVolume)
    } // handleLongPress()
} // DeckView
