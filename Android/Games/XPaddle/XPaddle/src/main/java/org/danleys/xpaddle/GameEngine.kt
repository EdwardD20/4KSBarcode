//
// XPaddle
// GameEngine.kt
//

package org.danleys.xpaddle

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

enum class XPaddleGamePhase {
    MENU, SERVING, PLAYING, POINT_SCORED, GAME_OVER
} // enum class XPaddleGamePhase

/// Port of the iOS GameEngine (single-device: 1-player vs CPU, or 2-player
/// on one screen). The model always thinks in "logical" landscape space
/// (x = axis the ball travels between paddles, y = axis a paddle slides
/// along); the UI layer is responsible for transposing that onto the
/// screen when the device is portrait, exactly as CourtView did on iOS.
class GameEngine(context: Context, private val settings: GameSettings) {
    companion object {
        const val WINNING_SCORE = 11
    } // companion object

    // MARK: - Tunables
    val paddleWidth: Float = 14f
    val paddleHeight: Float = 90f
    val ballSize: Float = 16f
    val paddleSpeed: Float = 512f // AI max speed, points/sec
    val baseBallSpeed: Float = 400f
    val maxBallSpeed: Float = 1400f
    val paddleMargin: Float = 60f
    val blackHoleSize: Float = 60f

    // MARK: - Published state
    var phase by mutableStateOf(XPaddleGamePhase.MENU)
    var twoPlayerMode by mutableStateOf(false)

    var courtSize by mutableStateOf(Size.Zero)
    var safeAreaLeading by mutableStateOf(0f)
    var safeAreaTrailing by mutableStateOf(0f)

    var isPortrait: Boolean by mutableStateOf(false)
        private set

    val leftPaddleX: Float get() = paddleMargin + safeAreaLeading
    val rightPaddleX: Float get() = courtSize.width - paddleMargin - safeAreaTrailing

    var leftPaddleY by mutableStateOf(0f)
    var rightPaddleY by mutableStateOf(0f)
    var ballPos by mutableStateOf(Offset.Zero)

    var leftScore by mutableStateOf(0)
    var rightScore by mutableStateOf(0)
    var winner by mutableStateOf<String?>(null)

    // Black Hole: a fixed hazard placed once per new game (when enabled in
    // Settings) that swallows the ball briefly on contact and spits it back
    // out at a randomized angle. See updateBall()/respawnFromBlackHole().
    var ballVisible by mutableStateOf(true)
    var blackHolePos by mutableStateOf(Offset.Zero)
    var blackHoleVisible by mutableStateOf(false)
    var blackHoleFrame by mutableStateOf(0)
    private var blackHoleRotationElapsed = 0f
    private var blackHoleRespawnTimer: Float? = null
    private var blackHoleExitAngleBase = 0f
    private var blackHoleExitSpeed = 0f

    // internal physics
    private var ballVelocity: Offset = Offset.Zero
    private var servingToRight: Boolean = true
    private var lastTick: Long? = null

    // targets set by touch input; null = no active touch (AI or idle)
    var leftPaddleTarget: Float? = null
    var rightPaddleTarget: Float? = null

    private val soundPlayer = SoundPlayer(context)

    private fun playSound(name: String) {
        if (settings.soundEnabled) soundPlayer.play(name)
    } // playSound

    // MARK: - Lifecycle

