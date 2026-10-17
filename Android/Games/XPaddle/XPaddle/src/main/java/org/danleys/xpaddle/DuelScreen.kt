//
// XPaddle
// DuelScreen.kt
//

package org.danleys.xpaddle

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.isActive

/// Port of DuelView: connects to a nearby phone over Nearby Connections and
/// runs a live two-device duel. `onExit` plays the role of iOS's
/// `dismiss()` (called from the Dialog's containing screen).
@Composable
fun DuelScreen(onExit: () -> Unit) {
    val context = LocalContext.current
    val engine = remember { DuelEngine(context) }
    val requiredPermissions = remember { duelPermissions() }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        if (results.values.all { it }) {
            engine.start()
        } else {
            engine.stop()
        } // if all granted / else
    } // permissionLauncher

    DisposableEffect(Unit) {
        permissionLauncher.launch(requiredPermissions)
        onDispose { engine.stop() }
    } // DisposableEffect

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        if (engine.phase == DuelPhase.CONNECTING || engine.phase == DuelPhase.CONNECTION_LOST) {
            ConnectingOverlay(engine = engine, onCancel = onExit)
        } else {
            BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
                // maxWidth/maxHeight are already Dp (density-independent) here —
                // the space the engine's paddle/ball/speed tunables are written
                // in, matching iOS's point-based DuelEngine. Feeding raw pixels
                // made everything render smaller/slower on high-density screens.
                val widthDp = maxWidth.value
                val heightDp = maxHeight.value

                LaunchedEffect(widthDp, heightDp) {
                    engine.configureCourt(Size(widthDp, heightDp))
                } // LaunchedEffect(size)

                DuelCourtView(engine = engine)

                if (engine.phase == DuelPhase.GAME_OVER) {
                    DuelGameOverOverlay(engine = engine, onExit = onExit)
                } // if game over
            } // BoxWithConstraints
        } // if connecting/lost else
    } // Box
} // DuelScreen

/// Nearby Connections needs Bluetooth (+ location pre-Android 12) to
/// discover peers, mirroring what MultipeerConnectivity gets "for free"
/// via Info.plist entitlements on iOS.
private fun duelPermissions(): Array<String> {
    return when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> arrayOf(
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.NEARBY_WIFI_DEVICES
        ) // Android 13+
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> arrayOf(
            Manifest.permission.BLUETOOTH_ADVERTISE,
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) // Android 12
        else -> arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN
        ) // pre-Android 12
    } // when
} // duelPermissions

@Composable
private fun ConnectingOverlay(engine: DuelEngine, onCancel: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize().padding(40.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text("XPADDLE", color = Color.White, fontSize = 48.sp, fontWeight = FontWeight.Black, fontFamily = FontFamily.Monospace)

            if (engine.phase == DuelPhase.CONNECTION_LOST) {
                Text("CONNECTION LOST", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                PillButton("SEARCH AGAIN", filled = true) { engine.start() }
            } else {
                CircularProgressIndicator(color = Color.White)
                Text(
                    engine.connectionLabel,
                    color = Color.White.copy(alpha = 0.7f),
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = FontFamily.Monospace,
                    textAlign = TextAlign.Center
                ) // Text (connection label)
                Text(
                    "Bring both phones close together.\nMake sure Wi-Fi and Bluetooth are on,\nand XPaddle is open on both.",
                    color = Color.White.copy(alpha = 0.4f),
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    textAlign = TextAlign.Center
                ) // Text (hint)
            } // if connection lost / else

            PillButton("CANCEL", filled = false, onClick = onCancel)
        } // Column
    } // Box
} // ConnectingOverlay

