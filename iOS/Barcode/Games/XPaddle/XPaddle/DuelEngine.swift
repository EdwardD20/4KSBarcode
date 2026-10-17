//
// DuelEngine.swift
//
// My original XPaddle game conceived in 2009 and was written in Objective C.
// Unfortunately the original source was lost.
//
// In 2026, I found this project on GitHub.com and adapted it back to my original game.
// Adapted from: https://github.com/rickyjonesus/pong
//

import SwiftUI
import Combine
import AudioToolbox

enum DuelPhase {
    case connecting
    case connectionLost
    case serving        // it's this device's turn to serve
    case waitingForBall // ball is currently on the opponent's screen
    case playing         // ball is currently on this device's screen
    case gameOver
}

/// Drives a two-device XPaddle match over MultipeerConnectivity. Each phone
/// renders and simulates only its own half of the court — there is no
/// shared "world state" beyond the ball's flight, which is handed from one
/// device to the other the instant it reaches the seam where the phones
/// are held together. Whoever currently "has" the ball is fully
/// authoritative over its physics until it either bounces back across the
/// seam or gets missed.
final class DuelEngine: ObservableObject {
    static let winningScore = 11

    let paddleWidth: CGFloat = 14
    let paddleHeight: CGFloat = 90
    let ballSize: CGFloat = 16
    let paddleSpeed: CGFloat = 620
    let baseBallSpeed: CGFloat = 380
    let maxBallSpeed: CGFloat = 900
    let paddleMargin: CGFloat = 28

    private let net = NetworkManager()
    private let myToken = UUID().uuidString
    private var peerToken: String?
    private var helloTimer: Timer?
    private var helloAttempts = 0

    @Published var phase: DuelPhase = .connecting
    @Published var connectionLabel: String = "Searching for nearby iPhone…"
    @Published private(set) var isLeftSide: Bool = true

    @Published var courtSize: CGSize = .zero
    private var safeAreaLeading: CGFloat = 0
    private var safeAreaTrailing: CGFloat = 0

    @Published var paddleY: CGFloat = 0
    @Published var ballPos: CGPoint = .zero
    @Published var ballVisible: Bool = false

    @Published var localScore: Int = 0
    @Published var opponentScore: Int = 0
    @Published var winnerIsMe: Bool?

    /// Set from the drag gesture; nil until the player first touches the court.
    var paddleTarget: CGFloat?

    private var ballVelocity: CGVector = .zero
    private var lastTick: Date?
    private var cancellables = Set<AnyCancellable>()

    // for: playMySound
    private var soundEnabled = true
    private var soundIDs: [String: SystemSoundID] = [:]

    var paddleX: CGFloat {
        isLeftSide ? paddleMargin + safeAreaLeading : courtSize.width - paddleMargin - safeAreaTrailing
    }

    init() {
        net.onMessage = { [weak self] message in self?.handle(message) }
        net.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.handleConnectionState(state) }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func start() {
        phase = .connecting
        connectionLabel = "Searching for nearby iPhone…"
        localScore = 0
        opponentScore = 0
        winnerIsMe = nil
        ballVisible = false
        peerToken = nil
        net.startSearching()
    }

    func stop() {
        helloTimer?.invalidate()
        net.stop()
    }

    func configureCourt(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let first = courtSize == .zero
        courtSize = size
        if first { paddleY = size.height / 2 }
    }

    func configureSafeArea(leading: CGFloat, trailing: CGFloat) {
        safeAreaLeading = leading
        safeAreaTrailing = trailing
    }

    // MARK: - Connection & handshake

    private func handleConnectionState(_ state: DuelConnectionState) {
        switch state {
        case .idle:
            break
        case .searching:
            connectionLabel = "Searching for nearby iPhone…"
        case .connected(let name):
            connectionLabel = "Connected to \(name) — syncing…"
            beginHandshake()
        case .lost:
            helloTimer?.invalidate()
            phase = .connectionLost
        }
    }