    /// - Parameters:
    ///   - rawSize: the actual screen/canvas size, in real screen orientation.
    ///   - isPortrait: whether the device is currently portrait. The UI
    ///     decides this from the same measured size, so there's one source
    ///     of truth shared with its rendering transform.
    fun configureCourt(rawSize: Size, isPortrait: Boolean) {
        if (rawSize.width <= 0f || rawSize.height <= 0f) return // guard rawSize.width > 0, rawSize.height > 0
        this.isPortrait = isPortrait
        // Logical space always has x = ball-travel axis, y = paddle axis.
        // In portrait those are swapped relative to the real screen.
        val size = if (isPortrait) Size(rawSize.height, rawSize.width) else rawSize

        val firstTime = courtSize == Size.Zero
        val previousSize = courtSize
        courtSize = size

        if (firstTime) {
            leftPaddleY = size.height / 2
            rightPaddleY = size.height / 2
            ballPos = Offset(size.width / 2, size.height / 2)
        } else if (previousSize != size) {
            // Rotating (or resizing) mid-game: rescale existing positions
            // proportionally instead of leaving them stranded out of bounds.
            var newBallX = ballPos.x
            var newBallY = ballPos.y
            if (previousSize.width > 0) newBallX *= size.width / previousSize.width // if previousSize.width > 0
            if (previousSize.height > 0) {
                newBallY *= size.height / previousSize.height
                val ratio = size.height / previousSize.height
                leftPaddleY *= ratio
                rightPaddleY *= ratio
            } // if previousSize.height > 0
            ballPos = Offset(newBallX, newBallY)
            val half = paddleHeight / 2
            leftPaddleY = leftPaddleY.coerceIn(half, size.height - half)
            rightPaddleY = rightPaddleY.coerceIn(half, size.height - half)
        } // if firstTime / else if previousSize != size
    } // configureCourt

    fun configureSafeArea(leading: Float, trailing: Float) {
        safeAreaLeading = leading
        safeAreaTrailing = trailing
    } // configureSafeArea

    fun startGame(twoPlayer: Boolean) {
        twoPlayerMode = twoPlayer
        leftScore = 0
        rightScore = 0
        winner = null
        resetPositions()
        servingToRight = Random.nextBoolean()
        phase = XPaddleGamePhase.SERVING

        blackHoleFrame = 0
        blackHoleRotationElapsed = 0f
        blackHoleVisible = settings.blackHoleEnabled && courtSize != Size.Zero
        if (blackHoleVisible) {
            // Middle 1/4 of the court width (25% of width, centered — i.e.
            // between 37.5% and 62.5%), but free to land anywhere along the
            // full height rather than boxed into a small central square.
            val minX = courtSize.width * 0.375f
            val maxX = courtSize.width * 0.625f
            val half = blackHoleSize / 2
            val minY = half
            val maxY = (courtSize.height - half).coerceAtLeast(minY)
            blackHolePos = Offset(
                minX + Random.nextFloat() * (maxX - minX),
                minY + Random.nextFloat() * (maxY - minY)
            ) // blackHolePos
        } // if blackHoleVisible
    } // startGame

    fun backToMenu() {
        phase = XPaddleGamePhase.MENU
    } // backToMenu

    private fun resetPositions() {
        leftPaddleY = courtSize.height / 2
        rightPaddleY = courtSize.height / 2
        ballPos = Offset(courtSize.width / 2, courtSize.height / 2)
        ballVelocity = Offset.Zero
        ballVisible = true
        blackHoleRespawnTimer = null
    } // resetPositions

    fun serve() {
        if (phase != XPaddleGamePhase.SERVING) return // guard phase == .serving
        val angle = Random.nextFloat() * 0.7f - 0.35f
        val dir: Float = if (servingToRight) 1f else -1f
        ballVelocity = Offset(cos(angle) * baseBallSpeed * dir, sin(angle) * baseBallSpeed)
        phase = XPaddleGamePhase.PLAYING
        playSound("wall_hit")
    } // serve

    // MARK: - Game loop

    fun tick(nowNanos: Long) {
        if (courtSize == Size.Zero) return // guard courtSize != .zero
        if (phase != XPaddleGamePhase.PLAYING) {
            lastTick = nowNanos
            return
        } // guard phase == .playing
        val dtSeconds = lastTick?.let { min((nowNanos - it) / 1_000_000_000.0, 1.0 / 30.0) } ?: (1.0 / 60.0)
        lastTick = nowNanos
        val dt = dtSeconds.toFloat()

        if (blackHoleVisible) {
            blackHoleRotationElapsed += dt
            if (blackHoleRotationElapsed >= 0.12f) {
                blackHoleRotationElapsed = 0f
                blackHoleFrame = (blackHoleFrame + 1) % 3
            } // if a rotation frame is due
        } // if blackHoleVisible

        updatePaddles(dt)

        val respawnTimer = blackHoleRespawnTimer
        if (respawnTimer != null) {
            // Ball is swallowed: paddles keep moving, but the ball itself
            // stays frozen and invisible until the delay elapses.
            val remaining = respawnTimer - dt
            if (remaining <= 0f) {
                respawnFromBlackHole()
            } else {
                blackHoleRespawnTimer = remaining
            } // if remaining <= 0f
            return
        } // if respawnTimer != null

        updateBall(dt)
    } // tick

