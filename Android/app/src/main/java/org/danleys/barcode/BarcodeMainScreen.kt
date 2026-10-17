package org.danleys.barcode

import android.content.Intent
import android.content.res.Configuration
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.fromHtml
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.net.toUri
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.danleys.barcode.games.GamesHubScreen
import org.danleys.solitaire.CheatersSolitaireApp
import org.danleys.xpaddle.XPaddleApp
import org.json.JSONObject
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

enum class ActiveGameScreen {
    NONE,
    GAMES_HUB,
    CHEATERS_SOLITAIRE,
    EXTREME_PADDLE
} // end enum ActiveGameScreen

@Composable
fun GoogleWalletButton(clientId: String, barcodeFormat: String) { // fun GoogleWalletButton
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbarHostState = remember { SnackbarHostState() }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { // clickable
                scope.launch { // scope.launch
                    try { // try
                        val saveUrl = withContext(Dispatchers.IO) { // withContext IO
                            val url = URL("https://edwardd20.homedns.org/google/index.php?clientID=$clientId&pass=4kidssake-pass&env=prod&barcode=$barcodeFormat")
                            val response = url.readText()
                            val json = JSONObject(response)
                            if (json.has("error")) throw Exception(json.getString("error"))
                            json.getString("url")
                        } // withContext IO

                        val intent = Intent(Intent.ACTION_VIEW, saveUrl.toUri())
                        context.startActivity(intent)

                    } catch (e: Exception) { // catch
                        e.printStackTrace()
                        snackbarHostState.showSnackbar("Error opening Google Wallet") // show Snackbar
                    } // try/catch
                } // scope.launch
            }, // clickable
        contentAlignment = Alignment.Center
    ) { // Box
        Image(
            painter = painterResource(id = R.drawable.googlewallet_vector), // vector asset
            contentDescription = "Add to Google Wallet",
            contentScale = ContentScale.Fit,
            modifier = Modifier
                .height(64.dp)
                .wrapContentWidth()
                .semantics {
                    role = Role.Button
                    contentDescription = "Add to Google Wallet"
                } // semantics
        ) // Image

        // SnackbarHost to show messages
        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.align(Alignment.BottomCenter)
        ) // SnackbarHost
    } // Box
} // fun GoogleWalletButton

