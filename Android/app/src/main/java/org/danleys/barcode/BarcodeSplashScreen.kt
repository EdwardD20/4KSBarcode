package org.danleys.barcode

import android.content.Intent
import android.util.Log
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.fromHtml
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.net.toUri
import kotlinx.coroutines.delay
import kotlin.time.Duration.Companion.milliseconds

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SplashScreen(
    onTimeout: () -> Unit
) {
    val infoStoreText = stringResource(id = R.string.splash_text)
    val infoStoreAddress = stringResource(id = R.string.splash_address)
    var timeLeft by remember {
        mutableIntStateOf(if (BuildConfig.DEBUG) 2 else 4)
    }

    LaunchedEffect(Unit) {
        while (timeLeft > 0) {
            delay(1000.milliseconds)
            timeLeft--
        } // while (timeLeft > 0)
        onTimeout()
    } // LaunchedEffect

    val configuration = LocalConfiguration.current
    val backgroundColor = Color.Red
    val context = LocalContext.current

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(backgroundColor)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Logo at the top
            Image(
                painter = painterResource(id = R.drawable.feelgooddealslogo),
                contentDescription = "Feel Good Deals Logo",
                modifier = Modifier
                    .width(375.dp)
                    .height(163.dp),
                contentScale = ContentScale.Fit
            ) // end Image

            val infoFontSize = (configuration.screenHeightDp * 0.04).sp

            Text(
                text = AnnotatedString.fromHtml(infoStoreText),
                fontSize = infoFontSize,
                lineHeight = infoFontSize * 1.2,
                textAlign = TextAlign.Left,
                color = Color.Black,
                fontStyle = FontStyle.Italic,
                softWrap = true,
                maxLines = Int.MAX_VALUE,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 17.dp)
            ) // end Text

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = AnnotatedString.fromHtml(infoStoreAddress),
                fontSize = (infoFontSize.value * 0.8).sp,
                lineHeight = infoFontSize * 1.1,
                fontFamily = FontFamily.Monospace,
                textAlign = TextAlign.Left,
                color = Color.Black,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 17.dp)
                    .clickable {
                        try {
                            val encodedAddress = java.net.URLEncoder.encode(infoStoreAddress, "UTF-8")
                            val mapIntent = Intent(
                                Intent.ACTION_VIEW,
                                "geo:0,0?q=$encodedAddress".toUri()
                            )
                            context.startActivity(mapIntent)
                        } catch (e: Exception) {
                            Log.e("SplashScreen", "Could not open maps", e)
                        } // try/catch
                    } // clickable
            ) // Text (infoStoreAddress)
        } // Column (Content)

        // Prominent, non-subtle animated countdown timer
        val infiniteTransition = rememberInfiniteTransition(label = "pulse")
        val scale by infiniteTransition.animateFloat(
            initialValue = 0.95f,
            targetValue = 1.15f,
            animationSpec = infiniteRepeatable(
                animation = tween(600),
                repeatMode = RepeatMode.Reverse
            ),
            label = "scale"
        )

        val timerFontSize = (configuration.screenHeightDp * 0.10).sp

        Text(
            text = timeLeft.toString(),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(24.dp)
                .graphicsLayer {
                    scaleX = scale
                    scaleY = scale
                },
            style = TextStyle(
                fontSize = timerFontSize,
                fontWeight = FontWeight.Black,
                fontFamily = FontFamily.SansSerif,
                color = Color.White,
                shadow = Shadow(
                    color = Color.Black.copy(alpha = 0.5f),
                    offset = Offset(4f, 4f),
                    blurRadius = 10f
                )
            )
        )
    } // Box
} // SplashScreen
