//
// XPaddle
// XPaddleSettingsView.kt
//

package org.danleys.xpaddle

import android.content.Context
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeOff
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlin.time.Duration.Companion.milliseconds
import androidx.core.content.edit

/// Shared, app-wide toggles configured from the Settings screen and read by
/// GameEngine during single-device play. One instance is created in
/// XPaddleApp and passed to both the engine and this screen, so a change
/// here takes effect immediately with no extra plumbing. Backed by
/// SharedPreferences so toggles survive an app restart, not just rotation.
class GameSettings(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val _soundEnabled = mutableStateOf(prefs.getBoolean(KEY_SOUND_ENABLED, true))
    var soundEnabled: Boolean
        get() = _soundEnabled.value
        set(value) {
            _soundEnabled.value = value
            prefs.edit { putBoolean(KEY_SOUND_ENABLED, value) }
        } // set

    private val _smarterAI = mutableStateOf(prefs.getBoolean(KEY_SMARTER_AI, false))
    var smarterAI: Boolean
        get() = _smarterAI.value
        set(value) {
            _smarterAI.value = value
            prefs.edit { putBoolean(KEY_SMARTER_AI, value) }
        } // set

    private val _blackHoleEnabled = mutableStateOf(prefs.getBoolean(KEY_BLACK_HOLE_ENABLED, false))
    var blackHoleEnabled: Boolean
        get() = _blackHoleEnabled.value
        set(value) {
            _blackHoleEnabled.value = value
            prefs.edit { putBoolean(KEY_BLACK_HOLE_ENABLED, value) }
        } // set

    companion object {
        private const val PREFS_NAME = "xpaddle_settings"
        private const val KEY_SOUND_ENABLED = "sound_enabled"
        private const val KEY_SMARTER_AI = "smarter_ai"
        private const val KEY_BLACK_HOLE_ENABLED = "black_hole_enabled"
    } // companion object
} // class GameSettings

/// The Settings screen, reached from a button on the main menu. Kept as its
/// own module so game-wide options (sound, difficulty, extra mechanics —
/// added incrementally) have one place to live, separate from gameplay.
/// Deliberately plain: solid blue background, no score/paddles/net/ball.
@Composable
fun XPaddleSettingsView(settings: GameSettings, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBlue)
            .padding(horizontal = 32.dp)
            .padding(top = 60.dp, bottom = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("SETTINGS", color = GameYellow, fontSize = 34.sp, fontWeight = FontWeight.Black, fontFamily = FontFamily.Monospace)

        // Sound: shown as the standard volume icon (filled when on, a
        // crossed-out volume icon when off) rather than the word "Sound".
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = if (settings.soundEnabled) Icons.AutoMirrored.Filled.VolumeUp else Icons.AutoMirrored.Filled.VolumeOff,
                contentDescription = if (settings.soundEnabled) "Sound on" else "Sound off",
                tint = GameYellow,
                modifier = Modifier.size(32.dp)
            ) // Icon (sound)
            Switch(
                checked = settings.soundEnabled,
                onCheckedChange = { settings.soundEnabled = it },
                colors = SwitchDefaults.colors(checkedThumbColor = GameYellow, checkedTrackColor = GameYellow.copy(alpha = 0.5f))
            ) // Switch (sound)
        } // Row (sound setting)

        // Black Hole: shown as its own icon rather than the words "Black
        // Hole" — a static icon when off, the spinning 3-frame animation
        // when on, so the toggle previews what it turns on.
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            var frame by remember { mutableIntStateOf(0) }
            LaunchedEffect(settings.blackHoleEnabled) {
                while (settings.blackHoleEnabled) {
                    delay(120.milliseconds)
                    frame = (frame + 1) % 3
                } // while blackHoleEnabled
            } // LaunchedEffect(blackHoleEnabled)

            val iconRes = if (settings.blackHoleEnabled) {
                when (frame) {
                    0 -> R.drawable.black_hole_0
                    1 -> R.drawable.black_hole_1
                    else -> R.drawable.black_hole_2
                } // when frame
            } else {
                R.drawable.black_hole_icon
            } // val iconRes
            Image(
                painter = painterResource(id = iconRes),
                contentDescription = if (settings.blackHoleEnabled) "Black Hole on" else "Black Hole off",
                modifier = Modifier.size(32.dp)
            ) // Image (black hole icon)
            Switch(
                checked = settings.blackHoleEnabled,
                onCheckedChange = { settings.blackHoleEnabled = it },
                colors = SwitchDefaults.colors(checkedThumbColor = GameYellow, checkedTrackColor = GameYellow.copy(alpha = 0.5f))
            ) // Switch (black hole)
        } // Row (black hole setting)

        // Smarter AI: on = today's tracking AI at its usual speed; off = the
        // AI paddle holds still until the ball is on its side of the court,
        // then reacts at half speed — an easier default for the 1P mode.
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("SMARTER AI", color = GameYellow, fontSize = 16.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
            Switch(
                checked = settings.smarterAI,
                onCheckedChange = { settings.smarterAI = it },
                colors = SwitchDefaults.colors(checkedThumbColor = GameYellow, checkedTrackColor = GameYellow.copy(alpha = 0.5f))
            ) // Switch (smarter AI)
        } // Row (smarter AI setting)

        // Moved here from the main menu overlay.
        Text(
            "Drag on your half to move your paddle\n" +
                "First to ${GameEngine.WINNING_SCORE} wins\n\n" +
                "Play Nearby: hold two phones side by side\n" +
                "and rally the ball across both screens",
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            fontFamily = FontFamily.Monospace,
            textAlign = TextAlign.Center
        ) // Text (instructions, moved here from the main menu)

        Button(
            onClick = onBack,
            colors = ButtonDefaults.buttonColors(containerColor = GameYellow),
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier.width(200.dp)
        ) {
            Text("BACK", color = Color.Black, fontSize = 16.sp, fontWeight = FontWeight.Bold, fontFamily = FontFamily.Monospace)
        } // Button (back)
    } // Column
} // XPaddleSettingsView
