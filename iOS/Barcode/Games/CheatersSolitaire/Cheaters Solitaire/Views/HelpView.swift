//
//  Views/HelpView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: In-app help/rules screen covering standard Klondike rules only, with no mention of the hidden cheats.
//

import SwiftUI

/// Standard Klondike rules only — deliberately does NOT explain any of the
/// hidden cheats. The closing line is the one and only hint the game ever
/// gives that something's off.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ruleSection(
                        title: "Goal",
                        text: "Move every card onto the four foundation piles, one per suit, built up in order from Ace to King."
                    ) // ruleSection (goal)

                    ruleSection(
                        title: "Tableau",
                        text: "Build down in alternating colors — a red 9 can hold a black 8, for example. A run of cards in the right order can be moved together. Only a King can start an empty column."
                    ) // ruleSection (tableau)

                    ruleSection(
                        title: "Foundations",
                        text: "Each pile starts with an Ace and builds upward by suit: Ace, 2, 3, and so on, up to King. Double-tap a card to send it straight to its foundation if it's eligible."
                    ) // ruleSection (foundations)

                    ruleSection(
                        title: "The stock",
                        text: "Tap the deck to draw three cards at a time. Once you've gone through the whole deck, tapping again reshuffles the drawn pile back into the stock."
                    ) // ruleSection (stock)

                    ruleSection(
                        title: "Winning",
                        text: "You've won once every card is resting on a foundation, in order, by suit."
                    ) // ruleSection (winning)

                    Divider()
                        .padding(.vertical, 4)

                    Text("If you can cheat, then so can I.")
                        .font(.headline)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } // VStack (all rule sections)
                .padding()
            } // ScrollView
            .navigationTitle("How to Play")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                } // ToolbarItem
            } // toolbar
        } // NavigationStack
    } // body

    private func ruleSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        } // VStack (one rule section)
    } // ruleSection(title:text:)
} // HelpView

#Preview {
    HelpView()
}
