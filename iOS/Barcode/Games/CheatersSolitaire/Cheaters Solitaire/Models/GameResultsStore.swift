//
//  Models/GameResultsStore.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Persists completed-game results (date played and
//  length of game) to disk and exposes them sorted fastest-first for the
//  top-results list.
//

import Foundation
import Combine

/// One completed, WON game: when it was played, how long it took, and
/// whether the player cheated at any point during it.
/// Stuck/abandoned games aren't recorded here — only a finished game has a
/// meaningful "length of game" worth comparing against the others.
struct GameResult: Identifiable, Codable, Equatable {
    let id: UUID
    let datePlayed: Date
    let duration: TimeInterval
    /// True if `SolitaireGameState.hasCheatedThisGame` was set by the time this win
    /// was recorded. Defaults to `false` when decoding older, pre-cheat-
    /// tracking saved results, so existing history doesn't retroactively
    /// get flagged.
    let cheated: Bool

    init(id: UUID = UUID(), datePlayed: Date, duration: TimeInterval, cheated: Bool = false) {
        self.id = id
        self.datePlayed = datePlayed
        self.duration = duration
        self.cheated = cheated
    } // init(id:datePlayed:duration:cheated:)

    private enum CodingKeys: String, CodingKey {
        case id, datePlayed, duration, cheated
    } // CodingKeys

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        datePlayed = try container.decode(Date.self, forKey: .datePlayed)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        cheated = try container.decodeIfPresent(Bool.self, forKey: .cheated) ?? false // older saved results predate this field
    } // init(from:)

    /// e.g. "2:47" — matches the in-game running timer's format.
    var formattedDuration: String {
        let totalSeconds = Int(duration.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    } // formattedDuration

    /// e.g. "Sep 9, 2026 at 3:14 PM".
    var formattedDate: String {
        datePlayed.formatted(date: .abbreviated, time: .shortened)
    } // formattedDate
} // GameResult

/// Keeps the persisted history of completed games and hands back the
/// current "top results" list — fastest completions first. One instance is
/// owned directly by `SolitaireGameState`, matching how `CheatEngine` is owned there.
final class GameResultsStore: ObservableObject {
    @Published private(set) var results: [GameResult] = []

    private let storageKey = "CheatersSolitaire.gameResults"
    private let maxStored = 10 // "Top Results" means the top 10 fastest wins, not an unbounded history

    init() {
        load()
    } // init()

    /// Records a freshly completed game and re-persists the whole list,
    /// fastest game first.
    func record(duration: TimeInterval, datePlayed: Date = Date(), cheated: Bool = false) {
        let result = GameResult(datePlayed: datePlayed, duration: duration, cheated: cheated)
        results.append(result)
        results.sort { $0.duration < $1.duration }
        if results.count > maxStored {
            results.removeLast(results.count - maxStored)
        } // if trimming the slowest overflow entries
        save()
    } // record(duration:datePlayed:cheated:)

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([GameResult].self, from: data) else {
            return
        } // guard decodable
        var sorted = decoded.sorted { $0.duration < $1.duration }
        if sorted.count > maxStored {
            sorted.removeLast(sorted.count - maxStored) // trims any pre-existing history down to the new cap
        } // if this device already had more than maxStored saved from before
        results = sorted
    } // load()

    private func save() {
        guard let data = try? JSONEncoder().encode(results) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    } // save()
} // GameResultsStore
