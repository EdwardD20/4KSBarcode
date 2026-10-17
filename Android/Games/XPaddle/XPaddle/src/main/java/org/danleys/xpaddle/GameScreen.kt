//
// XPaddle
// GameScreen.kt
//

package org.danleys.xpaddle

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Matrix
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.isActive

val DarkBlue = Color(red = 0f, green = 0f, blue = 0.55f)
val GameYellow = Color(red = 1f, green = 0.83f, blue = 0f)

/// Top-level screen. Port of XPaddleContentView: single-device play (1P
/// vs CPU or 2P on one screen) plus a "Play Nearby" entry into DuelScreen,
/// shown here as a fullscreen Dialog (the Android analogue of iOS's
/// .fullScreenCover).
@Composable
fun XPaddleApp(onExitToHost: (() -> Unit)? = null) {
    val context = LocalContext.current
    val settings = remember { GameSettings(context) }
    val engine = remember { GameEngine(context, settings) }
    var showNearbyDuel by remember { mutableStateOf(false) }
    var showSettings by remember { mutableStateOf(false) }

    Box(modifier = Modifier.fillMaxSize().background(DarkBlue)) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
            // maxWidth/maxHeight here are already Dp (density-independent), the
            // Android analogue of iOS's "points" — this is the space all of the
            // engine's tunables (paddle size, ball speed, etc.) were written in.
            // Feeding raw device pixels here instead made everything render
            // 2-3x smaller/slower than intended on high-density screens.
            val widthDp = maxWidth.value
            val heightDp = maxHeight.value
            val isPortrait = heightDp > widthDp

            LaunchedEffect(widthDp, heightDp) {
                engine.configureCourt(Size(widthDp, heightDp), isPortrait)
            } // LaunchedEffect(size)

            CourtView(engine = engine, isPortrait = isPortrait)

            when (engine.phase) {
                XPaddleGamePhase.MENU -> MenuOverlay(
                    engine = engine,
                    onPlayNearby = { showNearbyDuel = true },
                    onSettings = { showSettings = true },
                    singlePlayer = onExitToHost != null
                ) // MenuOverlay
                XPaddleGamePhase.SERVING -> ServeOverlay(engine = engine)
                XPaddleGamePhase.GAME_OVER -> GameOverOverlay(engine = engine)
                else -> {} // PLAYING / POINT_SCORED: no overlay
            } // when (engine.phase)

            if (onExitToHost != null) {
                Row(modifier = Modifier.align(Alignment.TopStart).padding(top = 76.dp, start = 12.dp)) {
                    Button(onClick = onExitToHost, colors = ButtonDefaults.buttonColors(containerColor = Color.Red.copy(alpha = 0.4f))) {
                        Text("Return to app", color = Color.Black, fontWeight = FontWeight.SemiBold)
                    } // Button
                } // Row
            } // if onExitToHost != null
        } // BoxWithConstraints
    } // Box

    if (showSettings) {
        Dialog(
            onDismissRequest = { showSettings = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            XPaddleSettingsView(settings = settings, onBack = { showSettings = false })
        } // Dialog
    } // if showSettings

    if (showNearbyDuel) {
        Dialog(
            onDismissRequest = { showNearbyDuel = false },
            properties = DialogProperties(usePlatformDefaultWidth = false)
        ) {
            DuelScreen(onExit = { showNearbyDuel = false })
        } // Dialog
    } // if showNearbyDuel
} // XPaddleApp

// MARK: - Court (gameplay canvas)

