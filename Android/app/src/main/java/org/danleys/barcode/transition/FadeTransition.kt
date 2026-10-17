package org.danleys.barcode.transition

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer

/**
 * Fade transition effect demonstrating extensibility of [TransitionEffect].
 */
class FadeTransition(
    override val transitionDurationMillis: Int = 500,
    override val flashColor: Color? = null,
    override val flashDurationMillis: Int = 0
) : TransitionEffect {

    @Composable
    override fun Render(
        progress: Float,
        targetContent: @Composable () -> Unit,
        modifier: Modifier
    ) {
        Box(modifier = modifier.fillMaxSize()) {
            flashColor?.let { color ->
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(color)
                )
            } // end flashColor?.let
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .graphicsLayer { alpha = progress.coerceIn(0f, 1f) }
            ) {
                targetContent()
            } // end Box
        } // end Box
    } // end Render
} // end class FadeTransition
