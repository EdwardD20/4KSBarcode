package org.danleys.barcode

import android.content.Context
import android.content.pm.ActivityInfo
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.danleys.barcode.transition.TransitionHost
import org.danleys.barcode.ui.theme.BarcodeTheme

class BarcodeMainActivity : ComponentActivity() {

    private val clientIdKey = stringPreferencesKey("client_id")
    private val languageKey = stringPreferencesKey("language")
    private val displayModeKey = stringPreferencesKey("display_mode")
    private val earlyEntryStatusKey = stringPreferencesKey("EarlyEntryStatus")
    private val earlyEntryIssueDateKey = stringPreferencesKey("earlyEntryIssueDate")

    override fun attachBaseContext(newBase: Context) {
        val dataStore = newBase.dataStore
        var savedLang = "en"
        runBlocking {
            savedLang = dataStore.data.first()[languageKey] ?: "en"
        }
        val context = LocaleManager.wrapContextWithLocale(newBase, savedLang)
        super.attachBaseContext(context)
    } // end attachBaseContext

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)

        val dataStore = applicationContext.dataStore

        setContent {
            BarcodeTheme {
                var showSplash by remember { mutableStateOf(true) }
                val scope = rememberCoroutineScope()

                val prefsState by dataStore.data.collectAsState(initial = null)

                val currentClientId = prefsState?.get(clientIdKey) ?: ""
                val currentDisplayMode = prefsState?.get(displayModeKey) ?: "barcode"
                val earlyEntryStatus = prefsState?.get(earlyEntryStatusKey)
                val earlyEntryIssueDate = prefsState?.get(earlyEntryIssueDateKey)

                var showSettings by remember { mutableStateOf(false) }
                var initialized by remember { mutableStateOf(false) }

                val configuration = LocalConfiguration.current
                LaunchedEffect(configuration.smallestScreenWidthDp) {
                    requestedOrientation = if (configuration.smallestScreenWidthDp < 600) {
                        ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                    } else {
                        ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    }
                }

                if (prefsState != null && !initialized) {
                    showSettings = currentClientId.isEmpty()
                    initialized = true
                } // if (prefsState != null && !initialized)

                fun saveSettings(newId: String, newDisplayMode: String) {
                    scope.launch {
                        try {
                            dataStore.edit {
                                it[clientIdKey] = newId
                                it[displayModeKey] = newDisplayMode
                            } // dataStore.edit
                            showSettings = false
                        } catch (e: Exception) {
                        } // try/catch
                    } // end scope.launch
                } // end saveSettings

                Surface(modifier = Modifier.fillMaxSize()) {
                    val transitionEffect = remember { SplashRevealStyle.random().createTransition() }
                    TransitionHost(
                        showSplash = showSplash,
                        onSplashTimeout = { showSplash = false },
                        transitionEffect = transitionEffect,
                        splashContent = { onTimeout ->
                            SplashScreen(onTimeout = onTimeout)
                        },
                        mainContent = {
                            val configuration = LocalConfiguration.current
                            val isTwoPaneMode = configuration.screenWidthDp >= 600

                            if (showSettings && !isTwoPaneMode) {
                                SettingsScreen(
                                    currentClientId = currentClientId,
                                    currentDisplayMode = currentDisplayMode,
                                    onSettingsSaved = { id, mode -> saveSettings(id, mode) }
                                ) // SettingsScreen
                            } else {
                                MainScreen(
                                    clientId = currentClientId,
                                    displayMode = currentDisplayMode,
                                    earlyEntryStatus = earlyEntryStatus,
                                    earlyEntryIssueDate = earlyEntryIssueDate,
                                    onSettingsClick = { showSettings = true },
                                    onSettingsSaved = { id, mode -> saveSettings(id, mode) }
                                ) // MainScreen
                            } // if/else showSettings
                        }
                    )
                } // Surface
            } // end BarcodeTheme
        } // end setContent
    } // end onCreate
} // end class MainActivity
