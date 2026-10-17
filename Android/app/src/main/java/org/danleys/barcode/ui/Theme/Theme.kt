package org.danleys.barcode.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalContext

// ---- Basic palette (tweak if you want custom branding) ----
private val LightColors: ColorScheme = lightColorScheme(
    primary = androidx.compose.ui.graphics.Color(0xFF006D3A),
    onPrimary = androidx.compose.ui.graphics.Color.White,
    secondary = androidx.compose.ui.graphics.Color(0xFF2F5DA8),
    onSecondary = androidx.compose.ui.graphics.Color.White,
    background = androidx.compose.ui.graphics.Color(0xFFFFFBFF),
    onBackground = androidx.compose.ui.graphics.Color(0xFF1C1B1F),
    surface = androidx.compose.ui.graphics.Color(0xFFFFFBFF),
    onSurface = androidx.compose.ui.graphics.Color(0xFF1C1B1F)
) // val LightColors

private val DarkColors: ColorScheme = darkColorScheme(
    primary = androidx.compose.ui.graphics.Color(0xFF4CD38E),
    onPrimary = androidx.compose.ui.graphics.Color(0xFF00371D),
    secondary = androidx.compose.ui.graphics.Color(0xFFACC7FF),
    onSecondary = androidx.compose.ui.graphics.Color(0xFF0A2D67),
    background = androidx.compose.ui.graphics.Color(0xFF1C1B1F),
    onBackground = androidx.compose.ui.graphics.Color(0xFFE6E1E5),
    surface = androidx.compose.ui.graphics.Color(0xFF1C1B1F),
    onSurface = androidx.compose.ui.graphics.Color(0xFFE6E1E5)
) // val DarkColors

@Composable
fun BarcodeTheme(
    useDarkTheme: Boolean = isSystemInDarkTheme(),
    useDynamicColor: Boolean = true,
    content: @Composable () -> Unit
) {
    val context = LocalContext.current
    val colorScheme =
        if (useDynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Dynamic color (Android 12+) follows user’s wallpaper/theme
            if (useDarkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        } else {
            if (useDarkTheme) DarkColors else LightColors
        } // val colorScheme

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    ) // MaterialTheme
} // fun BarcodeTheme