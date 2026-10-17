package org.danleys.barcode

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.fromHtml
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.core.content.ContextCompat
import androidx.core.graphics.createBitmap
import androidx.core.graphics.set
import androidx.core.net.toUri
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun SettingsScreen(
    currentClientId: String,
    currentDisplayMode: String,
    onSettingsSaved: (String, String) -> Unit,
    hideBottomBar: Boolean = false
) {
    val context = LocalContext.current
    val activity = context as? ComponentActivity
    val dataStore = context.dataStore
    val coroutineScope = rememberCoroutineScope()
    var showScanner by remember { mutableStateOf(false) }

    val displayModes = listOf(
        "barcode" to stringResource(id = R.string.display_mode_barcode),
        "qrcode" to stringResource(id = R.string.display_mode_qrcode)
    ) // end list

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (isGranted) {
            showScanner = true
        } else {
            // Handle permission denial
            Log.d("PERMISSION_DEBUG", "Camera permission denied")
        } // end if
    } // end permissionLauncher

    // Supported languages
    val languages = listOf(
        "en" to "English",
        "es" to "Español",
        "fr" to "Français",
        "ar" to "العربية",
        "arz" to "العربية (مصر)",
        "de" to "Deutsch",
        "pl" to "Polski",
        "uk" to "Українська",
        "zh" to "中文（简体）",
        "hi" to "हिन्दी",
        "tl" to "Tagalog",
        "vi" to "Tiếng Việt",
        "ko" to "한국어",
        "ru" to "Русский",
        "gu" to "ગુજરાતી",
        "km" to "ភាសាខ្មែر",
        "lo" to "ພາສາລາວ",
        "hmn" to "Lus Hmoob"
    ) // end list

    val languageKey = stringPreferencesKey("language")
    val systemLang = Locale.getDefault().language

    // --- Language dropdown state and logic ---
    var selectedLanguageCode by remember { mutableStateOf<String?>(null) }
    var selectedLanguageName by remember { mutableStateOf<String?>(null) }
    var initializedLanguage by remember { mutableStateOf(false) }
    // Only fetch from DataStore on first composition
    LaunchedEffect(Unit) {
        if (!initializedLanguage) {
            val code = dataStore.data.map { prefs -> prefs[languageKey] ?: "" }.first()
            val effectiveCode = when {
                languages.any { it.first == code } -> code
                languages.any { it.first == systemLang } -> systemLang
                else -> "en"
            } // end when
            selectedLanguageCode = effectiveCode
            selectedLanguageName = languages.first { it.first == effectiveCode }.second
            Log.d("LANGUAGE_DEBUG", "Loaded language from DataStore: $effectiveCode")
            initializedLanguage = true
        } // end if
    } // end LaunchedEffect

    // State for Client ID input - use rememberSaveable to survive rotation
    var clientId by rememberSaveable { mutableStateOf(currentClientId) }
    var selectedDisplayMode by rememberSaveable { mutableStateOf(currentDisplayMode) }
    var displayExpanded by remember { mutableStateOf(false) }

    // Dialog states
    var showInfoDialog1 by remember { mutableStateOf(false) }
    var showInfoDialog2 by remember { mutableStateOf(false) }
    var showInfoDialog3 by remember { mutableStateOf(false) }
    var shareTheApp by remember { mutableStateOf(false) }
    var earlyEntry by remember { mutableStateOf(false) }
    var showFlyer by remember { mutableStateOf(false) }

    // Language dropdown state
    var expanded by remember { mutableStateOf(false) }

    // Early Entry Flow State
    var requestStatusMessage by remember { mutableStateOf<String?>(null) }
    var earlyEntryErrorMessage by remember { mutableStateOf<String?>(null) }

    val earlyEntryStatusKey = stringPreferencesKey("EarlyEntryStatus")
    val earlyEntryIssueDateKey = stringPreferencesKey("earlyEntryIssueDate")

    suspend fun submitApprovalRequest(id: String): String = withContext(Dispatchers.IO) {
        val url = URL("https://edwardd20.homedns.org/api/request-approval")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
        } // end apply
        val body = JSONObject().apply { put("clientId", id) }.toString()
        conn.outputStream.use { it.write(body.toByteArray()) }
        if (conn.responseCode !in 200..299) throw Exception("Server error: ${conn.responseCode}")
        val response = conn.inputStream.bufferedReader().use { it.readText() }
        JSONObject(response).getString("requestId")
    } // end fun submitApprovalRequest

    suspend fun fetchRequestStatus(requestId: String): String = withContext(Dispatchers.IO) {
        val url = URL("https://edwardd20.homedns.org/api/request-status/$requestId")
        val response = url.readText()
        try {
            val obj = JSONObject(response)
            return@withContext "${obj.getString("status")} (${obj.getString("requestId")})"
        } catch (e: Exception) {
            try {
                val arr = JSONArray(response)
                if (arr.length() > 0) {
                    val obj = arr.getJSONObject(0)
                    return@withContext "${obj.getString("status")} (${obj.getString("requestId")})"
                } // end if
            } catch (e2: Exception) {
            } // end catch
        } // end catch
        response
    } // end fun fetchRequestStatus

    suspend fun pollStatusUntilComplete(requestId: String): String? {
        val terminalStatuses = setOf("Senior", "Medical", "Denied")
        val maxDuration = 180_000L
        val interval = 5_000L
        val start = System.currentTimeMillis()
        while (System.currentTimeMillis() - start < maxDuration) {
            try {
                val status = fetchRequestStatus(requestId)
                val plainStatus = if (status.contains("(")) {
                    status.substringBefore("(").trim()
                } else {
                    status.trim()
                } // end if
                if (terminalStatuses.contains(plainStatus)) return plainStatus
            } catch (e: Exception) {
            } // end catch
            delay(interval)
        } // end while
        return null
    } // end fun pollStatusUntilComplete

    fun runEarlyEntryFlow() {
        if (clientId.isBlank()) {
            if (BuildConfig.DEBUG) earlyEntryErrorMessage = "No client ID available"
            return
        } // end if
        coroutineScope.launch {
            try {
                val requestId = submitApprovalRequest(clientId)
                if (BuildConfig.DEBUG) requestStatusMessage = "Request submitted: $requestId"
                
                val finalStatus = pollStatusUntilComplete(requestId)
                if (finalStatus != null) {
                    if (BuildConfig.DEBUG) requestStatusMessage = "Completed with status: $finalStatus"
                    val now = Date()
                    val isoDate = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).format(now)
                    
                    dataStore.edit { it[earlyEntryIssueDateKey] = isoDate }
                    
                    if (finalStatus == "Senior" || finalStatus == "Medical") {
                        dataStore.edit { it[earlyEntryStatusKey] = finalStatus }
                        if (finalStatus == "Medical" && BuildConfig.DEBUG) {
                            requestStatusMessage += " ($isoDate)"
                        } // end if
                    } // end if
                } else if (BuildConfig.DEBUG) {
                    requestStatusMessage = "Timed out waiting for status."
                } // end if
            } catch (e: Exception) {
                if (BuildConfig.DEBUG) earlyEntryErrorMessage = e.localizedMessage
            } // end catch
        } // end launch
    } // end fun runEarlyEntryFlow

    val content: @Composable () -> Unit = {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Red)
                .verticalScroll(rememberScrollState())
                .padding(24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) { // Column (Main Content)

            // Logo and version
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Image(
                    painter = painterResource(id = R.drawable.logo),
                    contentDescription = "Logo",
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(100.dp)
                ) // end Image
            val versionName = try {
                val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                pInfo.versionName ?: "1.0"
            } catch (_: Exception) {
                "1.0"
            } // end try
                Text(
                    text = stringResource(id = R.string.version_label) + ": $versionName",
                    fontSize = 10.sp,
                    color = Color.Black,
                    modifier = Modifier.padding(top = 4.dp),
                    textAlign = TextAlign.Center
                ) // end Text
            } // Column (Logo and version)

            // Client ID input
            OutlinedTextField(
                value = clientId,
                onValueChange = { input -> 
                    // If user pastes "Client ID: 123456", this filters to "123456"
                    clientId = input.filter { it.isDigit() } 
                },
                label = { Text(stringResource(id = R.string.client_id_placeholder), color = Color.Black) },
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Done
                ),
                placeholder = { Text("e.g. 123456", color = Color.Black.copy(alpha = 0.5f)) },
                trailingIcon = {
                    IconButton(
                        onClick = {
                            val permissionCheckResult = ContextCompat.checkSelfPermission(
                                context,
                                Manifest.permission.CAMERA
                            )
                            if (permissionCheckResult == PackageManager.PERMISSION_GRANTED) {
                                showScanner = true
                            } else {
                                permissionLauncher.launch(Manifest.permission.CAMERA)
                            } // end if
                        },
                        modifier = Modifier.semantics {
                            contentDescription = "Scan barcode to enter Client ID"
                        }
                    ) {
                        Icon(
                            imageVector = Icons.Default.QrCodeScanner,
                            contentDescription = null,
                            tint = Color.Black
                        ) // Icon
                    } // IconButton (Scan barcode)
                }, // end trailingIcon
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics {
                        contentDescription = "Enter numeric Client ID"
                    },
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = Color.Black,
                    unfocusedTextColor = Color.Black,
                    focusedContainerColor = Color.White.copy(alpha = 0.5f),
                    unfocusedContainerColor = Color.White.copy(alpha = 0.3f),
                    focusedBorderColor = Color.Black,
                    unfocusedBorderColor = Color.Black.copy(alpha = 0.5f),
                    focusedLabelColor = Color.Black,
                    unfocusedLabelColor = Color.Black.copy(alpha = 0.7f)
                ) // end colors
            ) // OutlinedTextField (Client ID input)

            PrimaryRaisedWideButton(
                text = stringResource(id = R.string.save_client_and_close),
                onClick = { onSettingsSaved(clientId, selectedDisplayMode) }
            ) // PrimaryRaisedWideButton (Save button)

            FilledWideButton(
                text = if (shareTheApp) stringResource(id = R.string.close_button)
                else AnnotatedString.fromHtml(stringResource(id = R.string.client_enrollment)),
                onClick = {
                    val intent = Intent(
                        Intent.ACTION_VIEW,
                        "https://nifb.link2feed.com/create-account".toUri()
                    )
                    context.startActivity(intent)
                } // end onClick
            ) // FilledWideButton (Client Enrollment)

            FilledWideButton(
                text = stringResource(id = R.string.website_label),
                onClick = {
                    val intent = Intent(
                        Intent.ACTION_VIEW,
                        "https://4-kidssake.org".toUri()
                    )
                    context.startActivity(intent)
                } // end onClick
            ) // FilledWideButton (Website)

            FilledWideButton(
                text = stringResource(id = R.string.info_button_label),
                onClick = { showInfoDialog1 = true }
            ) // FilledWideButton (Info Dialog 1)

            FilledWideButton(
                text = stringResource(id = R.string.info_button_label2),
                onClick = { showInfoDialog2 = true }
            ) // FilledWideButton (Info Dialog 2)

            FilledWideButton(
                text = if (shareTheApp) stringResource(id = R.string.close_button)
                else stringResource(id = R.string.shareTheApp),
                onClick = { shareTheApp = !shareTheApp }
            ) // FilledWideButton (Share the App)

            FilledWideButton(
                text = if (earlyEntry) stringResource(id = R.string.close_button)
                else stringResource(id = R.string.early_entry_label),
                onClick = { earlyEntry = !earlyEntry }
            ) // FilledWideButton (Early Entry)

            // Condensed Display Mode Selector
            CondensedDropdown(
                label = stringResource(id = R.string.display_mode_label),
                currentValue = displayModes.firstOrNull { it.first == selectedDisplayMode }?.second ?: "",
                onRowClick = { displayExpanded = true }
            ) {
                DropdownMenu(
                    expanded = displayExpanded,
                    onDismissRequest = { displayExpanded = false }
                ) {
                    displayModes.forEach { (mode, label) ->
                        DropdownMenuItem(
                            text = { Text(label, color = Color.Black) },
                            onClick = {
                                selectedDisplayMode = mode
                                displayExpanded = false
                            } // onClick
                        ) // DropdownMenuItem
                    } // end forEach
                } // end DropdownMenu
            } // CondensedDropdown (Display Mode)

            // Condensed Language Selector
            CondensedDropdown(
                label = stringResource(id = R.string.language_label),
                currentValue = selectedLanguageName ?: "",
                onRowClick = { expanded = true }
            ) {
                DropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    languages.forEach { (code, name) ->
                        DropdownMenuItem(
                            text = { Text(name, color = Color.Black) },
                            onClick = {
                                expanded = false
                                if (selectedLanguageCode != code) {
                                    selectedLanguageCode = code
                                    selectedLanguageName = name
                                    coroutineScope.launch {
                                        dataStore.edit { prefs ->
                                            prefs[languageKey] = code
                                        } // end edit
                                        if (activity != null) {
                                            LocaleManager.setLocale(code)
                                            activity.recreate()
                                        } // end if
                                    } // end launch
                                } // end if
                            } // end onClick
                        ) // DropdownMenuItem
                    } // end forEach
                } // end DropdownMenu
            } // CondensedDropdown (Language)

            if (BuildConfig.DEBUG) {
                Spacer(modifier = Modifier.height(16.dp))
                Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                    Text("--- DEBUG DATASTORE ---", style = MaterialTheme.typography.labelSmall, color = Color.Black.copy(alpha = 0.6f))
                    val prefs by dataStore.data.collectAsState(initial = null)
                    Text("Stored ID: '${prefs?.get(stringPreferencesKey("client_id")) ?: "null"}'", style = MaterialTheme.typography.labelSmall, color = Color.Black.copy(alpha = 0.6f))
                    Text("Stored EE: ${prefs?.get(stringPreferencesKey("EarlyEntryStatus")) ?: "null"}", style = MaterialTheme.typography.labelSmall, color = Color.Black.copy(alpha = 0.6f))
                } // end Column
            } // end if

        } // Column (Main Content)
    } // end val content

    if (hideBottomBar) {
        content()
    } else {
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
                ) // end startActivity
            }, // end onDealsTap
            content = content
        ) // end BottomBarLayout
    } // end else

    // Dialogs
    if (showFlyer) {
        GraphicDialog(
            onClose = { showFlyer = false },
            title = R.string.pantry_hours,
            graphic = R.drawable.foodpantryflyer
        ) // GraphicDialog (Pantry Flyer)
    } // end if

    if (shareTheApp) {
        Dialog(onDismissRequest = { shareTheApp = false }) {
            ShareAppSheet(
                appStoreLogo = R.drawable.appstorelogo,
                googlePlayLogo = R.drawable.googleplaystorelogo,
                onClose = { shareTheApp = false }
            ) // end ShareAppSheet
        } // end Dialog
    } // end if

    if (earlyEntry) {
        Dialog(onDismissRequest = { earlyEntry = false }) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.9f),
                shape = MaterialTheme.shapes.medium,
                color = Color.Red,
                tonalElevation = 8.dp
            ) {
                Column(modifier = Modifier.fillMaxSize()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = stringResource(id = R.string.early_entry_label),
                            style = MaterialTheme.typography.titleLarge,
                            color = Color.Black
                        )
                        TextButton(onClick = { earlyEntry = false }) {
                            Text(stringResource(id = R.string.close_button), color = Color.Black)
                        } // end TextButton
                    } // end Row
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 16.dp)
                            .verticalScroll(rememberScrollState())
                    ) {
                        Text(
                            text = AnnotatedString.fromHtml(stringResource(id = R.string.early_entry_text)),
                            color = Color.Black
                        )
                        Spacer(modifier = Modifier.height(24.dp))
                        
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Button(
                                onClick = { runEarlyEntryFlow() },
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = androidx.compose.ui.graphics.Color(0xFFFFF59D) // Lighter yellow
                                ),
                                modifier = Modifier.weight(1f)
                            ) {
                                Text(".", color = Color.Black)
                            } // end Button
                            
                            if (BuildConfig.DEBUG) {
                                Button(
                                    onClick = { 
                                        coroutineScope.launch {
                                            dataStore.edit { prefs ->
                                                prefs.remove(earlyEntryStatusKey)
                                                prefs.remove(earlyEntryIssueDateKey)
                                            } // end edit
                                            requestStatusMessage = "Cleared"
                                        } // end launch
                                    },
                                    modifier = Modifier.weight(1f),
                                    colors = ButtonDefaults.buttonColors(
                                        containerColor = Color.Black,
                                        contentColor = Color.White
                                    )
                                ) {
                                    Text("Erase")
                                } // end Button
                            } // end if
                        } // end Row
                        
                        if (BuildConfig.DEBUG) {
                            requestStatusMessage?.let {
                                Text(
                                    text = it,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color.Black,
                                    modifier = Modifier.padding(top = 8.dp)
                                )
                            } // end let
                            earlyEntryErrorMessage?.let {
                                Text(
                                    text = it,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = Color.Black,
                                    modifier = Modifier.padding(top = 8.dp)
                                )
                            } // end let
                        } // end if
                        Spacer(modifier = Modifier.height(24.dp))
                    } // end Column
                } // end Column
            } // end Surface
        } // end Dialog
    } // end if earlyEntry

    if (showScanner) {
        BarcodeScannerScreen(
            onCodeScanned = { raw ->
                clientId = raw.filter { it.isDigit() }
                showScanner = false
            }, // end onCodeScanned
            onDismiss = { showScanner = false }
        ) // end BarcodeScannerScreen
    } // end if

    if (showInfoDialog1 || showInfoDialog2 || showInfoDialog3) {
        Dialog(onDismissRequest = {
            showInfoDialog1 = false
            showInfoDialog2 = false
            showInfoDialog3 = false
        }) {
            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .fillMaxHeight(0.9f),
                shape = MaterialTheme.shapes.medium,
                color = Color.Red,
                tonalElevation = 8.dp
            ) {
                Column(modifier = Modifier.fillMaxSize()) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        when {
                            showInfoDialog1 -> Text(
                                text = stringResource(id = R.string.info_button_label),
                                style = MaterialTheme.typography.titleLarge,
                                color = Color.Black
                            )

                            showInfoDialog2 -> Text(
                                text = stringResource(id = R.string.info_button_label2),
                                style = MaterialTheme.typography.titleLarge,
                                color = Color.Black
                            )

                            showInfoDialog3 -> Text(
                                text = stringResource(id = R.string.senior_day),
                                style = MaterialTheme.typography.titleLarge,
                                color = Color.Black
                            )
                        } // end when
                        TextButton(onClick = {
                            showInfoDialog1 = false
                            showInfoDialog2 = false
                            showInfoDialog3 = false
                        }) {
                            Text(stringResource(id = R.string.close_button), color = Color.Black)
                        }
                    } // Row (Dialog Title)
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 16.dp)
                            .verticalScroll(rememberScrollState())
                    ) {
                        when {
                            showInfoDialog1 -> Text(text = AnnotatedString.fromHtml(stringResource(id = R.string.info_text)), color = Color.Black)
                            showInfoDialog2 -> Text(text = AnnotatedString.fromHtml(stringResource(id = R.string.info_text2)), color = Color.Black)
                            showInfoDialog3 -> Text(text = stringResource(id = R.string.senior_day_notice), color = Color.Black)
                        } // end when
                        Spacer(modifier = Modifier.height(24.dp))
                    } // Column (Dialog Content)
                } // Column (Dialog Surface)
            } // Surface (Dialog Surface)
        } // Dialog (Info Dialogs)
    } // end if
} // SettingsScreen

