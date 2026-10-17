package org.danleys.barcode

import android.Manifest
import android.annotation.SuppressLint
import android.util.Log
import android.view.ScaleGestureDetector
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.core.content.ContextCompat
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun BarcodeScannerScreen(
    onDismiss: () -> Unit,
    onCodeScanned: (String) -> Unit
) {
    val cameraPermissionState = rememberPermissionState(Manifest.permission.CAMERA)

    LaunchedEffect(Unit) {
        if (!cameraPermissionState.status.isGranted) {
            cameraPermissionState.launchPermissionRequest()
        } // if
    } // LaunchedEffect

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier.fillMaxSize()
        ) {
            if (cameraPermissionState.status.isGranted) {
                CameraPreview(
                    onCodeScanned = onCodeScanned
                )
            } else {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp)
                        .align(Alignment.Center)
                ) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text("Camera permission required")
                        Spacer(modifier = Modifier.height(8.dp))
                        Button(onClick = {cameraPermissionState.launchPermissionRequest() }) {
                            Text("Grant Permission")
                        } // Button
                    } // Column
                } // Card
            } // if/else

            // Cancel button
            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 32.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = MaterialTheme.colorScheme.surface.copy(alpha = 0.8f)
                )
            ) {
                Text("Cancel")
            } // Button (Cancel)
        } // Box
    } // Dialog
} // fun BarcodeScannerScreen

@SuppressLint("ClickableViewAccessibility")
@Composable
fun CameraPreview(
    onCodeScanned: (String) -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    val cameraProviderFuture = remember {
        ProcessCameraProvider.getInstance(context)
    }

    val executor = remember {
        Executors.newSingleThreadExecutor()
    }

    val barcodeScanner = remember {
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(
                Barcode.FORMAT_CODE_128,
                Barcode.FORMAT_QR_CODE,
                Barcode.FORMAT_CODE_39
            )
            .build()
        BarcodeScanning.getClient(options)
    } // remember (barcodeScanner)

    var hasScanned by remember {
        mutableStateOf(false)
    }

    var camera by remember {
        mutableStateOf<Camera?>(null)
    }

    Box(
        modifier = Modifier.fillMaxSize()
    ) {
        AndroidView(
            factory = {ctx ->
                val previewView = PreviewView(ctx).apply {
                    implementationMode = PreviewView.ImplementationMode.COMPATIBLE
                }

                // Pinch-to-zoom support
                val scaleGestureDetector =
                    ScaleGestureDetector(
                        ctx,
                        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
                            override fun onScale(detector: ScaleGestureDetector): Boolean {
                                val currentZoom =
                                    camera?.cameraInfo?.zoomState?.value?.zoomRatio ?: 1f
                                val newZoom = currentZoom * detector.scaleFactor
                                camera?.cameraControl?.setZoomRatio(newZoom)
                                return true
                            } // onScale
                        } // SimpleOnScaleGestureListener
                    ) // ScaleGestureDetector

                previewView.setOnTouchListener { _, event ->
                    scaleGestureDetector.onTouchEvent(event)
                    true
                } // setOnTouchListener

                cameraProviderFuture.addListener({
                    try {
                        val cameraProvider = cameraProviderFuture.get()
                        Log.d("CAMERA_DEBUG", "CameraProvider obtained")

                        val preview = Preview.Builder().build()

                        val imageAnalysis = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                            .also { analysis ->
                                var frameCount = 0
                                analysis.setAnalyzer(
                                    executor,
                                    @ExperimentalGetImage
                                    { imageProxy ->
                                        if (++frameCount % 60 == 0) {
                                            Log.d("CAMERA_DEBUG", "Frames received by analyzer: $frameCount")
                                        } // if
                                        if (!hasScanned) {
                                            processImageProxy(
                                                imageProxy = imageProxy,
                                                barcodeScanner = barcodeScanner
                                            ) { code ->
                                                hasScanned = true
                                                onCodeScanned(code)
                                            } // processImageProxy
                                        } else {
                                            imageProxy.close()
                                        } // if (!hasScanned)
                                    } // setAnalyzer lambda
                                ) // setAnalyzer
                            } // also

                        val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                        cameraProvider.unbindAll()

                        // Small delay to ensure surface is ready
                        previewView.postDelayed({
                            try {
                                camera = cameraProvider.bindToLifecycle(
                                    lifecycleOwner,
                                    cameraSelector,
                                    preview,
                                    imageAnalysis
                                )
                                preview.surfaceProvider = previewView.surfaceProvider
                                Log.d("CAMERA_DEBUG", "Camera bound successfully. PreviewView size: ${previewView.width}x${previewView.height}")
                            } catch (e: Exception) {
                                Log.e("CAMERA_DEBUG", "Late binding failed", e)
                            } // end try-catch
                        }, 500) // end postDelayed

                    } catch (e: Exception) {
                        Log.e("CAMERA_DEBUG", "Camera initialization failed", e)
                    } // end try-catch
                }, ContextCompat.getMainExecutor(ctx)) // end addListener

                previewView
            }, // AndroidView factory
            modifier = Modifier.fillMaxSize()
        ) // AndroidView

        ScanBoxOverlay() // Scan box
    } // Box (Camera preview content)

    DisposableEffect(Unit) {
        onDispose {
            executor.shutdown()
            barcodeScanner.close()
        } // onDispose
    } // DisposableEffect
} // fun CameraPreview

@Composable
fun ScanBoxOverlay() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Canvas(
            modifier = Modifier.size(260.dp)
        ) {
            val strokeWidth = 6f
            drawRect(
                color = Color.Green,
                style = Stroke(width = strokeWidth)
            ) // drawRect
            // Horizontal scan line
            drawLine(
                color = Color.Green,
                start = Offset(0f, size.height / 2),
                end = Offset(size.width, size.height / 2),
                strokeWidth = 4f,
                cap = StrokeCap.Round
            ) // drawLine
        } // Canvas
    } // Box
} // fun ScanBoxOverlay

@ExperimentalGetImage
private fun processImageProxy(
    imageProxy: ImageProxy,
    barcodeScanner: com.google.mlkit.vision.barcode.BarcodeScanner,
    onCodeScanned: (String) -> Unit
) {
    val mediaImage = imageProxy.image
    if (mediaImage != null) {
        val image = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
        Log.d("CAMERA_DEBUG", "Processing image with ML Kit...")

        barcodeScanner.process(image)
            .addOnSuccessListener { barcodes ->
                for (barcode in barcodes) {
                    val code = barcode.rawValue ?: ""
                    if (code.isNotEmpty()) {
                        Log.d("BarcodeScanner", "✅ Scanned: $code")
                        onCodeScanned(code)
                        break
                    } // if
                } // for
            } // addOnSuccessListener
            .addOnFailureListener { e ->
                Log.e("BarcodeScanner", "Barcode scanning failed", e)
            } // addOnFailureListener
            .addOnCompleteListener {
                imageProxy.close()
            } // addOnCompleteListener
    } else {
        imageProxy.close()
    } // if (mediaImage != null)
} // fun processImageProxy
