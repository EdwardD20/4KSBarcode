//
// GameEngine.swift
//
// My original XPaddle game conceived in 2009 and was written in Objective C.
// Unfortunately the original source was lost.
//
// In 2026, I found this project on GitHub.com and adapted it back to my original game.
// Adapted from: https://github.com/rickyjonesus/pong
//

import SwiftUI
import AudioToolbox
import Combine

enum XPaddleGamePhase {
    case menu
    case serving
    case playing
    case pointScored
    case gameOver
} // enum XPaddleGamePhase

final class GameEngine: ObservableObject {

    // MARK: - Tunables
    static let winningScore = 11
    static let blackHoleDiameter: CGFloat = 67.2
    let paddleWidth: CGFloat = 14
    let paddleHeight: CGFloat = 90
    let ballSize: CGFloat = 32
    let paddleSpeed: CGFloat = 512   // AI max speed, points/sec
    let baseBallSpeed: CGFloat = 380
    let maxBallSpeed: CGFloat = 900

    // MARK: - Published state
    @Published var phase: XPaddleGamePhase = .menu
    @Published var twoPlayerMode: Bool = false

    @Published var courtSize: CGSize = .zero
    @Published var safeAreaLeading: CGFloat = 0
    @Published var safeAreaTrailing: CGFloat = 0

    /// True when the device is portrait. The physics/model below always
    /// operate in "logical" landscape space (x = axis the ball travels
    /// between paddles, y = axis a paddle slides along); the view is
    /// responsible for transposing that onto the screen when this is true.
    @Published private(set) var isPortrait: Bool = false

    /// Paddle margin from the screen edge, pushed inward past the notch / Dynamic Island cutout when present.
    let paddleMargin: CGFloat = 60
    var leftPaddleX: CGFloat { paddleMargin + safeAreaLeading }
    var rightPaddleX: CGFloat { courtSize.width - paddleMargin - safeAreaTrailing }

    @Published var leftPaddleY: CGFloat = 0
    @Published var rightPaddleY: CGFloat = 0
    @Published var ballPos: CGPoint = .zero
    @Published private(set) var ballMouthOpenUntil: Date? = nil
    @Published private(set) var blackHolePosition: CGPoint? = nil
    @Published private(set) var isBallHidden = false

    @Published var leftScore: Int = 0
    @Published var rightScore: Int = 0
    @Published var winner: String? = nil

    // internal physics
    private var ballVelocity: CGVector = .zero
    private var servingToRight: Bool = true
    private var lastTick: Date? = nil

    // targets set by touch input; nil = no active touch (AI or idle)
    var leftPaddleTarget: CGFloat? = nil
    var rightPaddleTarget: CGFloat? = nil

    private var soundEnabled = true
    private var smarterAI = false
    @Published private(set) var blackHoleEnabled = false
    private var blackHoleHiddenUntil: Date? = nil
    private var blackHoleExitVelocity: CGVector? = nil
    private var blackHoleEntrySpeed: CGFloat? = nil

    // for: playMySound
    private var soundIDs: [String: SystemSoundID] = [:]

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - rawSize: the actual screen/canvas size, in real screen orientation.
    ///   - isPortrait: whether the device is currently portrait. The view
    ///     decides this (from the same GeometryReader size) so there's one
    ///     source of truth shared with its rendering transform.
    func configureCourt(_ rawSize: CGSize, isPortrait: Bool) {
        guard rawSize.width > 0, rawSize.height > 0 else { return } // guard rawSize.width > 0, rawSize.height > 0
        self.isPortrait = isPortrait
        // Logical space always has x = ball-travel axis, y = paddle axis.
        // In portrait those are swapped relative to the real screen.
        let size = isPortrait ? CGSize(width: rawSize.height, height: rawSize.width) : rawSize

        let firstTime = courtSize == .zero
        let previousSize = courtSize
        courtSize = size

        if firstTime {
            leftPaddleY = size.height / 2
            rightPaddleY = size.height / 2
            ballPos = CGPoint(x: size.width / 2, y: size.height / 2)
            if blackHoleEnabled { chooseBlackHolePosition() }
        } else if previousSize != size {
            // Rotating (or resizing) mid-game: rescale existing positions
            // proportionally instead of leaving them stranded out of bounds.
            if previousSize.width > 0 { ballPos.x *= size.width / previousSize.width } // if previousSize.width > 0
            if previousSize.height > 0 {
                ballPos.y *= size.height / previousSize.height
                let ratio = size.height / previousSize.height
                leftPaddleY *= ratio
                rightPaddleY *= ratio
            } // if previousSize.height > 0
            let half = paddleHeight / 2
            leftPaddleY = min(size.height - half, max(half, leftPaddleY))
            rightPaddleY = min(size.height - half, max(half, rightPaddleY))
            if let hole = blackHolePosition, previousSize.width > 0, previousSize.height > 0 {
                blackHolePosition = CGPoint(x: hole.x * size.width / previousSize.width,
                                            y: hole.y * size.height / previousSize.height)
            }
        } // if firstTime / else if previousSize != size
    } // configureCourt

