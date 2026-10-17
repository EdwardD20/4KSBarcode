//
// XPaddle
// DuelEngine.kt
//

package org.danleys.xpaddle

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random
import kotlin.time.Duration.Companion.milliseconds

enum class DuelPhase {
    CONNECTING,
    CONNECTION_LOST,
    SERVING,        // it's this device's turn to serve
    WAITING_FOR_BALL, // ball is currently on the opponent's screen
    PLAYING,        // ball is currently on this device's screen
    GAME_OVER
} // enum class DuelPhase

/// Drives a two-device XPaddle match over Nearby Connections. Each phone
/// renders and simulates only its own half of the court — there is no
/// shared "world state" beyond the ball's flight, which is handed from one
/// device to the other the instant it reaches the seam where the phones
/// are held together. Whoever currently "has" the ball is fully
/// authoritative over its physics until it either bounces back across the
/// seam or gets missed. Direct Kotlin port of the iOS DuelEngine.
class DuelEngine(context: Context) {
    companion object {
        const val WINNING_SCORE = 11
    } // companion object

    val paddleWidth: Float = 14f
    val paddleHeight: Float = 90f
    val ballSize: Float = 16f
    val paddleSpeed: Float = 620f
    val baseBallSpeed: Float = 380f
    val maxBallSpeed: Float = 900f
    val paddleMargin: Float = 28f

    private val net = NetworkManager(context)
    private val myToken = UUID.randomUUID().toString()
    private var peerToken: String? = null
    private var helloJob: Job? = null
    private var helloAttempts = 0
    private val scope = CoroutineScope(Dispatchers.Main.immediate + SupervisorJob())

    var phase by mutableStateOf(DuelPhase.CONNECTING)
    var connectionLabel by mutableStateOf("Searching for nearby phone…")
    var isLeftSide: Boolean by mutableStateOf(true)
        private set

    var courtSize by mutableStateOf(Size.Zero)
    private var safeAreaLeading = 0f
    private var safeAreaTrailing = 0f

    var paddleY by mutableStateOf(0f)
    var ballPos by mutableStateOf(Offset.Zero)
    var ballVisible by mutableStateOf(false)

    var localScore by mutableStateOf(0)
    var opponentScore by mutableStateOf(0)
    var winnerIsMe by mutableStateOf<Boolean?>(null)

    /// Set from the drag/touch input; null until the player first touches the court.
    var paddleTarget: Float? = null

    private var ballVelocity: Offset = Offset.Zero
    private var lastTick: Long? = null

    private val soundPlayer = SoundPlayer(context)

    val paddleX: Float
        get() = if (isLeftSide) paddleMargin + safeAreaLeading else courtSize.width - paddleMargin - safeAreaTrailing

    init {
        net.onMessage = { message -> handle(message) } // net.onMessage
        net.onStateChange = { state, _ -> handleConnectionState(state) } // net.onStateChange
    } // init

    // MARK: - Lifecycle

    fun start() {
        phase = DuelPhase.CONNECTING
        connectionLabel = "Searching for nearby phone…"
        localScore = 0
        opponentScore = 0
        winnerIsMe = null
        ballVisible = false
        peerToken = null
        net.startSearching()
    } // start

    fun stop() {
        helloJob?.cancel()
        net.stop()
    } // stop

    fun configureCourt(size: Size) {
        if (size.width <= 0f || size.height <= 0f) return // guard size.width > 0, size.height > 0
        val first = courtSize == Size.Zero
        courtSize = size
        if (first) paddleY = size.height / 2
    } // configureCourt

    fun configureSafeArea(leading: Float, trailing: Float) {
        safeAreaLeading = leading
        safeAreaTrailing = trailing
    } // configureSafeArea

    // MARK: - Connection & handshake

    private fun handleConnectionState(state: DuelConnectionState) {
        when (state) {
            DuelConnectionState.IDLE -> {} // case .idle
            DuelConnectionState.SEARCHING -> connectionLabel = "Searching for nearby phone…"
            DuelConnectionState.CONNECTED -> {
                connectionLabel = "Connected — syncing…"
                beginHandshake()
            } // case .connected
            DuelConnectionState.LOST -> {
                helloJob?.cancel()
                phase = DuelPhase.CONNECTION_LOST
            } // case .lost
        } // when (state)
    } // handleConnectionState

