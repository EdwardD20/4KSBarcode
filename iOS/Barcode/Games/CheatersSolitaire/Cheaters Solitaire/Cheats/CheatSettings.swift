//
//  Cheats/CheatSettings.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Developer-tunable, published probabilities and volumes that drive the cheat detection and consequence system.
//

import Foundation
import Combine

/// Central, developer-tunable configuration for hidden cheats and their
/// visible "consequences" (critter/frog events, suit swaps, face-down flips).
/// Ship with sane defaults and adjust during playtesting — nothing here is
/// ever surfaced in the UI.
final class CheatSettings: ObservableObject {
    static let shared = CheatSettings()

    /// Master switch for the entire hidden-cheat system. Every cheat entry
    /// point (non-top waste selection, face-down tableau peek/grab, quiet
    /// stock reshuffle, and the stock-only peek/grab helpers) checks this
    /// before doing anything — flip it off and the game plays as an
    /// honest, by-the-rules Klondike with no hidden mechanics at all.
    /// Defaults to on; nothing in the UI surfaces this yet.
    @Published var cheatingEnabled: Bool = true

    /// How many "cheat points" one hidden-cheat action adds to the running total.
    @Published var cheatPointsPerAction: Int = 1

    /// Minimum accumulated cheat points before ANY consequence can fire.
    @Published var minimumCheatPointsForConsequence: Int = 3

    /// Chance (0...1) a consequence roll resolves to the critter+frog event.
    @Published var critterEventChance: Double = 0.20

    /// Chance (0...1) a consequence roll resolves to a suit swap.
    @Published var suitSwapEventChance: Double = 0.12

    /// Chance (0...1) a consequence roll resolves to a face-down flip.
    @Published var faceDownFlipEventChance: Double = 0.15

    // Remaining probability mass (1 - sum of the above) is "nothing happens."

    /// Playback volume for the loud, visible shuffle (deck pickup -> shuffle).
    @Published var normalShuffleVolume: Float = 1.0

    /// Playback volume for the quiet, hidden triple-tap reshuffle cheat.
    @Published var cheatShuffleVolume: Float = 0.35

    /// Playback volume for the "no moves left" foghorn cue — deliberately soft.
    @Published var stuckForeghornVolume: Float = 0.4
}
