//
//  Models/Card.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Defines Suit, Rank, and Card, plus the stacking rules used to validate tableau and foundation moves.
//

import Foundation

enum Suit: String, CaseIterable, Codable {
    case hearts, diamonds, clubs, spades

    var isRed: Bool { self == .hearts || self == .diamonds }

    var symbol: String {
        switch self {
        case .hearts: return "♥"
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .spades: return "♠"
        }
    }

    /// Used by the "suit swap" cheat consequence: red maps to the other red
    /// suit, black maps to the other black suit — color never changes.
    var swappedWithinColor: Suit {
        switch self {
        case .hearts: return .diamonds
        case .diamonds: return .hearts
        case .clubs: return .spades
        case .spades: return .clubs
        }
    }

    /// Capitalized name for building face-card asset names, e.g. "Jack-Spades".
    var name: String {
        switch self {
        case .hearts: return "Hearts"
        case .diamonds: return "Diamonds"
        case .clubs: return "Clubs"
        case .spades: return "Spades"
        }
    }
}

enum Rank: Int, CaseIterable, Codable {
    case ace = 1, two, three, four, five, six, seven, eight, nine, ten, jack, queen, king

    var label: String {
        switch self {
        case .ace: return "A"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        default: return "\(rawValue)"
        }
    }

    /// True Klondike stacking rule: descending rank.
    var isOneLessThan: (Rank) -> Bool {
        { other in self.rawValue == other.rawValue - 1 }
    }

    /// Non-nil only for face cards — used to build an asset name like
    /// "Jack-Spades" for the big center art. Number cards and the Ace
    /// (which gets a big suit symbol instead) return nil.
    var faceName: String? {
        switch self {
        case .jack: return "Jack"
        case .queen: return "Queen"
        case .king: return "King"
        default: return nil
        }
    }
}

struct Card: Identifiable, Codable, Equatable {
    let id: UUID
    var suit: Suit
    var rank: Rank
    var isFaceUp: Bool

    init(suit: Suit, rank: Rank, isFaceUp: Bool = false) {
        self.id = UUID()
        self.suit = suit
        self.rank = rank
        self.isFaceUp = isFaceUp
    }

    var isRed: Bool { suit.isRed }

    /// Cheat consequence: flips this card to the "opposite" suit of the same color.
    mutating func swapSuitWithinColor() {
        suit = suit.swappedWithinColor
    }

    /// Standard Klondike tableau stacking check: alternating color, descending rank.
    func canStack(on other: Card) -> Bool {
        other.isFaceUp &&
        isRed != other.isRed &&
        rank.rawValue == other.rank.rawValue - 1
    }

    /// Standard Klondike foundation stacking check: same suit, ascending rank.
    func canPlaceOnFoundation(topCard: Card?) -> Bool {
        guard suit == (topCard?.suit ?? suit) else { return false }
        if let top = topCard {
            return rank.rawValue == top.rank.rawValue + 1
        } else {
            return rank == .ace
        }
    }
}
