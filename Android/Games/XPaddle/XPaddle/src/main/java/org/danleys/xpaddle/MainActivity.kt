//
// XPaddle
// MainActivity.kt
//

package org.danleys.xpaddle

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/// Adapted from: https://github.com/rickyjonesus/pong (original iOS/SwiftUI XPaddle)
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // Mirrors the iOS app's .statusBarHidden(true) / .persistentSystemOverlays(.hidden):
        // an immersive, fullscreen court with system bars swipeable back in.
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } // WindowInsetsControllerCompat

        setContent {
            XPaddleApp()
        } // setContent
    } // onCreate
} // class MainActivity