    func configureSafeArea(leading: CGFloat, trailing: CGFloat) {
        safeAreaLeading = leading
        safeAreaTrailing = trailing
    } // configureSafeArea

    func configureOptions(soundEnabled: Bool, smarterAI: Bool, blackHole: Bool) {
        self.soundEnabled = soundEnabled
        self.smarterAI = smarterAI
        if self.blackHoleEnabled != blackHole {
            self.blackHoleEnabled = blackHole
            if blackHole {
                chooseBlackHolePosition()
            } else {
                blackHolePosition = nil
                blackHoleHiddenUntil = nil
                blackHoleExitVelocity = nil
                blackHoleEntrySpeed = nil
                isBallHidden = false
            }
        }
    }

    private func chooseBlackHolePosition() {
        guard courtSize.width > 0, courtSize.height > 0 else { return }
        // The middle quarter on each axis keeps the hole in the central 1/4 area.
        blackHolePosition = CGPoint(
            x: CGFloat.random(in: courtSize.width * 0.375...courtSize.width * 0.625),
            y: CGFloat.random(in: courtSize.height * 0.375...courtSize.height * 0.625)
        )
    }

    func startGame(twoPlayer: Bool) {
        twoPlayerMode = twoPlayer
        leftScore = 0
        rightScore = 0
        winner = nil
        resetPositions()
        if blackHoleEnabled { chooseBlackHolePosition() }
        servingToRight = Bool.random()
        phase = .serving
    } // startGame

    func backToMenu() {
        isBallHidden = false
        blackHoleHiddenUntil = nil
        blackHoleExitVelocity = nil
        blackHoleEntrySpeed = nil
        blackHolePosition = nil
        phase = .menu
    } // backToMenu

    private func resetPositions() {
        leftPaddleY = courtSize.height / 2
        rightPaddleY = courtSize.height / 2
        ballPos = CGPoint(x: courtSize.width / 2, y: courtSize.height / 2)
        ballVelocity = .zero
        isBallHidden = false
        blackHoleHiddenUntil = nil
        blackHoleExitVelocity = nil
        blackHoleEntrySpeed = nil
    } // resetPositions

    func serve() {
        guard phase == .serving else { return } // guard phase == .serving
        let angle = CGFloat.random(in: -0.35...0.35)
        let dir: CGFloat = servingToRight ? 1 : -1
        ballVelocity = CGVector(dx: cos(angle) * baseBallSpeed * dir,
                                 dy: sin(angle) * baseBallSpeed)
        phase = .playing
        playMySound("WallHit") // pop
    } // serve

    // MARK: - Game loop

    func tick(now: Date) {
        defer { lastTick = now } // defer
        guard courtSize != .zero else { return } // guard courtSize != .zero
        guard phase == .playing else {
            lastTick = now
            return
        } // guard phase == .playing
        let dt = min(lastTick.map { now.timeIntervalSince($0) } ?? 1.0/60.0, 1.0/30.0)

        updatePaddles(dt: dt)
        updateBall(dt: dt, now: now)
    } // tick

    private func updatePaddles(dt: TimeInterval) {
        let half = paddleHeight / 2
        let minY = half
        let maxY = courtSize.height - half

        // Right paddle: player-controlled always
        if let target = rightPaddleTarget {
            rightPaddleY = clampMove(current: rightPaddleY, target: target, dt: dt, minY: minY, maxY: maxY)
        } // if let target = rightPaddleTarget

        // Left paddle: AI unless two-player mode
        if twoPlayerMode {
            if let target = leftPaddleTarget {
                leftPaddleY = clampMove(current: leftPaddleY, target: target, dt: dt, minY: minY, maxY: maxY)
            } // if let target = leftPaddleTarget
        } else {
            let aiTarget: CGFloat
            if smarterAI {
                aiTarget = ballVelocity.dx < 0 ? ballPos.y : courtSize.height / 2
            } else if ballPos.x <= courtSize.width / 2 {
                aiTarget = ballPos.y
            } else {
                aiTarget = leftPaddleY
            }
            leftPaddleY = clampMove(current: leftPaddleY, target: aiTarget, dt: dt, minY: minY, maxY: maxY, speedScale: 0.43)
        } // if twoPlayerMode
    } // updatePaddles

