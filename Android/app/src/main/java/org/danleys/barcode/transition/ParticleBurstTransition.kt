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
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

class ParticleBurstShape(private val progress: Float) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density
    ): Outline {
        val clamped = progress.coerceIn(0f, 1f)
        if (clamped <= 0f) {
            return Outline.Generic(Path())
        } // end if (clamped <= 0f)

        val center = Offset(size.width / 2f, size.height / 2f)
        val radius = hypot(size.width.toDouble(), size.height.toDouble()).toFloat() * clamped

        val path = Path().apply {
            addOval(Rect(center.x - radius, center.y - radius, center.x + radius, center.y + radius))

            val particleCount = 14
            for (i in 0 until particleCount) {
                val angle = (i * 2 * PI / particleCount).toFloat()
                val distance = radius * 0.68f
                val pSize = maxOf(2f, radius * 0.13f)
                val px = center.x + cos(angle) * distance
                val py = center.y + sin(angle) * distance
                addOval(Rect(px - pSize / 2f, py - pSize / 2f, px + pSize / 2f, py + pSize / 2f))
            } // end for
        } // end path
        return Outline.Generic(path)
    } // end createOutline
} // end class ParticleBurstShape

class ParticleBurstTransition(
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
                        .clip(ParticleBurstShape(progress))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class ParticleBurstTransition
