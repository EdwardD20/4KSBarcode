package org.danleys.barcode.transition

import androidx.compose.animation.core.Easing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

/**
 * Interface representing a screen transition effect.
 * Designed to be modular and extensible so custom transitions (e.g., circular wipe, fade, slide)
 * can be plugged into the transition pipeline.
 */
interface TransitionEffect {
    /**
     * Duration of the main transition animation in milliseconds.
     */
    val transitionDurationMillis: Int

    /**
     * Optional flash color displayed before the wipe/transition animation begins.
     */
    val flashColor: Color?

    /**
     * Duration of the flash effect in milliseconds.
     */
    val flashDurationMillis: Int

    /**
     * Easing curve for the transition animation.
     */
    val easing: Easing get() = LinearEasing

    /**
     * Render the transition layout at a given progress [0.0f .. 1.0f].
     *
     * @param progress Progress of the transition from 0.0 (start/source) to 1.0 (end/target).
     * @param targetContent The composable for the main/target screen.
     * @param modifier Modifier for the transition container.
     */
    @Composable
    fun Render(
        progress: Float,
        targetContent: @Composable () -> Unit,
        modifier: Modifier
    )
} // end interface TransitionEffect
