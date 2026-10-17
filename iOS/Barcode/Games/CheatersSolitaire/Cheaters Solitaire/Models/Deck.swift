//
//  Models/Deck.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Builds and shuffles the 52-card deck used to start a new game.
//

import Foundation

struct Deck {
    private(set) var cards: [Card]

    /// Fresh, ordered 52-card deck.
    init() {
        cards = Suit.allCases.flatMap { suit in
            Rank.allCases.map { rank in Card(suit: suit, rank: rank) }
        }
    }

    /// Wrap an existing set of cards (e.g. the current stock) so it can be reshuffled.
    init(cards: [Card]) {
        self.cards = cards
    }

    mutating func shuffle() {
        cards.shuffle()
    }

    /// Draws from the "top" of the deck, defined as the end of the array.
    mutating func draw(_ count: Int = 1) -> [Card] {
        let n = min(count, cards.count)
        let drawn = Array(cards.suffix(n))
        cards.removeLast(n)
        return drawn
    }

    var isEmpty: Bool { cards.isEmpty }
    var count: Int { cards.count }
}