    private fun respawnFromBlackHole() {
        blackHoleRespawnTimer = null
        val maxOffset = 75f * (PI.toFloat() / 180f) // +/- 75 degrees, per spec
        val angle = blackHoleExitAngleBase + (Random.nextFloat() * 2f - 1f) * maxOffset
        // Emerge from the hole's edge along the new heading, not its exact
        // center — spawning inside the hole could immediately re-trigger
        // the collision check next frame.
        val exitDistance = blackHoleSize / 2 + ballSize / 2 + 20f
        ballPos = Offset(
            blackHolePos.x + cos(angle) * exitDistance,
            blackHolePos.y + sin(angle) * exitDistance
        ) // ballPos
        ballVelocity = Offset(cos(angle) * blackHoleExitSpeed, sin(angle) * blackHoleExitSpeed)
        ballVisible = true
    } // respawnFromBlackHole

    private fun updatePaddles(dt: Float) {
        val half = paddleHeight / 2
        val minY = half
        val maxY = courtSize.height - half

        // Right paddle: player-controlled always.
        rightPaddleTarget?.let { target ->
            rightPaddleY = clampMove(rightPaddleY, target, dt, minY, maxY)
        } // if let target = rightPaddleTarget

        // Left paddle: AI unless two-player mode.
        if (twoPlayerMode) {
            leftPaddleTarget?.let { target ->
                leftPaddleY = clampMove(leftPaddleY, target, dt, minY, maxY)
            } // if let target = leftPaddleTarget
        } else if (settings.smarterAI) {
            // Smarter AI: hold still until the ball has actually crossed
            // onto the computer's side of the court, then track it — same
            // speed as always, just doesn't react preemptively.
            val ballOnAiSide = ballPos.x < courtSize.width / 2
            if (ballOnAiSide) {
                leftPaddleY = clampMove(leftPaddleY, ballPos.y, dt, minY, maxY, speedScale = 0.86f)
            } // if ballOnAiSide (else: paddle holds its current position)
        } else {
            // Default: track the ball's y as soon as it's headed this way,
            // regardless of which side of the court it's on yet.
            val aiTarget = if (ballVelocity.x < 0) ballPos.y else courtSize.height / 2
            leftPaddleY = clampMove(leftPaddleY, aiTarget, dt, minY, maxY, speedScale = 0.86f)
        } // if twoPlayerMode / else if smarterAI / else
    } // updatePaddles

    private fun clampMove(current: Float, target: Float, dt: Float, minY: Float, maxY: Float, speedScale: Float = 1f): Float {
        val maxDelta = paddleSpeed * speedScale * dt
        val clampedDelta = (target - current).coerceIn(-maxDelta, maxDelta)
        return (current + clampedDelta).coerceIn(minY, maxY)
    } // clampMove