    /// Both phones pick a random token and trade it; whichever token sorts
    /// first becomes the "left" screen. Neither player has to choose a side.
    private func beginHandshake() {
        helloAttempts = 0
        sendHello()
        helloTimer?.invalidate()
        helloTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            guard self.peerToken == nil, self.helloAttempts < 6 else {
                timer.invalidate()
                return
            }
            self.helloAttempts += 1
            self.sendHello()
        }
    }

    private func sendHello() {
        net.send(.hello(token: myToken))
    }

    private func handle(_ message: DuelMessage) {
        switch message {
        case .hello(let token):
            guard peerToken == nil else { return }
            peerToken = token
            helloTimer?.invalidate()
            isLeftSide = myToken < token
            paddleY = courtSize.height / 2
            phase = isLeftSide ? .serving : .waitingForBall
        case .ballHandoff(let yFraction, let vyFraction, let speedFraction):
            receiveBall(yFraction: yFraction, vyFraction: vyFraction, speedFraction: speedFraction)
        case .pointAgainstSender:
            localScore += 1
            resolveRound(iConceded: false)
        case .rematch:
            beginRematch(sendMessage: false)
        }
    }

    // MARK: - Serve

    func serve() {
        guard phase == .serving, courtSize != .zero else { return }
        let angle = CGFloat.random(in: -0.3...0.3)
        let dir: CGFloat = isLeftSide ? 1 : -1 // always serve toward the seam, into the opponent's court
        ballVelocity = CGVector(dx: cos(angle) * baseBallSpeed * dir, dy: sin(angle) * baseBallSpeed)
        ballPos = CGPoint(x: courtSize.width / 2, y: courtSize.height / 2)
        ballVisible = true
        phase = .playing
        playMySound("WallHit")
    }

    // MARK: - Game loop

    func tick(now: Date) {
        defer { lastTick = now }
        guard phase == .playing, courtSize != .zero else {
            lastTick = now
            return
        }
        let dt = min(lastTick.map { now.timeIntervalSince($0) } ?? 1.0 / 60.0, 1.0 / 30.0)
        updatePaddle(dt: dt)
        updateBall(dt: dt)
    }

    private func updatePaddle(dt: TimeInterval) {
        guard let target = paddleTarget, courtSize != .zero else { return }
        let half = paddleHeight / 2
        let minY = half
        let maxY = courtSize.height - half
        let maxDelta = paddleSpeed * CGFloat(dt)
        let delta = max(-maxDelta, min(maxDelta, target - paddleY))
        paddleY = min(maxY, max(minY, paddleY + delta))
    }

    private func updateBall(dt: TimeInterval) {
        var pos = ballPos
        var vel = ballVelocity
        pos.x += vel.dx * CGFloat(dt)
        pos.y += vel.dy * CGFloat(dt)
        let half = ballSize / 2

        // Top / bottom walls
        if pos.y - half < 0 {
            pos.y = half
            vel.dy = abs(vel.dy)
            playMySound("WallHit")
        } else if pos.y + half > courtSize.height {
            pos.y = courtSize.height - half
            vel.dy = -abs(vel.dy)
            playMySound("WallHit")
        }

        // This device's own paddle, at the outer wall
        let px = paddleX
        let movingTowardPaddle = isLeftSide ? vel.dx < 0 : vel.dx > 0
        let withinPaddleX = isLeftSide
            ? (pos.x - half <= px + paddleWidth / 2 && pos.x - half >= px - paddleWidth / 2)
            : (pos.x + half >= px - paddleWidth / 2 && pos.x + half <= px + paddleWidth / 2)
        let withinPaddleY = pos.y >= paddleY - paddleHeight / 2 - half && pos.y <= paddleY + paddleHeight / 2 + half

        if movingTowardPaddle, withinPaddleX, withinPaddleY {
            pos.x = isLeftSide ? px + paddleWidth / 2 + half : px - paddleWidth / 2 - half
            vel = bounced(vel: vel, ballY: pos.y)
            playMySound("WallHit")
        }

        // Seam edge (touching the other phone) — hand the ball off
        let approachingSeam = isLeftSide ? vel.dx > 0 : vel.dx < 0
        let reachedSeam = isLeftSide ? pos.x + half >= courtSize.width : pos.x - half <= 0
        if approachingSeam, reachedSeam {
            handOffBall(vel: vel, y: pos.y)
            return
        }

        // Outer wall — this player missed it, opponent scores
        if isLeftSide ? pos.x < -ballSize : pos.x > courtSize.width + ballSize {
            missedPoint()
            return
        }

        ballPos = pos
        ballVelocity = vel
    }

    private func bounced(vel: CGVector, ballY: CGFloat) -> CGVector {
        let relative = max(-1, min(1, (ballY - paddleY) / (paddleHeight / 2)))
        let bounceAngle = relative * (.pi / 3)
        let speed = min(maxBallSpeed, hypot(vel.dx, vel.dy) * 1.06)
        let dir: CGFloat = isLeftSide ? 1 : -1
        return CGVector(dx: cos(bounceAngle) * speed * dir, dy: sin(bounceAngle) * speed)
    }

    private func handOffBall(vel: CGVector, y: CGFloat) {
        let yFraction = Double(y / courtSize.height)
        let vyFraction = Double(vel.dy / courtSize.height)
        let speedFraction = Double(hypot(vel.dx, vel.dy) / courtSize.width)
        net.send(.ballHandoff(yFraction: yFraction, vyFraction: vyFraction, speedFraction: speedFraction))
        ballVisible = false
        phase = .waitingForBall
    }

    private func receiveBall(yFraction: Double, vyFraction: Double, speedFraction: Double) {
        guard courtSize != .zero else { return }
        let y = CGFloat(yFraction) * courtSize.height
        let vy = CGFloat(vyFraction) * courtSize.height
        let speed = CGFloat(speedFraction) * courtSize.width
        let vx = (isLeftSide ? -1 : 1) * sqrt(max(0, speed * speed - vy * vy))
        ballPos = CGPoint(x: isLeftSide ? courtSize.width - ballSize / 2 : ballSize / 2, y: y)
        ballVelocity = CGVector(dx: vx, dy: vy)
        ballVisible = true
        phase = .playing
        playMySound("WallHit")
    }

    // MARK: - Scoring

    private func missedPoint() {
        ballVisible = false
        opponentScore += 1
        net.send(.pointAgainstSender)
        resolveRound(iConceded: true)
    }

    private func resolveRound(iConceded: Bool) {
        if localScore >= Self.winningScore || opponentScore >= Self.winningScore {
            winnerIsMe = localScore > opponentScore
            phase = .gameOver
            return
        }
        // The side that conceded the last point serves next.
        phase = iConceded ? .serving : .waitingForBall
    }

    // MARK: - Rematch

    func requestRematch() {
        net.send(.rematch)
        beginRematch(sendMessage: true)
    }

    private func beginRematch(sendMessage: Bool) {
        localScore = 0
        opponentScore = 0
        winnerIsMe = nil
        ballVisible = false
        paddleY = courtSize.height / 2
        phase = isLeftSide ? .serving : .waitingForBall
    }

//    private func playSound(_ id: SystemSoundID) {
//        guard soundEnabled else { return }
//        AudioServicesPlaySystemSound(id)
//    }
//
    private func playMySound(_ name: String, extension ext: String = "wav") {
        guard soundEnabled else { return }

        if let existingID = soundIDs[name] {
            AudioServicesPlaySystemSound(existingID)
            return
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Missing sound file: \(name).\(ext)")
            return
        }

        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        soundIDs[name] = soundID
        AudioServicesPlaySystemSound(soundID)
    }
}
