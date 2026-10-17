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

class PixelMosaicShape(private val progress: Float) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density
    ): Outline {
        val clamped = progress.coerceIn(0f, 1f)
        if (clamped <= 0f) {
            return Outline.Generic(Path())
        } // end if (clamped <= 0f)

        val columns = 12
        val rows = 18
        val tileWidth = size.width / columns.toFloat()
        val tileHeight = size.height / rows.toFloat()
        val totalTiles = columns * rows

        val path = Path()
        for (row in 0 until rows) {
            for (col in 0 until columns) {
                val order = (row * 37 + col * 19 + row * col * 7) % totalTiles
                val threshold = 0.08f + (order.toFloat() / totalTiles.toFloat()) * 0.82f
                if (clamped >= threshold) {
                    val left = col * tileWidth
                    val top = row * tileHeight
                    path.addRect(Rect(left, top, left + tileWidth + 0.5f, top + tileHeight + 0.5f))
                } // end if (clamped >= threshold)
            } // end for col
        } // end for row
        return Outline.Generic(path)
    } // end createOutline
} // end class PixelMosaicShape

class PixelMosaicTransition(
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
                        .clip(PixelMosaicShape(progress))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class PixelMosaicTransition
