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

class DiagonalWipeShape(private val progress: Float) : Shape {
    override fun createOutline(
        size: Size,
        layoutDirection: LayoutDirection,
        density: Density
    ): Outline {
        val clamped = progress.coerceIn(0f, 1f)
        if (clamped <= 0f) {
            return Outline.Generic(Path())
        } // end if (clamped <= 0f)
        if (clamped >= 0.999f) {
            return Outline.Generic(Path().apply {
                addRect(Rect(0f, 0f, size.width, size.height))
            })
        } // end if (clamped >= 0.999f)

        val corners = listOf(
            Offset(0f, 0f),
            Offset(size.width, 0f),
            Offset(size.width, size.height),
            Offset(0f, size.height)
        )
        val limit = clamped * 2f
        val clippedPoints = mutableListOf<Offset>()

        for (i in corners.indices) {
            val start = corners[i]
            val end = corners[(i + 1) % corners.size]
            val startVal = start.x / size.width + start.y / size.height
            val endVal = end.x / size.width + end.y / size.height
            val startInside = startVal <= limit
            val endInside = endVal <= limit

            if (startInside) {
                clippedPoints.add(start)
            } // end if (startInside)
            if (startInside != endInside) {
                val fraction = (limit - startVal) / (endVal - startVal)
                clippedPoints.add(
                    Offset(
                        start.x + (end.x - start.x) * fraction,
                        start.y + (end.y - start.y) * fraction
                    )
                )
            } // end if (startInside != endInside)
        } // end for

        val path = Path()
        if (clippedPoints.isNotEmpty()) {
            path.moveTo(clippedPoints.first().x, clippedPoints.first().y)
            for (pt in clippedPoints.drop(1)) {
                path.lineTo(pt.x, pt.y)
            } // end for
            path.close()
        } // end if (clippedPoints.isNotEmpty())
        return Outline.Generic(path)
    } // end createOutline
} // end class DiagonalWipeShape

class DiagonalWipeTransition(
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
                        .clip(DiagonalWipeShape(progress))
                ) {
                    targetContent()
                } // end Box
            } // end if (progress > 0f)
        } // end Box
    } // end Render
} // end class DiagonalWipeTransition
