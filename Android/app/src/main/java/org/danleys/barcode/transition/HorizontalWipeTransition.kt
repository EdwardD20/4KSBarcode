package org.danleys.barcode.transition

import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection

class HorizontalWipeShape(private val progress: Float) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density
    ): Outline {
        val clamped = progress.coerceIn(0f, 1f)
        if (clamped <= 0f) {
            return Outline.Generic(Path())
        } // end if (clamped <= 0f)

        val path = Path().apply {
            addRect(Rect(0f, 0f, size.width * clamped, size.height))
        } // end path
        return Outline.Generic(path)
    } // end createOutline
} // end class HorizontalWipeShape

class HorizontalWipeTransition(
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

            if (progress > 0f) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(HorizontalWipeShape(progress))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class HorizontalWipeTransition