@Composable
private fun PillButton(text: String, filled: Boolean, onClick: () -> Unit) {
    if (filled) {
        Button(
            onClick = onClick,
            colors = ButtonDefaults.buttonColors(containerColor = Color.White),
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier.width(240.dp)
        ) {
            Text(text, color = Color.Black, fontSize = 16.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
        } // Button (filled)
    } else {
        OutlinedButton(onClick = onClick, shape = RoundedCornerShape(8.dp), modifier = Modifier.width(240.dp)) {
            Text(text, color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
        } // OutlinedButton
    } // if filled / else
} // PillButton

@Composable
private fun DuelCourtView(engine: DuelEngine) {
    LaunchedEffect(Unit) {
        while (isActive) {
            withFrameNanos { now -> engine.tick(now) }
        } // while isActive
    } // LaunchedEffect(game loop)

    // Pointer events report raw device pixels; convert into the same
    // dp-equivalent space the engine's court/paddle/ball live in.
    val density = LocalDensity.current.density

    Box(
        modifier = Modifier
            .fillMaxSize()
            .pointerInput(density) {
                awaitEachGesture {
                    do {
                        val event = awaitPointerEvent()
                        if (event.changes.any { it.pressed && !it.previousPressed }) {
                            if (engine.phase == DuelPhase.SERVING) engine.serve()
                        } // if a new touch just began
                        val active = event.changes.lastOrNull { it.pressed }
                        if (active != null) {
                            engine.paddleTarget = active.position.y / density
                            active.consume()
                        } // if active != null
                    } while (event.changes.any { it.pressed })
                } // awaitEachGesture
            } // pointerInput
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            scale(scaleX = density, scaleY = density, pivot = Offset.Zero) {
            val size = engine.courtSize
            // Seam hint: a faint bar on the edge touching the other phone.
            val seamX = if (engine.isLeftSide) size.width - 3f else 0f
            drawRect(color = Color.White.copy(alpha = 0.2f), topLeft = Offset(seamX, 0f), size = Size(3f, size.height))

            drawRoundRect(
                color = Color.White,
                topLeft = Offset(engine.paddleX - engine.paddleWidth / 2, engine.paddleY - engine.paddleHeight / 2),
                size = Size(engine.paddleWidth, engine.paddleHeight),
                cornerRadius = CornerRadius(3f, 3f)
            ) // drawRoundRect (paddle)

            if (engine.ballVisible) {
                drawOval(
                    color = Color.White,
                    topLeft = Offset(engine.ballPos.x - engine.ballSize / 2, engine.ballPos.y - engine.ballSize / 2),
                    size = Size(engine.ballSize, engine.ballSize)
                ) // drawOval (ball)
            } // if ballVisible
            } // scale (density)
        } // Canvas

        Row(
            modifier = Modifier.align(Alignment.TopCenter).padding(top = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(32.dp)
        ) {
            DuelScoreBlock("YOU", engine.localScore)
            Text(":", color = Color.White.copy(alpha = 0.3f), fontSize = 32.sp, fontFamily = FontFamily.Monospace)
            DuelScoreBlock("THEM", engine.opponentScore)
        } // Row (score bar)

        when (engine.phase) {
            DuelPhase.SERVING -> Text(
                "TAP TO SERVE",
                color = Color.White,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier
                    .align(Alignment.Center)
                    .background(Color.Black.copy(alpha = 0.55f), RoundedCornerShape(12.dp))
                    .padding(16.dp)
            ) // Text (tap to serve)
            DuelPhase.WAITING_FOR_BALL -> Text(
                "OPPONENT'S SERVE…",
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace,
                modifier = Modifier.align(Alignment.Center)
            ) // Text (waiting for ball)
            else -> {} // playing / other: no status text
        } // when (engine.phase)
    } // Box
} // DuelCourtView

@Composable
private fun DuelScoreBlock(label: String, value: Int) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text("$value", color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
        Text(label, color = Color.White.copy(alpha = 0.5f), fontSize = 11.sp, fontWeight = FontWeight.Medium, fontFamily = FontFamily.Monospace)
    } // Column
} // DuelScoreBlock

@Composable
private fun DuelGameOverOverlay(engine: DuelEngine, onExit: () -> Unit) {
    Box(modifier = Modifier.fillMaxSize().padding(40.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text(
                if (engine.winnerIsMe == true) "YOU WIN" else "YOU LOSE",
                color = Color.White,
                fontSize = 40.sp,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.Monospace
            ) // Text (result)
            Text(
                "${engine.localScore} — ${engine.opponentScore}",
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold,
                fontFamily = FontFamily.Monospace
            ) // Text (final score)

            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Button(
                    onClick = { engine.requestRematch() },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White),
                    shape = RoundedCornerShape(8.dp),
                    modifier = Modifier.width(150.dp)
                ) {
                    Text("REMATCH", color = Color.Black, fontSize = 16.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                } // Button (rematch)
                OutlinedButton(onClick = onExit, shape = RoundedCornerShape(8.dp), modifier = Modifier.width(150.dp)) {
                    Text("EXIT", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
                } // OutlinedButton (exit)
            } // Row (buttons)
        } // Column
    } // Box
} // DuelGameOverOverlay