    /// Both phones pick a random token and trade it; whichever token sorts
    /// first becomes the "left" screen. Neither player has to choose a side.
    private fun beginHandshake() {
        helloAttempts = 0
        sendHello()
        helloJob?.cancel()
        helloJob = scope.launch {
            while (peerToken == null && helloAttempts < 6) {
                delay(1000.milliseconds)
                if (peerToken != null) break // if peerToken already arrived while waiting
                helloAttempts += 1
                sendHello()
            } // while peerToken == null && helloAttempts < 6
        } // scope.launch
    } // beginHandshake

    private fun sendHello() {
        net.send(DuelMessage.Hello(token = myToken))
    } // sendHello

    private fun handle(message: DuelMessage) {
        when (message) {
            is DuelMessage.Hello -> {
                if (peerToken != null) return // guard peerToken == nil
                peerToken = message.token
                helloJob?.cancel()
                isLeftSide = myToken < message.token
                paddleY = courtSize.height / 2
                phase = if (isLeftSide) DuelPhase.SERVING else DuelPhase.WAITING_FOR_BALL
            } // is DuelMessage.Hello
            is DuelMessage.BallHandoff -> receiveBall(message.yFraction, message.vyFraction, message.speedFraction)
            is DuelMessage.PointAgainstSender -> {
                localScore += 1
                resolveRound(iConceded = false)
            } // is DuelMessage.PointAgainstSender
            is DuelMessage.Rematch -> beginRematch(sendMessage = false)
        } // when (message)
    } // handle

    // MARK: - Serve

    fun serve() {
        if (phase != DuelPhase.SERVING || courtSize == Size.Zero) return // guard phase == .serving, courtSize != .zero
        val angle = Random.nextFloat() * 0.6f - 0.3f
        val dir: Float = if (isLeftSide) 1f else -1f // always serve toward the seam, into the opponent's court
        ballVelocity = Offset(cos(angle) * baseBallSpeed * dir, sin(angle) * baseBallSpeed)
        ballPos = Offset(courtSize.width / 2, courtSize.height / 2)
        ballVisible = true
        phase = DuelPhase.PLAYING
        soundPlayer.play("wall_hit")
    } // serve

    // MARK: - Game loop

    fun tick(nowNanos: Long) {
        if (phase != DuelPhase.PLAYING || courtSize == Size.Zero) {
            lastTick = nowNanos
            return
        } // guard phase == .playing, courtSize != .zero
        val dtSeconds = lastTick?.let { min((nowNanos - it) / 1_000_000_000.0, 1.0 / 30.0) } ?: (1.0 / 60.0)
        lastTick = nowNanos
        val dt = dtSeconds.toFloat()
        updatePaddle(dt)
        updateBall(dt)
    } // tick