@Composable
private fun CourtView(engine: GameEngine, isPortrait: Boolean) {
    // Game loop: TimelineView(.animation(paused: phase != .playing)) equivalent.
    LaunchedEffect(Unit) {
        while (isActive) {
            withFrameNanos { now -> engine.tick(now) }
        } // while isActive
    } // LaunchedEffect(game loop)

    // Pointer events always report raw device pixels regardless of how the
    // layout was measured, so touches need converting into the same
    // dp-equivalent space the engine's court/paddle/ball live in.
    val density = LocalDensity.current.density

    // painterResource is @Composable, so the three rotation frames are
    // fetched here (not inside the Canvas draw closure) and just referenced
    // from within it.
    val blackHolePainters = listOf(
        painterResource(id = R.drawable.black_hole_0),
        painterResource(id = R.drawable.black_hole_1),
        painterResource(id = R.drawable.black_hole_2)
    ) // blackHolePainters

    Box(
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(isPortrait, density) {
                // A SwiftUI DragGesture only tracks one active touch; this reads
                // every active pointer each frame instead, so two fingers on
                // opposite halves drive both paddles independently in 2P mode
                // — the same reasoning as the iOS UIKit TouchTrackingUIView.
                awaitEachGesture {
                    do {
                        val event = awaitPointerEvent()
                        val width = engine.courtSize.width
                        if (width <= 0f) continue // if width <= 0f

                        if (event.changes.any { it.pressed && !it.previousPressed }) {
                            if (engine.phase == XPaddleGamePhase.SERVING) engine.serve()
                        } // if a new touch just began

                        for (change in event.changes) {
                            if (!change.pressed) continue // if this touch was lifted
                            val posDp = change.position / density
                            val logical = if (isPortrait) Offset(posDp.y, posDp.x) else posDp
                            val isLeftSide = logical.x < width / 2
                            if (isLeftSide) {
                                if (engine.twoPlayerMode) engine.leftPaddleTarget = logical.y
                            } else {
                                engine.rightPaddleTarget = logical.y
                            } // if isLeftSide
                            change.consume()
                        } // for change in event.changes
                    } while (event.changes.any { it.pressed })
                } // awaitEachGesture
            } // pointerInput
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            withTransform({
                // Canvas draws in raw device pixels; the engine's coordinates are
                // dp-equivalent, so scale up by density before anything else.
                scale(scaleX = density, scaleY = density, pivot = Offset.Zero)
                if (isPortrait) {
                    // The model always thinks in landscape logical coordinates;
                    // in portrait we transpose x/y with a single matrix, mirroring
                    // the iOS CGAffineTransform(a:0,b:1,c:1,d:0,tx:0,ty:0). A
                    // uniform scale commutes with this swap, so order doesn't matter.
                    val transposed = Matrix().apply {
                        this[0, 0] = 0f; this[0, 1] = 1f
                        this[1, 0] = 1f; this[1, 1] = 0f
                    } // val transposed
                    transform(transposed)
                } // if isPortrait
            }) {
                val size = engine.courtSize
                drawNet(size)
                drawPaddle(engine.leftPaddleX, engine.leftPaddleY, engine)
                drawPaddle(engine.rightPaddleX, engine.rightPaddleY, engine)
                if (engine.blackHoleVisible) {
                    drawBlackHole(engine, blackHolePainters[engine.blackHoleFrame])
                } // if blackHoleVisible
                if (engine.ballVisible) {
                    drawBall(engine)
                } // if ballVisible (hidden while swallowed by the black hole)
            } // withTransform
        } // Canvas

        ScoreBar(engine = engine, modifier = Modifier.align(Alignment.TopCenter).padding(top = 24.dp))
    } // Box
} // CourtView

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawNet(size: Size) {
    val dashHeight = 12f
    val gap = 10f
    var y = 0f
    while (y < size.height) {
        drawRect(
            color = GameYellow.copy(alpha = 0.4f),
            topLeft = Offset(size.width / 2 - 2f, y),
            size = Size(4f, dashHeight)
        ) // drawRect (net dash)
        y += dashHeight + gap
    } // while y < size.height
} // drawNet

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawPaddle(x: Float, y: Float, engine: GameEngine) {
    drawRoundRect(
        color = GameYellow,
        topLeft = Offset(x - engine.paddleWidth / 2, y - engine.paddleHeight / 2),
        size = Size(engine.paddleWidth, engine.paddleHeight),
        cornerRadius = CornerRadius(3f, 3f)
    ) // drawRoundRect (paddle)
} // drawPaddle

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawBlackHole(engine: GameEngine, painter: Painter) {
    val diameter = engine.blackHoleSize
    translate(left = engine.blackHolePos.x - diameter / 2, top = engine.blackHolePos.y - diameter / 2) {
        with(painter) { draw(Size(diameter, diameter)) }
    } // translate
} // drawBlackHole

