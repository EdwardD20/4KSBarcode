//
//  Views/ResultsView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Lists completed games from GameResultsStore,
//  fastest first, showing the date/time played and the length of the game.
//

import SwiftUI

struct ResultsView: View {
    @ObservedObject var resultsStore: GameResultsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if resultsStore.results.isEmpty {
                    ContentUnavailableView(
                        "No games finished yet",
                        systemImage: "trophy",
                        description: Text("Win a game and it'll show up here.")
                    ) // ContentUnavailableView
                } else {
                    List {
                        ForEach(Array(resultsStore.results.enumerated()), id: \.element.id) { index, result in
                            resultRow(rank: index + 1, result: result)
                        } // ForEach
                    } // List
                } // if/else (any results yet)
            } // Group
            .navigationTitle("Top Results")
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

    private func resultRow(rank: Int, result: GameResult) -> some View {
        HStack {
            Text("#\(rank)")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.formattedDuration)
                    .font(.body.monospacedDigit())
                Text(result.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } // VStack (duration + date)
            Spacer()
            if result.cheated {
                // Matches the chicken sound played on a cheated win — same
                // idea, just the visible badge for it here in the list.
                Text("🐔")
                    .font(.body)
                    .accessibilityLabel("Cheated")
            } // if this win involved a cheat
        } // HStack (one result row)
    } // resultRow(rank:result:)
} // ResultsView

#Preview {
    ResultsView(resultsStore: GameResultsStore())
}
