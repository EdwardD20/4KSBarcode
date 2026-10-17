package org.danleys.barcode.transition

import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.hypot

/**
 * Custom [Shape] that clips content to an expanding circle centered on [centerOffsetRatio]
 * based on the animation [progress] (0.0f to 1.0f).
 */
class CircularWipeShape(
    private val progress: Float,
    private val centerOffsetRatio: Offset = Offset(0.5f, 0.5f)
) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density
    ): Outline {
        val clampedProgress = progress.coerceIn(0f, 1f)
        if (clampedProgress <= 0f) {
            return Outline.Generic(Path())
        } // end if (clampedProgress <= 0f)

        val centerX = size.width * centerOffsetRatio.x
        val centerY = size.height * centerOffsetRatio.y

        val maxDistX = maxOf(centerX, size.width - centerX)
        val maxDistY = maxOf(centerY, size.height - centerY)
        val maxRadius = hypot(maxDistX.toDouble(), maxDistY.toDouble()).toFloat()

        val currentRadius = maxRadius * clampedProgress

        val path = Path().apply {
            addOval(
                Rect(
                    left = centerX - currentRadius,
                    top = centerY - currentRadius,
                    right = centerX + currentRadius,
                    bottom = centerY + currentRadius
                )
            )
        } // end path
        return Outline.Generic(path)
    } // end createOutline
} // end class CircularWipeShape

/**
 * Circular wipe transition effect.
 *
 * Flashes [flashColor] (DarkBlue by default) then performs a circular wipe
 * over [transitionDurationMillis] (0.9 seconds by default).
 */
class CircularWipeTransition(
    override val transitionDurationMillis: Int = 900,
    override val flashColor: Color = Color(0xFF00008B), // DarkBlue
    override val flashDurationMillis: Int = 0,
    override val easing: Easing = LinearEasing,
    private val centerOffsetRatio: Offset = Offset(0.5f, 0.5f)
) : TransitionEffect {

    @Composable
    override fun Render(
        progress: Float,
        targetContent: @Composable () -> Unit,
        modifier: Modifier
    ) {
        Box(modifier = modifier.fillMaxSize()) {
            // Darkblue flash background layer
            flashColor?.let { color ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(color)
                )
            } // end flashColor?.let

            // Main display content clipped by the expanding circle
            if (progress > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(CircularWipeShape(progress, centerOffsetRatio))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class CircularWipeTransition
