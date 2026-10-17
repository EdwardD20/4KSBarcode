//
//  Views/GameTimerView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Displays how long the current game has taken so
//  far — ticking live once a second while playing, and freezing at the
//  final time once the game is won or stuck (see SolitaireGameState.gameEndDate).
//

import SwiftUI

struct GameTimerView: View {
    @ObservedObject var game: SolitaireGameState

    /// Once the player's first cheat of the game lands, the timer flips to
    /// an inverted "badge" look — foreground and background swapped — as a
    /// quiet, persistent tell that this game is no longer a clean one. Stays
    /// that way for the rest of the game; a fresh `startNewGame()` resets
    /// `hasCheatedThisGame` back to false, and the timer with it.
    private var hasCheated: Bool { game.hasCheatedThisGame }

    var body: some View {
        Group {
            if let start = game.gameStartDate {
                if let end = game.gameEndDate {
                    Text(Self.format(end.timeIntervalSince(start))) // frozen — game's over
                } else {
                    TimelineView(.periodic(from: start, by: 1)) { context in
                        Text(Self.format(context.date.timeIntervalSince(start)))
                    } // TimelineView (ticks once a second while play continues)
                } // if/else (frozen vs. live)
            } else {
                Text("0:00") // no game started yet
            } // if/else (has a game even started)
        } // Group
        .font(.callout.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6) // shrink-to-fit belt-and-braces, in case some size still doesn't fit the toolbar's chip
        // This sits in a fixed-height nav bar/toolbar chip, not free-flowing
        // text — at the accessibility Dynamic Type sizes (AX1–AX5, which are
        // dramatically larger than the standard range) that chip doesn't
        // grow to match, so the enlarged text simply gets clipped rather
        // than shown. Capping growth at .accessibility1 keeps the timer
        // legibly larger for anyone using bigger text, without letting it
        // outgrow the toolbar chrome it's fixed inside. This matches Apple's
        // own guidance for compact, fixed-size chrome like nav bar items.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // Normal: plain secondary-colored text, no fill, matching the toolbar
        // around it. Cheated: text becomes the BACKGROUND-colored style, sat
        // on a primary-colored capsule — the same two colors, deliberately
        // swapped, rather than an unrelated new color, so it reads as "the
        // timer itself flipped" rather than "the timer changed color."
        .foregroundStyle(hasCheated ? AnyShapeStyle(.background) : AnyShapeStyle(.secondary))
        .padding(.horizontal, hasCheated ? 8 : 0)
        .padding(.vertical, hasCheated ? 2 : 0)
        .background {
            if hasCheated {
                Capsule().fill(Color.primary)
            } // if
        } // background
        .animation(.easeInOut(duration: 0.3), value: hasCheated)
        .accessibilityLabel("Elapsed game time")
    } // body

    private static func format(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    } // format(_:)
} // GameTimerView

#Preview {
    GameTimerView(game: SolitaireGameState())
}