    private func clampMove(current: CGFloat, target: CGFloat, dt: TimeInterval, minY: CGFloat, maxY: CGFloat, speedScale: CGFloat = 1.0) -> CGFloat {
        let maxDelta = paddleSpeed * speedScale * CGFloat(dt)
        let delta = (target - current)
        let clampedDelta = max(-maxDelta, min(maxDelta, delta))
        return min(maxY, max(minY, current + clampedDelta))
    } // clampMove

    private func updateBall(dt: TimeInterval, now: Date) {
        if let hiddenUntil = blackHoleHiddenUntil {
            guard now >= hiddenUntil else { return }
            blackHoleHiddenUntil = nil
            isBallHidden = false
            if let exitVelocity = blackHoleExitVelocity {
                let calculatedSpeed = sqrt(exitVelocity.dx * exitVelocity.dx + exitVelocity.dy * exitVelocity.dy)
                let preservedSpeed = blackHoleEntrySpeed ?? calculatedSpeed
                let scale = calculatedSpeed > 0 ? preservedSpeed / calculatedSpeed : 0
                let preservedVelocity = CGVector(dx: exitVelocity.dx * scale,
                                                 dy: exitVelocity.dy * scale)
                ballVelocity = preservedVelocity
                if let blackHolePosition {
                    let clearance = Self.blackHoleDiameter / 2 + ballSize / 2 + 2
                    if preservedSpeed > 0 {
                        ballPos = CGPoint(
                            x: blackHolePosition.x + preservedVelocity.dx / preservedSpeed * clearance,
                            y: blackHolePosition.y + preservedVelocity.dy / preservedSpeed * clearance
                        )
                    } else {
                        ballPos = blackHolePosition
                    }
                }
            }
            blackHoleExitVelocity = nil
            blackHoleEntrySpeed = nil
            return
        }

        var pos = ballPos
        var vel = ballVelocity

        pos.x += vel.dx * CGFloat(dt)
        pos.y += vel.dy * CGFloat(dt)

        let half = ballSize / 2

        // Top / bottom walls
        if pos.y - half < 0 {
            pos.y = half
            vel.dy = abs(vel.dy)
            ballMouthOpenUntil = Date().addingTimeInterval(0.16)
            playMySound("WallHit")
        } else if pos.y + half > courtSize.height {
            pos.y = courtSize.height - half
            vel.dy = -abs(vel.dy)
            ballMouthOpenUntil = Date().addingTimeInterval(0.16)
            playMySound("WallHit")
        } // if pos.y - half < 0 / else if pos.y + half > courtSize.height

        if blackHoleEnabled, let blackHolePosition {
            let dx = pos.x - blackHolePosition.x
            let dy = pos.y - blackHolePosition.y
            let hitRadius = Self.blackHoleDiameter / 2 + half
            if dx * dx + dy * dy <= hitRadius * hitRadius {
                ballPos = blackHolePosition
                ballVelocity = .zero
                blackHoleEntrySpeed = sqrt(vel.dx * vel.dx + vel.dy * vel.dy)
                blackHoleExitVelocity = deflectedVelocity(from: vel)
                blackHoleHiddenUntil = now.addingTimeInterval(0.25)
                isBallHidden = true
                playMySound("BlackHoleHit")
                return
            }
        }

        // Left paddle collision
        if vel.dx < 0,
           pos.x - half <= leftPaddleX + paddleWidth / 2,
           pos.x - half >= leftPaddleX - paddleWidth / 2,
           pos.y >= leftPaddleY - paddleHeight / 2 - half,
           pos.y <= leftPaddleY + paddleHeight / 2 + half {
            pos.x = leftPaddleX + paddleWidth / 2 + half
            vel = bounced(vel: vel, paddleY: leftPaddleY, ballY: pos.y, movingRight: true)
            ballMouthOpenUntil = Date().addingTimeInterval(0.16)
            playMySound("RacquetHit")
        } // if vel.dx < 0 (left paddle collision)

        // Right paddle collision
        if vel.dx > 0,
           pos.x + half >= rightPaddleX - paddleWidth / 2,
           pos.x + half <= rightPaddleX + paddleWidth / 2,
           pos.y >= rightPaddleY - paddleHeight / 2 - half,
           pos.y <= rightPaddleY + paddleHeight / 2 + half {
            pos.x = rightPaddleX - paddleWidth / 2 - half
            vel = bounced(vel: vel, paddleY: rightPaddleY, ballY: pos.y, movingRight: false)
            ballMouthOpenUntil = Date().addingTimeInterval(0.16)
            playMySound("RacquetHit")
        } // if vel.dx > 0 (right paddle collision)

        ballPos = pos
        ballVelocity = vel

        // Scoring: right paddle is always the player, left is the opponent
        // (AI, or Player 1 in two-player mode).
        if pos.x < -ballSize {
            rightScore += 1
            handlePointScored(rightScored: true)
        } else if pos.x > courtSize.width + ballSize {
            leftScore += 1
            handlePointScored(rightScored: false)
        } // if pos.x < -ballSize / else if pos.x > courtSize.width + ballSize
    } // updateBall