    private fun updateBall(dt: Float) {
        val oldPos = ballPos
        var pos = ballPos
        var vel = ballVelocity

        pos = Offset(pos.x + vel.x * dt, pos.y + vel.y * dt)
        val half = ballSize / 2

        // Top / bottom walls
        if (pos.y - half < 0) {
            pos = Offset(pos.x, half)
            vel = Offset(vel.x, abs(vel.y))
            playSound("wall_hit")
        } else if (pos.y + half > courtSize.height) {
            pos = Offset(pos.x, courtSize.height - half)
            vel = Offset(vel.x, -abs(vel.y))
            playSound("wall_hit")
        } // if pos.y - half < 0 / else if pos.y + half > courtSize.height

        // Black hole: swallow the ball on contact, eject it after a short
        // delay (handled in tick()) rather than bouncing it like a paddle.
        if (blackHoleVisible) {
            val dx = pos.x - blackHolePos.x
            val dy = pos.y - blackHolePos.y
            val hitRadius = blackHoleSize / 2 + half
            if (dx * dx + dy * dy <= hitRadius * hitRadius) {
                blackHoleExitAngleBase = atan2(vel.y, vel.x)
                blackHoleExitSpeed = hypot(vel.x, vel.y)
                ballPos = pos
                ballVelocity = Offset.Zero
                ballVisible = false
                playSound("black_hole_hit")
                blackHoleRespawnTimer = 0.5f
                return
            } // if within the black hole's hit radius
        } // if blackHoleVisible

        // Left paddle collision. Checked as a swept crossing of the paddle's
        // front face (old position on the far side, new position at/past it)
        // rather than "did the ball land inside a narrow x-band" — a fast
        // ball can travel further than the paddle's ~14-unit collision zone
        // in a single frame (especially on a choppy emulator frame rate),
        // which let it tunnel straight through under the old position-only check.
        val leftFront = leftPaddleX + paddleWidth / 2
        val crossedLeft = vel.x < 0 && (oldPos.x - half) >= leftFront && (pos.x - half) <= leftFront
        val withinLeftPaddleY = pos.y >= leftPaddleY - paddleHeight / 2 - half && pos.y <= leftPaddleY + paddleHeight / 2 + half
        if (crossedLeft && withinLeftPaddleY) {
            pos = Offset(leftFront + half, pos.y)
            vel = bounced(vel, leftPaddleY, pos.y, movingRight = true)
            playSound("racquet_hit")
        } // if crossedLeft, withinLeftPaddleY

        // Right paddle collision (same swept-crossing reasoning as above).
        val rightFront = rightPaddleX - paddleWidth / 2
        val crossedRight = vel.x > 0 && (oldPos.x + half) <= rightFront && (pos.x + half) >= rightFront
        val withinRightPaddleY = pos.y >= rightPaddleY - paddleHeight / 2 - half && pos.y <= rightPaddleY + paddleHeight / 2 + half
        if (crossedRight && withinRightPaddleY) {
            pos = Offset(rightFront - half, pos.y)
            vel = bounced(vel, rightPaddleY, pos.y, movingRight = false)
            playSound("racquet_hit")
        } // if vel.x > 0 (right paddle collision)

        ballPos = pos
        ballVelocity = vel

        // Scoring: right paddle is always the player, left is the opponent
        // (AI, or Player 1 in two-player mode).
        if (pos.x < -ballSize) {
            rightScore += 1
            handlePointScored(rightScored = true)
        } else if (pos.x > courtSize.width + ballSize) {
            leftScore += 1
            handlePointScored(rightScored = false)
        } // if pos.x < -ballSize / else if pos.x > courtSize.width + ballSize
    } // updateBall

    private fun bounced(vel: Offset, paddleY: Float, ballY: Float, movingRight: Boolean): Offset {
        val relative = ((ballY - paddleY) / (paddleHeight / 2)).coerceIn(-1f, 1f)
        val bounceAngle = relative * (PI.toFloat() / 3f) // up to 60 degrees
        val currentSpeed = hypot(vel.x, vel.y)
        val newSpeed = min(maxBallSpeed, currentSpeed * 1.06f)
        val dir: Float = if (movingRight) 1f else -1f
        return Offset(cos(bounceAngle) * newSpeed * dir, sin(bounceAngle) * newSpeed)
    } // bounced

    /// - Parameter rightScored: true when the right paddle won the point,
    ///   false when the left paddle did. Drives both next-server assignment
    ///   and which point-scored sound plays. In two-player mode both sides
    ///   are "you", so it's always golf_clap there; in single-player,
    ///   golf_clap is for the player (right) and aw is for the CPU (left).
    private fun handlePointScored(rightScored: Boolean) {
        playSound(if (twoPlayerMode || rightScored) "golf_clap" else "aw")
        servingToRight = !rightScored
        if (leftScore >= WINNING_SCORE || rightScore >= WINNING_SCORE) {
            winner = if (leftScore > rightScore) "PLAYER 1" else if (twoPlayerMode) "PLAYER 2" else "COMPUTER"
            phase = XPaddleGamePhase.GAME_OVER
            resetPositions()
        } else {
            resetPositions()
            phase = XPaddleGamePhase.SERVING
        } // if leftScore >= WINNING_SCORE || rightScore >= WINNING_SCORE
    } // handlePointScored
} // class GameEngine