@Composable
fun MainScreen(
    clientId: String,
    displayMode: String,
    earlyEntryStatus: String?,
    earlyEntryIssueDate: String?,
    onSettingsClick: () -> Unit,
    onSettingsSaved: (String, String) -> Unit
) {
    var showFlyer by remember { mutableStateOf(false) } // state for showing flyer
    var showEarlyEntryCard by remember { mutableStateOf(false) }
    var activeGameScreen by remember { mutableStateOf(ActiveGameScreen.NONE) }

    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    val isLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
    val isTwoPaneMode = configuration.screenWidthDp >= 600

    when (activeGameScreen) {
        ActiveGameScreen.GAMES_HUB -> {
            GamesHubScreen(
                onReturnToApp = { activeGameScreen = ActiveGameScreen.NONE },
                onSelectSolitaire = { activeGameScreen = ActiveGameScreen.CHEATERS_SOLITAIRE },
                onSelectXPaddle = { activeGameScreen = ActiveGameScreen.EXTREME_PADDLE }
            ) // end GamesHubScreen
        } // end ActiveGameScreen.GAMES_HUB
        ActiveGameScreen.CHEATERS_SOLITAIRE -> {
            CheatersSolitaireApp(
                onExitToHost = { activeGameScreen = ActiveGameScreen.NONE }
            ) // end CheatersSolitaireApp
        } // end ActiveGameScreen.CHEATERS_SOLITAIRE
        ActiveGameScreen.EXTREME_PADDLE -> {
            XPaddleApp(
                onExitToHost = { activeGameScreen = ActiveGameScreen.NONE }
            ) // end XPaddleApp
        } // end ActiveGameScreen.EXTREME_PADDLE
        ActiveGameScreen.NONE -> {
            BottomBarLayout(
                modifier = Modifier.background(Color.Red),
                pantryLabel = stringResource(id = R.string.pantry_hours),
                dealsLabel = stringResource(id = R.string.feel_good_deals),
                onPantryTap = { showFlyer = true },
                onDealsTap = {
                    context.startActivity(
                        Intent(
                            Intent.ACTION_VIEW,
                            "https://www.facebook.com/FeelGoodDeals4KidsSake".toUri()
                        )
                    ) // startActivity
                } // onDealsTap
            ) {
                if (isTwoPaneMode) {
                    Row(modifier = Modifier.fillMaxSize()) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Top,
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight()
                                .background(Color.Red)
                                .verticalScroll(rememberScrollState())
                                .padding(16.dp)
                        ) {
                            MainContent(
                                clientId = clientId,
                                displayMode = displayMode,
                                earlyEntryStatus = earlyEntryStatus,
                                earlyEntryIssueDate = earlyEntryIssueDate,
                                isLandscape = isLandscape,
                                isTwoPaneMode = isTwoPaneMode,
                                onSettingsClick = onSettingsClick,
                                onGamesClick = { activeGameScreen = ActiveGameScreen.GAMES_HUB },
                                showEarlyEntryCard = { showEarlyEntryCard = true }
                            )
                        } // end Column

                        Surface(
                            modifier = Modifier
                                .weight(1f)
                                .fillMaxHeight(),
                            color = Color.Red
                        ) {
                            SettingsScreen(
                                currentClientId = clientId,
                                currentDisplayMode = displayMode,
                                onSettingsSaved = onSettingsSaved,
                                hideBottomBar = true
                            )
                        } // end Surface
                    } // end Row
                } else {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Top,
                        modifier = Modifier
                            .fillMaxSize()
                            .background(Color.Red)
                            .verticalScroll(rememberScrollState())
                            .padding(16.dp)
                    ) {
                        MainContent(
                            clientId = clientId,
                            displayMode = displayMode,
                            earlyEntryStatus = earlyEntryStatus,
                            earlyEntryIssueDate = earlyEntryIssueDate,
                            isLandscape = isLandscape,
                            isTwoPaneMode = isTwoPaneMode,
                            onSettingsClick = onSettingsClick,
                            onGamesClick = { activeGameScreen = ActiveGameScreen.GAMES_HUB },
                            showEarlyEntryCard = { showEarlyEntryCard = true }
                        )
                        Spacer(modifier = Modifier.height(32.dp))
                    } // end Column
                } // end else
            } // BottomBarLayout content
        } // end ActiveGameScreen.NONE
    } // end when (activeGameScreen)

    if (showFlyer) {
        GraphicDialog(
            onClose = { showFlyer = false },
            title = R.string.pantry_hours,
            graphic = R.drawable.foodpantryflyer
        ) // GraphicDialog
    } // if showFlyer

    if (showEarlyEntryCard) {
        val calendar = Calendar.getInstance()
        val currentYear = calendar.get(Calendar.YEAR)

        val cardBackgroundColor = Color.Red
        val contentTextColor = Color.Black

        val expirationDate = "December 31, $currentYear"
        
        val formattedIssueDate = try {
            val parser = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US)
            val formatter = SimpleDateFormat("MMMM d, yyyy", Locale.getDefault())
            val date = parser.parse(earlyEntryIssueDate ?: "")
            date?.let { formatter.format(it) } ?: earlyEntryIssueDate
        } catch (_: Exception) {
            earlyEntryIssueDate
        } // end try

        val rawTemplate = stringResource(id = R.string.early_entry_card)
        val formattedContent = rawTemplate
            .replace("?????", earlyEntryStatus ?: "")
            .replace("~~~~~", expirationDate)
            .replace("_____", clientId)
            .replace("-----", formattedIssueDate ?: "")

        Dialog(
            onDismissRequest = { showEarlyEntryCard = false }
        ) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.9f),
                shape = MaterialTheme.shapes.medium,
                color = cardBackgroundColor,
                tonalElevation = 8.dp
            ) {
                Column(
                    modifier = Modifier
                        .padding(16.dp)
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = stringResource(id = R.string.early_entry_label),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = contentTextColor,
                        modifier = Modifier.padding(bottom = 16.dp)
                    )
                    
                    Text(
                        text = AnnotatedString.fromHtml(formattedContent),
                        style = MaterialTheme.typography.bodyMedium,
                        textAlign = TextAlign.Start,
                        color = contentTextColor
                    )
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    TextButton(onClick = { showEarlyEntryCard = false }) {
                        Text(
                            text = stringResource(id = R.string.close_button),
                            color = Color.Black
                        )
                    } // end TextButton
                } // end Column
            } // end Surface
        } // end Dialog
    } // end if
} // fun MainScreen

