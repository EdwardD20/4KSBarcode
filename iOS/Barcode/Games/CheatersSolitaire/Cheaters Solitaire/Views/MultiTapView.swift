//
//  Views/MultiTapView.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: Native UIKit/AppKit tap-count detection used to reliably distinguish mutually exclusive single/double/triple taps on the deck.
//

import SwiftUI

#if os(iOS)
import UIKit

/// SwiftUI's `.onTapGesture(count:)` is unreliable when you need single,
/// double, AND triple tap on the same view (single tends to fire before
/// double/triple resolve). This wraps real UIKit recognizers with explicit
/// `require(toFail:)` chaining so exactly one closure fires per tap sequence.
struct MultiTapView: UIViewRepresentable {
    var onSingleTap: () -> Void
    var onDoubleTap: () -> Void
    var onTripleTap: () -> Void
    /// Optional: see `CardTapView`'s doc comment for the same pattern. Used
    /// by the deck for the quiet-reshuffle cheat, so it requires a
    /// deliberate 2-second hold rather than a double-tap that could happen
    /// by accident while trying to draw quickly.
    var onLongPress: (() -> Void)? = nil
    var longPressMinimumDuration: TimeInterval = 2.0

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true

        let triple = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tripleTapped))
        triple.numberOfTapsRequired = 3

        let double = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleTapped))
        double.numberOfTapsRequired = 2
        double.require(toFail: triple)

        let single = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleTapped))
        single.numberOfTapsRequired = 1
        single.require(toFail: double)

        view.addGestureRecognizer(triple)
        view.addGestureRecognizer(double)
        view.addGestureRecognizer(single)

        if onLongPress != nil {
            let longPress = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPressed))
            longPress.minimumPressDuration = longPressMinimumDuration
            // A 2-second hold must not ALSO resolve as a single-tap draw
            // once the finger lifts — same "hold vs. tap" split as
            // CardTapView. A quick tap is unaffected: the long-press
            // recognizer fails immediately on early release.
            single.require(toFail: longPress)
            view.addGestureRecognizer(longPress)
        } // if a long-press handler was supplied

        return view
    } // makeUIView(context:)

    /// Same stale-coordinator risk as CardTapView — refresh on every update
    /// even though this particular usage (DeckView) happens to be immune in
    /// practice, since it only calls methods that read live SolitaireGameState values.
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onTripleTap = onTripleTap
        context.coordinator.onLongPress = onLongPress
    } // updateUIView(_:context:)

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap, onDoubleTap: onDoubleTap, onTripleTap: onTripleTap, onLongPress: onLongPress)
    } // makeCoordinator()

    final class Coordinator: NSObject {
        var onSingleTap: () -> Void
        var onDoubleTap: () -> Void
        var onTripleTap: () -> Void
        var onLongPress: (() -> Void)?

        init(onSingleTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void, onTripleTap: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
            self.onTripleTap = onTripleTap
            self.onLongPress = onLongPress
        } // init(onSingleTap:onDoubleTap:onTripleTap:onLongPress:)

        @objc func singleTapped() { onSingleTap() }
        @objc func doubleTapped() { onDoubleTap() }
        @objc func tripleTapped() { onTripleTap() }
        @objc func longPressed(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return } // fire once, the moment the hold threshold is crossed
            onLongPress?()
        } // longPressed(_:)
    } // Coordinator
} // MultiTapView

#elseif os(macOS)
import AppKit

struct MultiTapView: NSViewRepresentable {
    var onSingleTap: () -> Void
    var onDoubleTap: () -> Void
    var onTripleTap: () -> Void
    /// Optional: see the iOS branch's doc comment above. A mouse-down held
    /// for `longPressMinimumDuration` fires this instead of a click.
    var onLongPress: (() -> Void)? = nil
    var longPressMinimumDuration: TimeInterval = 2.0

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)

        let triple = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tripleClicked))
        triple.numberOfClicksRequired = 3

        let double = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.doubleClicked))
        double.numberOfClicksRequired = 2

        let single = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.singleClicked))
        single.numberOfClicksRequired = 1

        // AppKit has no require(toFail:) API for NSClickGestureRecognizer, so
        // the coordinator debounces manually using a short timer window instead.
        view.addGestureRecognizer(triple)
        view.addGestureRecognizer(double)
        view.addGestureRecognizer(single)

        if onLongPress != nil {
            let longPress = NSPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.longPressed))
            longPress.minimumPressDuration = longPressMinimumDuration
            view.addGestureRecognizer(longPress)
        } // if a long-press handler was supplied

        return view
    } // makeNSView(context:)

    /// Same stale-coordinator risk as CardTapView — refresh on every update.
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onTripleTap = onTripleTap
        context.coordinator.onLongPress = onLongPress
    } // updateNSView(_:context:)

    func makeCoordinator() -> Coordinator {
        Coordinator(onSingleTap: onSingleTap, onDoubleTap: onDoubleTap, onTripleTap: onTripleTap, onLongPress: onLongPress)
    } // makeCoordinator()

    final class Coordinator: NSObject {
        var onSingleTap: () -> Void
        var onDoubleTap: () -> Void
        var onTripleTap: () -> Void
        var onLongPress: (() -> Void)?
        private var pendingWorkItem: DispatchWorkItem?
        private var pendingClickCount = 0
        /// Set while an `NSPressGestureRecognizer` hold is in progress, so
        /// the click recognizers (which AppKit still delivers on mouse-up
        /// even after a long hold) don't ALSO fire a single/double tap once
        /// the long press has already done its thing.
        private var longPressConsumedThisGesture = false

        init(onSingleTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void, onTripleTap: @escaping () -> Void, onLongPress: (() -> Void)? = nil) {
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
            self.onTripleTap = onTripleTap
            self.onLongPress = onLongPress
        } // init(onSingleTap:onDoubleTap:onTripleTap:onLongPress:)

        @objc func singleClicked() {
            guard !longPressConsumedThisGesture else { return }
            registerClick()
        } // singleClicked()
        @objc func doubleClicked() {
            guard !longPressConsumedThisGesture else { return }
            pendingClickCount = 2
            flushIfSettled()
        } // doubleClicked()
        @objc func tripleClicked() {
            guard !longPressConsumedThisGesture else { return }
            pendingWorkItem?.cancel()
            onTripleTap()
            pendingClickCount = 0
        } // tripleClicked()
        @objc func longPressed(_ gesture: NSPressGestureRecognizer) {
            switch gesture.state {
            case .began:
                longPressConsumedThisGesture = true
                pendingWorkItem?.cancel() // cancel any pending single/double click resolution
                pendingClickCount = 0
                onLongPress?()
            case .ended, .cancelled, .failed:
                longPressConsumedThisGesture = false
            default:
                break
            } // switch
        } // longPressed(_:)

        private func registerClick() {
            pendingClickCount = max(pendingClickCount, 1)
            flushIfSettled()
        } // registerClick()

        private func flushIfSettled() {
            pendingWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                guard let self else { return }
                if self.pendingClickCount >= 2 { self.onDoubleTap() } else { self.onSingleTap() }
                self.pendingClickCount = 0
            } // DispatchWorkItem
            pendingWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + NSEvent.doubleClickInterval, execute: item)
        } // flushIfSettled()
    } // Coordinator
} // MultiTapView
#endif
