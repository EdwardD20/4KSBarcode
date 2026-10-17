//
//  Models/DealerAppearance.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Randomizes the on-screen dealer hand's handedness/gender combination; cosmetic only, not part of the cheat system.
//

import Foundation

/// Rolled once per new game. Neither property is a cheat signal — both are
/// purely cosmetic and randomized so the dealer doesn't feel identical every game.
enum DealerHandedness: CaseIterable, Equatable {
    case rightHanded  // majority of games
    case leftHanded   // roughly 1 in 3 games, per design spec

    static func randomForNewGame() -> DealerHandedness {
        Double.random(in: 0...1) < (1.0 / 3.0) ? .leftHanded : .rightHanded
    }
}

enum DealerGender: CaseIterable, Equatable {
    case masculine // larger hand asset
    case feminine  // smaller, slimmer hand asset

    static func randomForNewGame() -> DealerGender {
        Bool.random() ? .masculine : .feminine
    }
}

enum HandSide: Equatable { case left, right }

enum HandGesture: String {
    case resting
    case pickingUpDeck
    case holdingDeck
    case dealing
    case drawingThree
    case pointingAtCard
}

/// Bundles the two randomized-but-not-a-cheat visual choices made once per new game,
/// and resolves them to concrete asset names.
struct DealerAppearance {
    let handedness: DealerHandedness
    let gender: DealerGender

    static func rollNew() -> DealerAppearance {
        DealerAppearance(handedness: .randomForNewGame(), gender: .randomForNewGame())
    }

    /// The hand that starts holding / dealing the deck.
    var dealingHandSide: HandSide {
        handedness == .rightHanded ? .right : .left
    }

    /// The hand that ends up resting with the remaining stock after the deal.
    var restingHandSide: HandSide {
        handedness == .rightHanded ? .left : .right
    }

    /// Swap in your real Assets.xcassets image names here. Keep separate
    /// image sets per gesture so animations can crossfade/transition cleanly.
    func imageName(for side: HandSide, gesture: HandGesture) -> String {
        let genderPart = gender == .masculine ? "hand_m" : "hand_f"
        let sidePart = side == .left ? "left" : "right"
        return "\(genderPart)_\(sidePart)_\(gesture.rawValue)"
    }
}
