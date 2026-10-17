package org.danleys.barcode

import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import kotlinx.coroutines.delay

// ============================================================
// BottomBarLayout - shared container for any screen
// ============================================================
@Composable
fun BottomBarLayout(
    modifier: Modifier = Modifier,
    pantryLabel: String,
    dealsLabel: String,
    onPantryTap: () -> Unit,
    onDealsTap: () -> Unit,
    content: @Composable () -> Unit
) {
    val barHeight = 56.dp

    Box(
        modifier = modifier.fillMaxSize()
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = barHeight)
        ) {
            content()
        } // end Box

        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(barHeight)
                .windowInsetsPadding(WindowInsets.navigationBars)
        ) {
            BottomShadedBarGeometry(
                heightDp = barHeight,
                modifier = Modifier.matchParentSize()
            ) // BottomShadedBarGeometry

            BottomMessageSwitcher(
                heightDp = barHeight,
                pantryLabel = pantryLabel,
                dealsLabel = dealsLabel,
                onPantryHours = onPantryTap,
                onFeelGoodDeals = onDealsTap,
                modifier = Modifier.matchParentSize()
            ) // BottomMessageSwitcher
        } // Box (single bottom bar)
    } // Box (root layout)
} // fun BottomBarLayout

// ============================================================
// Bottom bar background
// ============================================================
@Composable
fun BottomShadedBarGeometry(
    heightDp: Dp,
    modifier: Modifier = Modifier
) {
    val base = MaterialTheme.colorScheme.surfaceVariant
    val divider = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.08f)

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(heightDp)
            .background(base)
    ) {
        // Gradient overlay
        Box(
            modifier = Modifier
                .matchParentSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.Black.copy(alpha = 0.08f),
                            Color.Black.copy(alpha = 0.03f),
                            Color.Transparent
                        )
                    )
                )
        ) // Box (Gradient overlay)

        // Thin top divider line
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(0.5.dp)
                .background(divider)
                .align(Alignment.TopCenter)
        ) // Divider line
    } // Box
} // fun BottomShadedBarGeometry

// ============================================================
// Alternating Message Banner (Pantry Hours / Feel Good Deals)
// ============================================================
@Composable
fun BottomMessageSwitcher(
    heightDp: Dp,
    modifier: Modifier = Modifier,
    pantryLabel: String,
    dealsLabel: String,
    onPantryHours: () -> Unit,
    onFeelGoodDeals: () -> Unit
) {
    val isDark = MaterialTheme.colorScheme.background.luminance() < 0.5f
    val textColor = if (isDark) Color.White else Color.Red
    val bgColor = if (isDark) Color.Red else Color.Transparent

    var showFirst by remember { mutableStateOf(true) }

    // Switch every 10 seconds
    LaunchedEffect(Unit) {
        while (true) {
            delay(10_000)
            showFirst = !showFirst
        } // while
    } // LaunchedEffect

    // Dynamic font size based on text length
    fun dynamicFontSize(text: String): Float {
        return when {
            text.length <= 20 -> 22f
            text.length <= 30 -> 18f
            else -> 14f
        } // when
    } // fun dynamicFontSize

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(heightDp)
            .background(bgColor)
            .clickable {
                if (showFirst) {
                    onPantryHours()
                } else {
                    onFeelGoodDeals()
                } // if (showFirst)
            } // clickable
    ) {
        if (showFirst) {
            // Pantry hours text only
            Text(
                text = pantryLabel,
                color = textColor,
                fontWeight = FontWeight.Bold,
                fontSize = dynamicFontSize(pantryLabel).sp,
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(horizontal = 12.dp)
            ) // Text (pantryLabel)
        } else {
            // Feel Good Deals + Facebook icon
            Row(
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(horizontal = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(
                    painter = painterResource(id = R.drawable.ic_facebook),
                    contentDescription = null,
                    tint = Color.Unspecified,      // keep brand colors
                    modifier = Modifier
                        .size(24.dp)
                        .padding(end = 8.dp)
                ) // Icon

                Text(
                    text = dealsLabel,
                    color = textColor,
                    fontWeight = FontWeight.Bold,
                    fontSize = dynamicFontSize(dealsLabel).sp,
                    maxLines = 1
                ) // Text (dealsLabel)
            } // Row (Deals content)
        } // if (showFirst)
    } // Box (Message container)
} // fun BottomMessageSwitcher

