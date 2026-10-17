//
// NetworkManager.swift
//
// My original XPaddle game conceived in 2009 and was written in Objective C.
// Unfortunately the original source was lost.
//
// In 2026, I found this project on GitHub.com and adapted it back to my original game.
// Adapted from: https://github.com/rickyjonesus/pong
//

import Foundation
import MultipeerConnectivity
import UIKit
import Combine

/// Messages exchanged between the two phones during a nearby duel.
/// Kept intentionally tiny: paddle positions never need to cross the wire —
/// each phone is fully authoritative over the ball while it's on its own
/// screen, and only hands off state when the ball reaches the seam between
/// the two devices.
enum DuelMessage: Codable {
    case hello(token: String)
    case ballHandoff(yFraction: Double, vyFraction: Double, speedFraction: Double)
    case pointAgainstSender
    case rematch
}

enum DuelConnectionState: Equatable {
    case idle
    case searching
    case connected(peerName: String)
    case lost
}

/// Thin wrapper around MultipeerConnectivity that auto-discovers and
/// auto-connects to the first nearby peer running the app — no pairing
/// codes, no UI picker. Works over Bluetooth and/or Wi-Fi, so it keeps
/// working with no internet connection as long as the two phones are close.
final class NetworkManager: NSObject, ObservableObject {
    private let serviceType = "XPaddle-duel"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    @Published var state: DuelConnectionState = .idle
    var onMessage: ((DuelMessage) -> Void)?

    override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func startSearching() {
        guard state == .idle || state == .lost else { return }
        state = .searching
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        state = .idle
    }

    func send(_ message: DuelMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension NetworkManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.advertiser.stopAdvertisingPeer()
                self.browser.stopBrowsingForPeers()
                self.state = .connected(peerName: peerID.displayName)
            case .notConnected:
                if case .connected = self.state {
                    self.state = .lost
                }
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(DuelMessage.self, from: data) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onMessage?(message)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension NetworkManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension NetworkManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard session.connectedPeers.isEmpty else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
