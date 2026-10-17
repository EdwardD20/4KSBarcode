package org.danleys.barcode.transition

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import kotlinx.coroutines.delay
import org.danleys.barcode.SplashRevealStyle
import kotlin.time.Duration.Companion.milliseconds

enum class TransitionState {
    SPLASH,
    FLASH,
    WIPE,
    COMPLETED
} // end enum TransitionState

/**
 * Transition host managing the screen transition pipeline from [splashContent] to [mainContent]
 * using [transitionEffect].
 */
@Composable
fun TransitionHost(
    showSplash: Boolean,
    onSplashTimeout: () -> Unit,
    transitionEffect: TransitionEffect = remember { SplashRevealStyle.random().createTransition() },
    splashContent: @Composable (onTimeout: () -> Unit) -> Unit,
    mainContent: @Composable () -> Unit
) {
    var transitionState by remember { mutableStateOf(TransitionState.SPLASH) }
    val progressAnimatable = remember { Animatable(0f) }

    LaunchedEffect(transitionState) {
        when (transitionState) {
            TransitionState.FLASH -> {
                if (transitionEffect.flashDurationMillis > 0) {
                    delay(transitionEffect.flashDurationMillis.toLong().milliseconds)
                } // end if (transitionEffect.flashDurationMillis > 0)
                transitionState = TransitionState.WIPE
            } // end TransitionState.FLASH
            TransitionState.WIPE -> {
                progressAnimatable.animateTo(
                    targetValue = 1f,
                    animationSpec = tween(
                        durationMillis = transitionEffect.transitionDurationMillis,
                        easing = transitionEffect.easing
                    )
                )
                transitionState = TransitionState.COMPLETED
                onSplashTimeout()
            } // end TransitionState.WIPE
            else -> {}
        } // end when
    } // end LaunchedEffect

    Box(modifier = Modifier.fillMaxSize()) {
        when (transitionState) {
            TransitionState.SPLASH -> {
                splashContent {
                    transitionState = if (transitionEffect.flashDurationMillis > 0) {
                        TransitionState.FLASH
                    } else {
                        TransitionState.WIPE
                    } // end if/else
                } // end splashContent
            } // end TransitionState.SPLASH
            TransitionState.FLASH, TransitionState.WIPE -> {
                transitionEffect.Render(
                    progress = progressAnimatable.value,
                    targetContent = mainContent,
                    modifier = Modifier.fillMaxSize()
                )
            } // end TransitionState.FLASH, TransitionState.WIPE
            TransitionState.COMPLETED -> {
                mainContent()
            } // end TransitionState.COMPLETED
        } // end when
    } // end Box
} // end fun TransitionHost
