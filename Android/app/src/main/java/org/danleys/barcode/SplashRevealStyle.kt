package org.danleys.barcode

import org.danleys.barcode.transition.CircularWipeTransition
import org.danleys.barcode.transition.DiagonalWipeTransition
import org.danleys.barcode.transition.HorizontalWipeTransition
import org.danleys.barcode.transition.IrisOpeningTransition
import org.danleys.barcode.transition.LightFlashTransition
import org.danleys.barcode.transition.PanelRevealTransition
import org.danleys.barcode.transition.ParticleBurstTransition
import org.danleys.barcode.transition.PixelMosaicTransition
import org.danleys.barcode.transition.RadialBurstTransition
import org.danleys.barcode.transition.ShutterBladesTransition
import org.danleys.barcode.transition.SpiralTransition
import org.danleys.barcode.transition.TransitionEffect
import org.danleys.barcode.transition.ZoomThroughTransition

enum class SplashRevealStyle {
    CIRCULAR_WIPE,
    RADIAL_BURST,
    IRIS_OPENING,
    PARTICLE_BURST,
    ZOOM_THROUGH,
    LIGHT_FLASH,
    PANEL_REVEAL,
    HORIZONTAL_WIPE,
    DIAGONAL_WIPE,
    SPIRAL,
    PIXEL_MOSAIC,
    SHUTTER_BLADES;

    fun createTransition(): TransitionEffect {
        return when (this) {
            CIRCULAR_WIPE -> CircularWipeTransition()
            RADIAL_BURST -> RadialBurstTransition()
            IRIS_OPENING -> IrisOpeningTransition()
            PARTICLE_BURST -> ParticleBurstTransition()
            ZOOM_THROUGH -> ZoomThroughTransition()
            LIGHT_FLASH -> LightFlashTransition()
            PANEL_REVEAL -> PanelRevealTransition()
            HORIZONTAL_WIPE -> HorizontalWipeTransition()
            DIAGONAL_WIPE -> DiagonalWipeTransition()
            SPIRAL -> SpiralTransition()
            PIXEL_MOSAIC -> PixelMosaicTransition()
            SHUTTER_BLADES -> ShutterBladesTransition()
        } // end when
    } // end createTransition

    companion object {
        fun random(): SplashRevealStyle {
            return entries.random()
        } // end random
    } // end companion object
} // end enum SplashRevealStyle
