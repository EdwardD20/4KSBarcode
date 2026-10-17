package org.danleys.barcode.transition

import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer

class ZoomThroughTransition(
    override val transitionDurationMillis: Int = 900,
    override val flashColor: Color = Color(0xFF00008B),
    override val flashDurationMillis: Int = 0,
    override val easing: Easing = LinearEasing
) : TransitionEffect {

    @Composable
    override fun Render(
        progress: Float,
        targetContent: @Composable () -> Unit,
        modifier: Modifier
    ) {
        Box(modifier = modifier.fillMaxSize()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(flashColor)
            )

            val scale = 0.08f + 0.92f * progress.coerceIn(0f, 1f)
            val alphaVal = progress.coerceIn(0f, 1f)

            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        alpha = alphaVal
                    }
            ) {
                targetContent()
            } // end Box
        } // end Box
    } // end Render
} // end class ZoomThroughTransition
