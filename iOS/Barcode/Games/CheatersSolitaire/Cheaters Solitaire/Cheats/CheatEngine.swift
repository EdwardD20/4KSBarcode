//
//  Cheats/CheatEngine.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Tracks accumulated cheat points and rolls the probabilistic consequence events (suit swap, face-down flip, critter animation) that punish cheating.
//

import Foundation
import Combine

enum SwapScope {
    case redOnly, blackOnly, both
}

enum CheatConsequence: Equatable {
    case critterAndFrog
    case suitSwap(colorsAffected: SwapScope)
    case faceDownFlip
}

/// Tracks how much the player has been cheating and decides, probabilistically,
/// when to trigger a visible consequence. Pure logic — no UI or audio here;
/// SolitaireGameState applies the game-state effect and the view layer handles animation/sound.
final class CheatEngine: ObservableObject {
    private let settings: CheatSettings
    @Published private(set) var cheatPoints: Int = 0

    init(settings: CheatSettings = .shared) {
        self.settings = settings
    }

    /// Call every time the player uses a hidden cheat (grab-any-drawn-card,
    /// peek/grab a face-down table card, peek/grab from the stock, quiet reshuffle).
    func registerCheatUsed() {
        cheatPoints += settings.cheatPointsPerAction
    }

    /// Call after each cheat-eligible action to see if a consequence should fire.
    /// Returns nil most of the time — that's expected and desired.
    func rollForConsequence() -> CheatConsequence? {
        guard cheatPoints >= settings.minimumCheatPointsForConsequence else { return nil }

        let roll = Double.random(in: 0...1)
        var cumulative = 0.0

        cumulative += settings.critterEventChance
        if roll < cumulative { return .critterAndFrog }

        cumulative += settings.suitSwapEventChance
        if roll < cumulative {
            let scope: SwapScope = [.redOnly, .blackOnly, .both].randomElement()!
            return .suitSwap(colorsAffected: scope)
        }

        cumulative += settings.faceDownFlipEventChance
        if roll < cumulative { return .faceDownFlip }

        return nil
    }

    func resetAfterConsequence() {
        cheatPoints = 0
    }
}
