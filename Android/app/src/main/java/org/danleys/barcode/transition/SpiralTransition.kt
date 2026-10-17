package org.danleys.barcode.transition

import android.graphics.Paint
import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.graphics.asComposePath
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

class SpiralShape(private val progress: Float) : Shape {
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
        val maxRadius = hypot(size.width.toDouble(), size.height.toDouble()).toFloat() * 0.72f
        val steps = 180
        val turns = 3.2f

        val centerline = Path()
        for (step in 0..steps) {
            val fraction = step.toFloat() / steps.toFloat()
            val angle = (fraction * turns * 2f * PI - clamped * PI * 0.6f).toFloat()
            val radius = maxRadius * clamped * fraction
            val x = center.x + cos(angle) * radius
            val y = center.y + sin(angle) * radius

            if (step == 0) {
                centerline.moveTo(x, y)
            } else {
                centerline.lineTo(x, y)
            } // end if/else
        } // end for

        val strokeWidth = maxRadius * 0.34f * clamped
        val paint = Paint().apply {
            style = Paint.Style.STROKE
            this.strokeWidth = strokeWidth
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        } // end paint

        val filledAndroidPath = android.graphics.Path()
        paint.getFillPath(centerline.asAndroidPath(), filledAndroidPath)

        return Outline.Generic(filledAndroidPath.asComposePath())
    } // end createOutline
} // end class SpiralShape

class SpiralTransition(
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
                        .clip(SpiralShape(progress))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class SpiralTransition
