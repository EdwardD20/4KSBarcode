//
//  Views/CardTapView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: UIKit-backed tap gesture wrapper providing immediate single-tap response layered with double-tap auto-move, for card selection.
//

import SwiftUI

#if os(iOS)
import UIKit

/// Unlike `MultiTapView` (used for the deck, where single/double/triple are
/// mutually exclusive actions), this fires the single tap IMMEDIATELY with
/// no waiting-to-see-if-a-second-tap-comes delay. Double tap is layered on
/// top as a bonus — both recognizers fire independently on an actual double
/// tap, which is safe here because `autoMoveOnDoubleTap` is a no-op/idempotent
/// on top of whatever the single tap's select/move already did.
struct CardTapView: UIViewRepresentable {
    var onSingleTap: () -> Void
    var onDoubleTap: () -> Void
    /// Optional: when supplied, a plain tap on this card does nothing useful
    /// (see the `require(toFail:)` wiring below) and only a hold of
    /// `longPressMinimumDuration` triggers this closure. Pass `nil` (the
    /// default) for ordinary cards that should keep responding instantly —
    /// this is currently only used for face-down tableau cards, so the
    /// hidden peek/grab cheat can't be triggered by an accidental tap.
    var onLongPress: (() -> Void)? = nil
    var longPressMinimumDuration: TimeInterval = 2.0

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTapped))
        single.numberOfTapsRequired = 1
        // Deliberately NO require(toFail:) against double — single fires
        // right away even if a double follows moments later.

        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped))
        double.numberOfTapsRequired = 2

        view.addGestureRecognizer(single)
        view.addGestureRecognizer(double)

        if onLongPress != nil {
            let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPressed))
            longPress.minimumPressDuration = longPressMinimumDuration
            // A hold that reaches the long-press threshold must NOT also
            // fire as a single tap on release — require single to fail
            // (i.e. wait for the long-press recognizer to resolve) only on
            // the cards where a long-press handler exists at all. Quick
            // taps are unaffected: the long-press recognizer fails the
            // instant the finger lifts early, so single still fires right away.
            single.require(toFail: longPress)
            view.addGestureRecognizer(longPress)
        } // if this card wants a long-press-gated action

        return view
    } // makeUIView(context:)

    /// CRITICAL: SwiftUI reuses the same Coordinator instance across
    /// re-renders of this view slot — it does NOT recreate it just because
    /// `card`/`index`/`source` changed upstream (e.g. a card flipping from
    /// face-down to face-up). Without refreshing the closures here, the
    /// coordinator keeps calling whatever closure it was FIRST built with,
    /// silently acting on stale captured data forever.
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onLongPress = onLongPress
    } // updateUIView(_:context:)

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap, onDoubleTap: onDoubleTap, onLongPress: onLongPress)
    } // makeCoordinator()

    final class Coordinator: NSObject {
        var onSingleTap: () -> Void
        var onDoubleTap: () -> Void
        var onLongPress: (() -> Void)?

        init(onSingleTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
            self.onLongPress = onLongPress
        } // init(onSingleTap:onDoubleTap:onLongPress:)

        @objc func singleTapped() { onSingleTap() }
        @objc func doubleTapped() { onDoubleTap() }
        @objc func longPressed(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return } // fire once, the moment the hold threshold is crossed
            onLongPress?()
        } // longPressed(_:)
    } // Coordinator
} // CardTapView

#elseif os(macOS)
import AppKit

struct CardTapView: NSViewRepresentable {
    var onSingleTap: () -> Void
    var onDoubleTap: () -> Void
    /// Optional: see the iOS branch's doc comment above — same idea, a
    /// mouse-down held for `longPressMinimumDuration` on cards that supply
    /// this, instead of a normal click.
    var onLongPress: (() -> Void)? = nil
    var longPressMinimumDuration: TimeInterval = 2.0

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        let single = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleClicked))
        single.numberOfClicksRequired = 1
        // No manual debounce timer here (unlike MultiTapView) — this fires
        // the instant a click is recognized, with no artificial delay.

        let double = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleClicked))
        double.numberOfClicksRequired = 2

        view.addGestureRecognizer(single)
        view.addGestureRecognizer(double)

        if onLongPress != nil {
            let longPress = NSPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPressed))
            longPress.minimumPressDuration = longPressMinimumDuration
            view.addGestureRecognizer(longPress)
            // AppKit has no UIKit-style `require(toFail:)` — the equivalent
            // "hold vs. click" split is expressed through the delegate
            // callback below instead. `single.delegate` is what actually
            // asks the coordinator the question.
            single.delegate = context.coordinator
            context.coordinator.longPressRecognizer = longPress
        } // if this card wants a long-press-gated action

        return view
    } // makeNSView(context:)

    /// CRITICAL: see the iOS branch's comment above updateUIView — same
    /// stale-coordinator issue applies here. Without this, a card that
    /// flips from face-down to face-up (or moves to a new pile/index) keeps
    /// triggering logic based on its OLD state indefinitely.
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onLongPress = onLongPress
    } // updateNSView(_:context:)

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap, onDoubleTap: onDoubleTap, onLongPress: onLongPress)
    } // makeCoordinator()

    final class Coordinator: NSObject, NSGestureRecognizerDelegate {
        var onSingleTap: () -> Void
        var onDoubleTap: () -> Void
        var onLongPress: (() -> Void)?
        /// Set only when a long-press handler exists for this card — see
        /// `gestureRecognizer(_:shouldRequireFailureOf:)` below.
        weak var longPressRecognizer: NSGestureRecognizer?

        init(onSingleTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
            self.onLongPress = onLongPress
        } // init(onSingleTap:onDoubleTap:onLongPress:)

        @objc func singleClicked() { onSingleTap() }
        @objc func doubleClicked() { onDoubleTap() }
        @objc func longPressed(_ gesture: NSPressGestureRecognizer) {
            guard gesture.state == .began else { return } // fire once, the moment the hold threshold is crossed
            onLongPress?()
        } // longPressed(_:)

        /// AppKit's answer to UIKit's `require(toFail:)`: asked once per
        /// recognition attempt whether `gestureRecognizer` (here, always
        /// `single`, since that's the only one with a delegate set) must
        /// wait for `otherGestureRecognizer` to fail first. Returning true
        /// specifically for the long-press recognizer reproduces the same
        /// "hold vs. click" split as the iOS branch: a quick click still
        /// resolves the moment the long-press recognizer fails (near-
        /// instantly on early release), while a genuine 2-second hold wins
        /// outright and single never fires.
        func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: NSGestureRecognizer) -> Bool {
            otherGestureRecognizer === longPressRecognizer
        } // gestureRecognizer(_:shouldRequireFailureOf:)
    } // Coordinator
} // CardTapView
#endif
