package org.danleys.barcode

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.core.graphics.createBitmap
import androidx.core.graphics.set
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatWriter
import com.google.zxing.common.BitMatrix
import kotlin.math.roundToInt

@Composable
fun BarcodeGenerator(
    data: String,
    mode: String = "barcode"
) {
    val config = LocalConfiguration.current
    val density = LocalDensity.current

    val isLandscape = config.screenWidthDp > config.screenHeightDp

    // Portrait: 80% of width (matches iOS), Landscape: 50% of width
    val widthFraction = if (isLandscape) 0.5f else 0.8f

    val screenWidthDp = config.screenWidthDp.dp
    val screenHeightDp = config.screenHeightDp.dp
    val barcodeWidthDp = screenWidthDp * widthFraction

    // For QR code, we want a square. For barcode, a 2:1 ratio.
    val barcodeHeightDp = if (mode == "qrcode") {
        barcodeWidthDp
    } else if (isLandscape) {
        minOf(barcodeWidthDp / 2f, screenHeightDp * 0.4f)
    } else {
        barcodeWidthDp / 2f    // 2:1 aspect ratio (W:H)
    } // if (barcodeHeightDp)

    val widthPx: Int
    val heightPx: Int
    with(density) {
        widthPx = barcodeWidthDp.toPx().roundToInt()
        heightPx = barcodeHeightDp.toPx().roundToInt()
    } // with (density)

    val bitmap = remember(data, widthPx, heightPx, mode) {
        generateCodeBitmap(
            data = data,
            widthPx = widthPx,
            heightPx = heightPx,
            format = if (mode == "qrcode") BarcodeFormat.QR_CODE else BarcodeFormat.CODE_128
        )
    } // remember (bitmap)

    // FULL-WIDTH white background for dark mode scanner compatibility
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                // Pure white background extends full width for maximum scanner contrast
                .background(Color.White)
                .padding(vertical = 16.dp, horizontal = 12.dp),
            contentAlignment = Alignment.Center
        ) {
            Image(
                bitmap = bitmap.asImageBitmap(),
                contentDescription = if (mode == "qrcode") "QR Code" else "Barcode",
                contentScale = ContentScale.FillBounds,
                modifier = Modifier
                    .width(barcodeWidthDp)
                    .height(barcodeHeightDp)
            ) // Image
        } // Box (White background)
    } // Column (Barcode wrapper)
} // fun BarcodeGenerator

private fun generateCodeBitmap(
    data: String,
    widthPx: Int,
    heightPx: Int,
    format: BarcodeFormat
): Bitmap {
    val writer = MultiFormatWriter()
    val hints = hashMapOf<EncodeHintType, Any>(
        EncodeHintType.MARGIN to 0 // remove ZXing quiet zone
    ) // hashMapOf (hints)

    val matrix: BitMatrix = writer.encode(
        data,
        format,
        widthPx,
        heightPx,
        hints
    ) // BitMatrix (encode)

    val bmp = createBitmap(matrix.width, matrix.height, Bitmap.Config.ARGB_8888)

    for (y in 0 until matrix.height) {
        for (x in 0 until matrix.width) {
            bmp[x, y] = if (matrix[x, y]) {
                0xFF000000.toInt()      // black bar
            } else {
                0xFFFFFFFF.toInt()      // white background
            } // if
        } // for x
    } // for y

    return bmp
} // fun generateCodeBitmap