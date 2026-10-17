//
//  CheatersSolitaireApp.swift
//  Cheaters Solitaire
//
//  Created by Ed Danley on 09/09/26.
//
//  This file accomplishes: App entry point for the shared iOS/macOS target; locks iPhone to portrait + landscape (excluding upside-down) via AppDelegate while leaving iPad unrestricted.
//

import SwiftUI

#if os(iOS)
import UIKit

/// Locks orientation on iPhone specifically to portrait and both landscapes
/// (excluding upside-down portrait, which iPhone apps conventionally skip),
/// while leaving iPad free to rotate to anything. This can't be done with a
/// single static Info.plist setting alone, since that can't distinguish
/// device idiom at runtime — this hook can. NOTE: your Xcode target's
/// "Supported Interface Orientations" for iPhone needs Portrait AND
/// Landscape Left/Right all checked — this delegate is what actually
/// restricts orientation at runtime, but it can't grant an orientation the
/// project itself doesn't declare support for.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all // iPad: unrestricted
        } else {
            return [.portrait, .landscapeLeft, .landscapeRight] // iPhone: no upside-down portrait
        } // if/else
    } // application(_:supportedInterfaceOrientationsFor:)
} // AppDelegate
#endif

@main
struct CheatersSolitaireApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            SolitaireContentView()
                // Respects the system light/dark setting automatically since
                // no .preferredColorScheme override is set — remove this
                // comment's assumption only if you want to force a mode.
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 750)
        #endif
    } // body
} // CheatersSolitaireApp