@Composable
fun ShareAppSheet(
    appStoreLogo: Int,
    googlePlayLogo: Int,
    onClose: () -> Unit
) {
    val screenWidth = LocalConfiguration.current.screenWidthDp.dp

    val googleUrl = "https://play.google.com/store/apps/details?id=org.danleys.fourksbarcode"
    val appleUrl = "https://apps.apple.com/app/4-k-i-d-s-sake-food-pantry/id6753714955"

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .fillMaxHeight(0.9f),
        shape = MaterialTheme.shapes.medium,
        color = Color.Red,
        tonalElevation = 8.dp
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) { // Column (ShareAppSheet)

                // Top title row with close button
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(
                        text = stringResource(id = R.string.shareTheApp),
                        style = MaterialTheme.typography.titleLarge,
                        color = Color.Black
                    )
                    TextButton(onClick = { onClose() }) {
                        Text(stringResource(id = R.string.close_button), color = Color.Black)
                    } // end TextButton
                } // Row (Title & Close)

                // Google Play QR
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(
                        painter = painterResource(id = googlePlayLogo),
                        contentDescription = "Google Play Store",
                        modifier = Modifier.width(screenWidth * 0.5f)
                    ) // end Image
                    val googleBitmap: Bitmap? =
                        remember(googleUrl) { generateQRCodeBitmap(googleUrl) }
                    if (googleBitmap != null) {
                        Image(
                            bitmap = googleBitmap.asImageBitmap(),
                            contentDescription = "Google Play QR",
                            modifier = Modifier
                                .width(screenWidth * 0.75f)
                                .aspectRatio(1f)
                        ) // end Image
                    } // end if
                } // Column (Google Play)

                Spacer(modifier = Modifier.height(16.dp))

                // Apple App Store QR
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Image(
                        painter = painterResource(id = appStoreLogo),
                        contentDescription = "Apple App Store",
                        modifier = Modifier.width(screenWidth * 0.5f)
                    ) // end Image
                    val appleBitmap: Bitmap? = remember(appleUrl) { generateQRCodeBitmap(appleUrl) }
                    if (appleBitmap != null) {
                        Image(
                            bitmap = appleBitmap.asImageBitmap(),
                            contentDescription = "Apple App Store QR",
                            modifier = Modifier
                                .width(screenWidth * 0.75f)
                                .aspectRatio(1f)
                        ) // end Image
                    } // end if
                } // Column (Apple App Store)
            } // Column (ShareAppSheet)
        } // Box (ShareAppSheet Scrollable)
    } // Surface (ShareAppSheet)
} // ShareAppSheet