private fun androidx.compose.ui.graphics.drawscope.DrawScope.drawBall(engine: GameEngine) {
    drawOval(
        color = GameYellow,
        topLeft = Offset(engine.ballPos.x - engine.ballSize / 2, engine.ballPos.y - engine.ballSize / 2),
        size = Size(engine.ballSize, engine.ballSize)
    ) // drawOval (ball)
} // drawBall

@Composable
private fun ScoreBar(engine: GameEngine, modifier: Modifier = Modifier) {
    Row(
        modifier = modifier.fillMaxWidth().padding(horizontal = 16.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text("${engine.leftScore}", color = GameYellow, fontSize = 44.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
        Text(
            "❚❚",
            color = GameYellow.copy(alpha = 0.6f),
            modifier = Modifier
                .clickable { engine.backToMenu() }
                .padding(10.dp)
        ) // Text (pause button — was never wired up; now calls backToMenu like iOS's pause.fill button)
        Text("${engine.rightScore}", color = GameYellow, fontSize = 44.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
    } // Row
} // ScoreBar

// MARK: - Overlays

@Composable
private fun MenuOverlay(engine: GameEngine,
                        onPlayNearby: () -> Unit,
                        onSettings: () -> Unit,
                        singlePlayer: Boolean) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(28.dp)) {
            Text("XPaddle", color = GameYellow, fontSize = 48.sp, fontWeight = FontWeight.Black, fontFamily = FontFamily.Monospace)

            Column(verticalArrangement = Arrangement.spacedBy(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                MenuButton("1 PLAYER  (VS CPU)") { engine.startGame(twoPlayer = false) }
                if (!singlePlayer) {

                    MenuButton("2 PLAYER  (SAME DEVICE)") { engine.startGame(twoPlayer = true) }
                    MenuButton("PLAY NEARBY  (2 DEVICES)", onClick = onPlayNearby)
                } // if !singlePlayer
                MenuButton("SETTINGS", onClick = onSettings)
            } // Column (menu buttons)
        } // Column
    } // Box
} // MenuOverlay

@Composable
private fun MenuButton(text: String, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(containerColor = GameYellow),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.width(340.dp)
    ) {
        Text(text, color = Color.Black, fontSize = 20.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
    } // Button
} // MenuButton

@Composable
private fun ServeOverlay(engine: GameEngine) {
    Box(
        modifier = Modifier.fillMaxSize().padding(10.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(
            modifier = Modifier.background(DarkBlue.copy(alpha = 0.55f), RoundedCornerShape(12.dp)).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("TAP TO SERVE", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
            val subtitle = if (engine.twoPlayerMode) {
                if (engine.isPortrait) "Player 1 (top) vs Player 2 (bottom)" else "Player 1 (left) vs Player 2 (right)"
            } else {
                if (engine.isPortrait) "You are the bottom paddle" else "You are the right paddle"
            } // val subtitle
            Text(subtitle, color = Color.White.copy(alpha = 0.6f), fontSize = 14.sp, fontWeight = FontWeight.Medium, fontFamily = FontFamily.Monospace)
        } // Column
    } // Box
} // ServeOverlay

@Composable
private fun GameOverOverlay(engine: GameEngine) {
    Box(modifier = Modifier.fillMaxSize().padding(40.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text(
                "${engine.winner ?: ""} WINS",
                color = Color.White,
                fontSize = 40.sp,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Center
            ) // Text (winner)
            Text(
                "${engine.leftScore} — ${engine.rightScore}",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace
            ) // Text (final score)

            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Button(
                    onClick = { engine.startGame(twoPlayer = engine.twoPlayerMode) },
                    colors = ButtonDefaults.buttonColors(containerColor = GameYellow),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.width(160.dp)
                ) {
                    Text("REMATCH", color = Color.Black, fontSize = 17.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                } // Button (rematch)
                Button(
                    onClick = { engine.backToMenu() },
                    colors = ButtonDefaults.buttonColors(containerColor = GameYellow),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.width(160.dp)
                ) {
                    Text("MENU", color = Color.Black, fontSize = 17.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                } // Button (menu)
            } // Row (buttons)
        } // Column
    } // Box
} // GameOverOverlay