// ============================================================
// GraphicDialog
// ============================================================
@Composable
fun GraphicDialog(
    onClose: () -> Unit,
    @StringRes title: Int,
    @DrawableRes graphic: Int
) {
    val config = LocalConfiguration.current
    val isLandscape = config.screenWidthDp > config.screenHeightDp

    Dialog(onDismissRequest = onClose) {
        Surface(
            shape = RoundedCornerShape(12.dp),
            tonalElevation = 6.dp
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(MaterialTheme.colorScheme.surface)
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    TextButton(
                        onClick = onClose,
                        modifier = Modifier.align(Alignment.End)
                    ) {
                        Text(text = stringResource(id = R.string.close_button))
                    } // TextButton (Close)

                    ZoomableImage(
                        imageRes = graphic,
                        contentDescription = stringResource(id = title),
                        modifier = if (isLandscape)
                            Modifier.fillMaxHeight()
                        else
                            Modifier.fillMaxWidth()
                    ) // ZoomableImage
                } // end Column
            } // end Box
        } // end Surface
    } // end Dialog
} // fun GraphicDialog

// ============================================================
// ZoomableImage
// ============================================================
@Composable
fun ZoomableImage(
    @DrawableRes imageRes: Int,
    contentDescription: String,
    modifier: Modifier = Modifier
) {
    var scale by remember { mutableFloatStateOf(1f) }
    var offset by remember { mutableStateOf(Offset.Zero) }
    val minScale = 1f
    val maxScale = 4f

    val gestureModifier = Modifier
        .pointerInput(Unit) {
            detectTransformGestures { _, pan, zoom, _ ->
                val newScale = (scale * zoom).coerceIn(minScale, maxScale)
                val newOffset = if (newScale > minScale) offset + pan else Offset.Zero
                scale = newScale
                offset = newOffset
            } // detectTransformGestures
        } // pointerInput (Transform)
        .pointerInput(Unit) {
            detectTapGestures(
                onDoubleTap = {
                    if (scale > minScale + 0.01f) {
                        scale = minScale
                        offset = Offset.Zero
                    } else {
                        scale = 2f
                    } // if (scale)
                } // onDoubleTap
            ) // detectTapGestures
        } // pointerInput (Tap)
        .graphicsLayer {
            translationX = offset.x
            translationY = offset.y
            scaleX = scale
            scaleY = scale
        } // graphicsLayer

    Image(
        painter = painterResource(id = imageRes),
        contentDescription = contentDescription,
        contentScale = ContentScale.Fit,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .background(Color.Transparent)
            .then(gestureModifier)
            .fillMaxSize()
    ) // Image
} // fun ZoomableImage

// ============================================================
// MediumWidthButton
// ============================================================
@Composable
fun MediumWidthButton(
    text: String,
    onClick: () -> Unit,
    icon: Int? = null,
    enabled: Boolean = true
) {
    val screenDp = LocalConfiguration.current.screenWidthDp.dp
    val maxW = minOf(280.dp, screenDp * 0.6f) // up to 60% of screen, capped at 280dp

    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .widthIn(min = 160.dp, max = maxW)
            .padding(horizontal = 8.dp), // breathing room
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Black,
            contentColor = Color.White,
            disabledContainerColor = Color.Black.copy(alpha = 0.3f),
            disabledContentColor = Color.White.copy(alpha = 0.5f)
        ),
        contentPadding = PaddingValues(vertical = 12.dp)
    ) {
        if (icon != null) {
            Icon(
                painter = painterResource(id = R.drawable.ic_facebook),
                contentDescription = null,
                tint = Color.Unspecified,      // keep brand colors
                modifier = Modifier
                    .size(28.dp)
                    .padding(end = 8.dp)
            ) // Icon
        } // if (icon)

        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold)
        ) // end Text
    } // end Button
} // fun MediumWidthButton