@Suppress("DEPRECATION") // Bitmap.createBitmap/set is fine here for QR code generation
fun generateQRCodeBitmap(content: String): Bitmap? {
    return try {
        val size = 512 // size in pixels
        val bits = MultiFormatWriter().encode(
            content,
            BarcodeFormat.QR_CODE,
            size,
            size
        ) // end encode
        val bmp = createBitmap(size, size, Bitmap.Config.RGB_565)
        for (x in 0 until size) {
            for (y in 0 until size) {
                bmp[x, y] = if (bits[x, y]) android.graphics.Color.BLACK else android.graphics.Color.WHITE
            } // end for
        } // end for
        bmp
    } catch (_: Exception) {
        null
    } // end try
} // generateQRCodeBitmap

@Composable
private fun CondensedDropdown(
    label: String,
    currentValue: String,
    onRowClick: () -> Unit,
    content: @Composable () -> Unit
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onRowClick() },
        color = Color.Transparent,
        shape = MaterialTheme.shapes.small
    ) {
        Row(
            modifier = Modifier
                .padding(vertical = 8.dp, horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge,
                color = Color.Black
            )
            Box {
                Text(
                    text = currentValue,
                    style = MaterialTheme.typography.bodyLarge,
                    color = Color.Black,
                    fontWeight = FontWeight.Medium
                )
                content()
            } // end Box
        } // end Row
    } // end Surface
} // end CondensedDropdown