    private func deflectedVelocity(from velocity: CGVector) -> CGVector {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        let coreAngle: CGFloat
        if abs(velocity.dx) >= abs(velocity.dy) {
            coreAngle = velocity.dx >= 0 ? 0 : .pi
        } else {
            coreAngle = velocity.dy >= 0 ? .pi / 2 : -.pi / 2
        }

        // Keep each nonzero component pointed the same way as it was on entry.
        // This preserves the randomized deflection without letting the ball
        // come back out along the path it entered.
        for _ in 0..<64 {
            let angle = coreAngle + CGFloat.random(in: -75...75) * .pi / 180
            let candidate = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            let horizontalPreserved = velocity.dx == 0 || candidate.dx * velocity.dx >= 0
            let verticalPreserved = velocity.dy == 0 || candidate.dy * velocity.dy >= 0
            if horizontalPreserved && verticalPreserved {
                return candidate
            }
        }

        // The incoming vector is always within 45 degrees of its selected core.
        return velocity
    }

    private func bounced(vel: CGVector, paddleY: CGFloat, ballY: CGFloat, movingRight: Bool) -> CGVector {
        let relative = (ballY - paddleY) / (paddleHeight / 2) // -1...1
        let clampedRel = max(-1, min(1, relative))
        let bounceAngle = clampedRel * (.pi / 3) // up to 60 degrees
        let currentSpeed = sqrt(vel.dx * vel.dx + vel.dy * vel.dy)
        let newSpeed = min(maxBallSpeed, currentSpeed * 1.06)
        let dir: CGFloat = movingRight ? 1 : -1
        return CGVector(dx: cos(bounceAngle) * newSpeed * dir, dy: sin(bounceAngle) * newSpeed)
    } // bounced

    /// - Parameter rightScored: true when the right paddle won the point,
    ///   false when the left paddle did. Drives both next-server assignment
    ///   and which point-scored sound plays. In two-player mode both sides
    ///   are "you", so it's always GolfClap there; in single-player, GolfClap
    ///   is for the player (right) and Aw is for the CPU opponent (left).
    private func handlePointScored(rightScored: Bool) {
        playMySound(twoPlayerMode || rightScored ? "GolfClap" : "Aw")
        servingToRight = !rightScored
        if leftScore >= Self.winningScore || rightScore >= Self.winningScore {
            winner = leftScore > rightScore ? "PLAYER 1" : (twoPlayerMode ? "PLAYER 2" : "COMPUTER")
            phase = .gameOver
            resetPositions()
        } else {
            resetPositions()
            phase = .serving
        } // if leftScore >= Self.winningScore || rightScore >= Self.winningScore
    } // handlePointScored

//    private func playSound(_ id: SystemSoundID) {
//        guard soundEnabled else { return }
//        AudioServicesPlaySystemSound(id)
//    }
//
    private func playMySound(_ name: String, extension ext: String = "wav") {
        guard soundEnabled else { return } // guard soundEnabled

        if let existingID = soundIDs[name] {
            AudioServicesPlaySystemSound(existingID)
            return
        } // if let existingID = soundIDs[name]

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("Missing sound file: \(name).\(ext)")
            return
        } // guard let url = Bundle.main.url(forResource:withExtension:)

        var soundID: SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        soundIDs[name] = soundID
        AudioServicesPlaySystemSound(soundID)
    } // playMySound
} // class GameEngine
