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

class ShutterBladesShape(private val progress: Float) : Shape {
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
        val radius = hypot(size.width.toDouble(), size.height.toDouble()).toFloat() * 0.8f
        val bladeCount = 6
        val halfAngle = (clamped * PI / bladeCount).toFloat()
        val rotation = ((1f - clamped) * PI / 5.0).toFloat()

        val path = Path()
        for (blade in 0 until bladeCount) {
            val angle = (blade * 2f * PI / bladeCount + rotation).toFloat()
            val edge1 = Offset(
                center.x + cos(angle - halfAngle) * radius,
                center.y + sin(angle - halfAngle) * radius
            )
            val edge2 = Offset(
                center.x + cos(angle + halfAngle) * radius,
                center.y + sin(angle + halfAngle) * radius
            )
            path.moveTo(center.x, center.y)
            path.lineTo(edge1.x, edge1.y)
            path.lineTo(edge2.x, edge2.y)
            path.close()
        } // end for
        return Outline.Generic(path)
    } // end createOutline
} // end class ShutterBladesShape

class ShutterBladesTransition(
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
                        .clip(ShutterBladesShape(progress))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class ShutterBladesTransition