@Composable
private fun PrimaryRaisedWideButton(
    text: String,
    onClick: () -> Unit
) {
    ElevatedButton(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.elevatedButtonColors(
            containerColor = Color.Black,
            contentColor = Color.White
        ),
        elevation = ButtonDefaults.elevatedButtonElevation(
            defaultElevation = 6.dp,
            pressedElevation = 8.dp,
            focusedElevation = 6.dp,
            hoveredElevation = 8.dp,
            disabledElevation = 0.dp
        ),
        contentPadding = PaddingValues(vertical = 12.dp)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            maxLines = 2,
            softWrap = true
        ) // end Text
    } // ElevatedButton (PrimaryRaisedWideButton)
} // PrimaryRaisedWideButton

@Composable
private fun FilledWideButton(
    text: Any,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.White.copy(alpha = 0.8f),
            contentColor = Color.Black
        ),
        contentPadding = PaddingValues(vertical = 10.dp)
    ) {
        val annotatedText = when(text) {
            is AnnotatedString -> text
            is String -> AnnotatedString(text)
            else -> AnnotatedString(text.toString())
        } // end when
        Text(
            text = annotatedText,
            style = MaterialTheme.typography.labelLarge,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
            maxLines = 2,
            softWrap = true
        ) // end Text
    } // Button (FilledWideButton)
} // FilledWideButton
