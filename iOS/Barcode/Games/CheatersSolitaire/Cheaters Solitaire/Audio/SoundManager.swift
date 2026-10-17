//
//  Audio/SoundManager.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Loads and plays the game's loose .m4a sound effects (shuffle, croak, ribbit, frog snap) via AVAudioPlayer.
//

import AVFoundation

/// Thin wrapper around AVAudioPlayer. Drop your audio files into the app
/// bundle with these exact names (any AVFoundation-supported format; .caf
/// or .m4a recommended for size) and this will pick them up automatically.
///
/// Expected assets:
///   shuffle.m4a       — used for both the loud intro shuffle and the quiet
///                        triple-tap cheat reshuffle (volume differs per call)
///   croak_deep.m4a    — suit-swap consequence
///   ribbit.m4a        — face-down-flip consequence
///   frog_snap.m4a     — frog catching the bug/critter
///   FogHorn.m4a       — played softly when the stock is empty and no legal
///                        move remains anywhere
///   applause.m4a      — played once every card reaches its foundation (win)
///   chicken.m4a       — played on every single cheat move (see
///                        SolitaireGameState.cheatEventCount)
final class SoundManager {
    static let shared = SoundManager()

    private var players: [String: AVAudioPlayer] = [:]

    /// EVERY audio call — session setup, player creation, `prepareToPlay()`,
    /// and `play()` — runs on this one serial queue, never on the main
    /// thread. Two things this buys us, together:
    ///   1. It's what actually silences the "AVAudioSession Hang Risk"
    ///      warning. Just dispatching `configureAudioSession()` off the main
    ///      thread (the previous approach) wasn't enough on its own: if a
    ///      sound played before that background block finished, `AVAudioPlayer`
    ///      would fall back to configuring the session ITSELF, synchronously,
    ///      on whatever thread called `play()` — the main thread, since
    ///      that's where game code calls `playX()`. Moving `play()` here too
    ///      closes that gap.
    ///   2. Because it's a SERIAL queue, FIFO ordering is guaranteed: the
    ///      session-activation work enqueued in `init()` always finishes
    ///      before any later `playX()` call's work even starts, with no
    ///      manual "wait for setup" bookkeeping needed.
    /// `AVAudioPlayer` doesn't require the main thread for any of this —
    /// playback itself proceeds independently of whatever thread `play()`
    /// was called from.
    private let audioQueue = DispatchQueue(label: "com.cheaterssolitaire.audio", qos: .userInitiated)

    private init() {
        configureAudioSession()
    } // init()

    /// Explicitly sets up and activates the shared audio session ONCE, up
    /// front, on `audioQueue`. See `audioQueue`'s doc comment for why this
    /// alone isn't sufficient by itself — every subsequent audio call also
    /// has to go through the same queue.
    ///
    /// NOTE: `AVAudioSession` also has a newer `activate(options:
    /// completionHandler:)` that's async by design rather than by manual
    /// dispatch — genuinely nicer once it's available, but it requires
    /// iOS 27, well past this project's iOS 17 deployment target, so this
    /// sticks with the classic `setActive(true)` API and just keeps it off
    /// the main thread by hand instead.
    ///
    /// `.soloAmbient` matches the system's own default category (i.e. what
    /// was already in effect before this existed) — chosen so this purely
    /// silences the warning without changing how the game's sounds
    /// currently behave alongside other audio or the silent switch.
    ///
    /// iOS-only: `AVAudioSession` isn't part of the macOS SDK — AVAudioPlayer
    /// there has no equivalent session-activation step to preempt.
    private func configureAudioSession() {
        #if os(iOS)
        audioQueue.async {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.soloAmbient)
                try session.setActive(true)
            } catch {
                print("SoundManager: failed to configure audio session: \(error)")
            } // do/catch
        } // async — never touches the main thread
        #endif
    } // configureAudioSession()

    /// MUST only be called from within a block already running on
    /// `audioQueue` — see that property's doc comment. `AVAudioPlayer(contentsOf:)`
    /// and `prepareToPlay()` are exactly the two calls that can trigger an
    /// implicit, synchronous audio-session activation if one hasn't happened
    /// yet, so keeping this off the main thread is the whole point.
    private func player(named name: String, ext: String = "m4a") -> AVAudioPlayer? {
        if let cached = players[name] {
            return cached
        } // if let cached

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("SoundManager: missing audio asset \(name).\(ext) — check target membership / Copy Bundle Resources.")
            return nil
        } // guard let url

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.prepareToPlay()
            players[name] = p
            return p
        } catch {
            print("SoundManager: AVAudioPlayer failed to load \(name).\(ext): \(error)")
            return nil
        } // do/catch
    } // player(named:ext:)

    func playShuffle(volume: Float) {
        play("shuffle", volume: volume)
    }

    func playDeepCroak() {
        play("croak_deep", volume: 1.0)
    }

    func playRibbit() {
        play("ribbit", volume: 1.0)
    }

    func playFrogSnap() {
        play("frog_snap", volume: 1.0)
    }

    func playFoghorn(volume: Float) {
        play("FogHorn", volume: volume)
    }

    func playApplause(volume: Float = 1.0) {
        play("applause", volume: volume)
    }

    /// Plays on every single cheat move — see the `game.cheatEventCount`
    /// handler in SolitaireContentView.
    func playChicken(volume: Float = 1.0) {
        play("chicken", volume: volume)
    }

    /// Callable from any thread (the `playX()` wrappers above are all
    /// called from SwiftUI view code on the main thread, same as before) —
    /// this just hands the actual work off to `audioQueue` instead of doing
    /// it right here on the caller's thread.
    private func play(_ name: String, volume: Float) {
        audioQueue.async { [weak self] in
            guard let self, let p = self.player(named: name) else { return }
            p.volume = volume
            p.currentTime = 0
            p.play()
        } // async — player creation/prepareToPlay/play all happen off the main thread
    } // play(_:volume:)
}