    private fun updatePaddle(dt: Float) {
        val target = paddleTarget ?: return // guard let target = paddleTarget
        if (courtSize == Size.Zero) return // guard courtSize != .zero
        val half = paddleHeight / 2
        val minY = half
        val maxY = courtSize.height - half
        val maxDelta = paddleSpeed * dt
        val delta = (target - paddleY).coerceIn(-maxDelta, maxDelta)
        paddleY = (paddleY + delta).coerceIn(minY, maxY)
    } // updatePaddle

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
            soundPlayer.play("wall_hit")
        } else if (pos.y + half > courtSize.height) {
            pos = Offset(pos.x, courtSize.height - half)
            vel = Offset(vel.x, -abs(vel.y))
            soundPlayer.play("wall_hit")
        } // if pos.y - half < 0 / else if pos.y + half > courtSize.height

        // This device's own paddle. Checked as a swept crossing of the
        // paddle's front face (old position on the far side, new position
        // at/past it) rather than "did the ball land inside a narrow
        // x-band" — a fast ball can travel further than the paddle's
        // ~14-unit collision zone in a single frame (especially on a
        // choppy emulator frame rate), which let it tunnel straight
        // through under the old position-only check.
        val px = paddleX
        val movingTowardPaddle = if (isLeftSide) vel.x < 0 else vel.x > 0
        val paddleFront = if (isLeftSide) px + paddleWidth / 2 else px - paddleWidth / 2
        val crossedPaddleFace = if (isLeftSide) {
            (oldPos.x - half) >= paddleFront && (pos.x - half) <= paddleFront
        } else {
            (oldPos.x + half) <= paddleFront && (pos.x + half) >= paddleFront
        } // val crossedPaddleFace
        val withinPaddleY = pos.y >= paddleY - paddleHeight / 2 - half && pos.y <= paddleY + paddleHeight / 2 + half

        if (movingTowardPaddle && crossedPaddleFace && withinPaddleY) {
            pos = Offset(if (isLeftSide) paddleFront + half else paddleFront - half, pos.y)
            vel = bounced(vel, pos.y)
            soundPlayer.play("wall_hit")
        } // if movingTowardPaddle, crossedPaddleFace, withinPaddleY

        // Seam edge (touching the other phone) — hand the ball off
        val approachingSeam = if (isLeftSide) vel.x > 0 else vel.x < 0
        val reachedSeam = if (isLeftSide) pos.x + half >= courtSize.width else pos.x - half <= 0
        if (approachingSeam && reachedSeam) {
            handOffBall(vel, pos.y)
            return
        } // if approachingSeam, reachedSeam

        // Outer wall — this player missed it, opponent scores
        if (if (isLeftSide) pos.x < -ballSize else pos.x > courtSize.width + ballSize) {
            missedPoint()
            return
        } // if outer wall miss

        ballPos = pos
        ballVelocity = vel
    } // updateBall

    private fun bounced(vel: Offset, ballY: Float): Offset {
        val relative = ((ballY - paddleY) / (paddleHeight / 2)).coerceIn(-1f, 1f)
        val bounceAngle = relative * (Math.PI.toFloat() / 3f)
        val speed = min(maxBallSpeed, hypot(vel.x, vel.y) * 1.06f)
        val dir: Float = if (isLeftSide) 1f else -1f
        return Offset(cos(bounceAngle) * speed * dir, sin(bounceAngle) * speed)
    } // bounced

    private fun handOffBall(vel: Offset, y: Float) {
        val yFraction = (y / courtSize.height).toDouble()
        val vyFraction = (vel.y / courtSize.height).toDouble()
        val speedFraction = (hypot(vel.x, vel.y) / courtSize.width).toDouble()
        net.send(DuelMessage.BallHandoff(yFraction, vyFraction, speedFraction))
        ballVisible = false
        phase = DuelPhase.WAITING_FOR_BALL
    } // handOffBall

    private fun receiveBall(yFraction: Double, vyFraction: Double, speedFraction: Double) {
        if (courtSize == Size.Zero) return // guard courtSize != .zero
        val y = (yFraction * courtSize.height).toFloat()
        val vy = (vyFraction * courtSize.height).toFloat()
        val speed = (speedFraction * courtSize.width).toFloat()
        val vx = (if (isLeftSide) -1f else 1f) * sqrt(maxOf(0f, speed * speed - vy * vy))
        ballPos = Offset(if (isLeftSide) courtSize.width - ballSize / 2 else ballSize / 2, y)
        ballVelocity = Offset(vx, vy)
        ballVisible = true
        phase = DuelPhase.PLAYING
        soundPlayer.play("wall_hit")
    } // receiveBall

    // MARK: - Scoring

    private fun missedPoint() {
        ballVisible = false
        opponentScore += 1
        net.send(DuelMessage.PointAgainstSender)
        resolveRound(iConceded = true)
    } // missedPoint

    private fun resolveRound(iConceded: Boolean) {
        if (localScore >= WINNING_SCORE || opponentScore >= WINNING_SCORE) {
            winnerIsMe = localScore > opponentScore
            phase = DuelPhase.GAME_OVER
            return
        } // if localScore >= WINNING_SCORE || opponentScore >= WINNING_SCORE
        // The side that conceded the last point serves next.
        phase = if (iConceded) DuelPhase.SERVING else DuelPhase.WAITING_FOR_BALL
    } // resolveRound

    // MARK: - Rematch

    fun requestRematch() {
        net.send(DuelMessage.Rematch)
        beginRematch(sendMessage = true)
    } // requestRematch

    private fun beginRematch(sendMessage: Boolean) {
        localScore = 0
        opponentScore = 0
        winnerIsMe = null
        ballVisible = false
        paddleY = courtSize.height / 2
        phase = if (isLeftSide) DuelPhase.SERVING else DuelPhase.WAITING_FOR_BALL
    } // beginRematch
} // class DuelEngine