@Composable
private fun MainContent(
    clientId: String,
    displayMode: String,
    earlyEntryStatus: String?,
    earlyEntryIssueDate: String?,
    isLandscape: Boolean,
    isTwoPaneMode: Boolean,
    onSettingsClick: () -> Unit,
    onGamesClick: () -> Unit,
    showEarlyEntryCard: () -> Unit
) {
    val context = LocalContext.current
    val noRipple = remember { MutableInteractionSource() }
    val siteUrl = "https://4-kidssake.org"

    // --- Logo ---
    val logoModifier = if (isLandscape || isTwoPaneMode) {
        Modifier
    } else {
        Modifier
            .fillMaxWidth()
            .height(200.dp)
    } // if

    Image(
        painter = painterResource(id = R.drawable.logo),
        contentDescription = "Open 4 K.I.D.S. Sake website",
        modifier = logoModifier
            .semantics {
                role = Role.Button
                contentDescription = "Open 4 K.I.D.S. Sake website"
            } // semantics
            .clickable(
                interactionSource = noRipple,
                indication = null,
                role = Role.Button,
                onClickLabel = "Open website"
            ) {
                context.startActivity(
                    Intent(Intent.ACTION_VIEW, siteUrl.toUri())
                ) // startActivity
            } // clickable
    ) // Image logo

    Spacer(modifier = Modifier.height(16.dp))

    // --- Title ---
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = stringResource(id = R.string.app_title),
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
            softWrap = true,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            color = Color.Black,
            modifier = Modifier.fillMaxWidth()
        ) // Text (app_title)
    } // Box (title container)

    // --- Barcode and Google Wallet ---
    if (clientId.isNotEmpty()) {
        BarcodeGenerator(data = clientId, mode = displayMode) // BarcodeGenerator

        Text(
            text = clientId,
            fontWeight = FontWeight.Bold,
            fontSize = 22.sp,
            color = Color.Black
        ) // Text (clientId)

        Spacer(modifier = Modifier.height(12.dp))

        // --- Google Wallet button ---
        GoogleWalletButton(clientId = clientId, barcodeFormat = "code128")

        // --- Early Entry Button ---
        if (!earlyEntryStatus.isNullOrEmpty() && !earlyEntryIssueDate.isNullOrEmpty()) {
            Spacer(modifier = Modifier.height(12.dp))
            MediumWidthButton(
                text = stringResource(id = R.string.early_entry_label),
                onClick = { showEarlyEntryCard() }
            )
        } // if hasEE

    } else {
        Text(
            text = stringResource(id = R.string.no_client),
            fontWeight = FontWeight.Normal,
            fontSize = 18.sp,
            color = Color.Black,
            modifier = Modifier.padding(vertical = 32.dp)
        ) // Text no_client
    } // if/else clientId

    Spacer(modifier = Modifier.height(12.dp))

    // --- Games button ---
    MediumWidthButton(
        text = "Get sidetracked...",
        onClick = { onGamesClick() }
    ) // MediumWidthButton Games

    Spacer(modifier = Modifier.height(12.dp))

    // --- Settings button ---
    MediumWidthButton(
        text = stringResource(id = R.string.settings_button),
        onClick = { onSettingsClick() },
        enabled = !isTwoPaneMode
    ) // MediumWidthButton Settings
}
