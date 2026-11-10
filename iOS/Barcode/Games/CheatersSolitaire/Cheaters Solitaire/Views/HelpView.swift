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
                        title: "help_goal_title",
                        text: "help_goal_body"
                    ) // ruleSection (goal)

                    ruleSection(
                        title: "help_tableau_title",
                        text: "help_tableau_body"
                    ) // ruleSection (tableau)

                    ruleSection(
                        title: "help_foundations_title",
                        text: "help_foundations_body"
                    ) // ruleSection (foundations)

                    ruleSection(
                        title: "help_stock_title",
                        text: "help_stock_body"
                    ) // ruleSection (stock)

                    ruleSection(
                        title: "help_winning_title",
                        text: "help_winning_body"
                    ) // ruleSection (winning)

                    Divider()
                        .padding(.vertical, 4)

                    solitaireText("help_closing_line")
                        .font(.headline)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } // VStack (all rule sections)
                .padding()
            } // ScrollView
            .navigationTitle(solitaireText("help_title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { solitaireText("done") }
                } // ToolbarItem
            } // toolbar
        } // NavigationStack
    } // body

    private func ruleSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            solitaireText(title)
                .font(.headline)
            solitaireText(text)
                .font(.body)
                .foregroundStyle(.secondary)
        } // VStack (one rule section)
    } // ruleSection(title:text:)
} // HelpView

#Preview {
    HelpView()
}
