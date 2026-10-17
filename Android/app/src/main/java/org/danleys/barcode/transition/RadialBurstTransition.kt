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
import kotlin.math.sin

class RadialBurstShape(
    private val progress: Float,
    private val points: Int = 12
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
        if (clampedProgress >= 0.999f) {
            return Outline.Generic(Path().apply {
                addRect(Rect(0f, 0f, size.width, size.height))
            })
        } // end if (clampedProgress >= 0.999f)

        val center = Offset(size.width / 2f, size.height / 2f)
        val radius = maxOf(size.width, size.height) * 1.5f / 2f
        val innerRadius = 0.28f + 0.72f * clampedProgress
        val outerRadius = clampedProgress * 1.2f

        val path = Path()
        val totalPoints = points * 2
        for (i in 0 until totalPoints) {
            val angle = (i * PI / points - PI / 2.0).toFloat()
            val rRatio = if (i % 2 == 0) outerRadius else innerRadius
            val r = radius * rRatio
            val x = center.x + cos(angle) * r
            val y = center.y + sin(angle) * r
            if (i == 0) {
                path.moveTo(x, y)
            } else {
                path.lineTo(x, y)
            } // end if/else
        } // end for
        path.close()
        return Outline.Generic(path)
    } // end createOutline
} // end class RadialBurstShape

class RadialBurstTransition(
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
                        .clip(RadialBurstShape(progress))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class RadialBurstTransition
