package org.danleys.barcode

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore

// Singleton Preferences DataStore for app-wide settings
private const val SETTINGS_NAME = "settings"

// Extension property on Context to access the singleton DataStore
val Context.dataStore: DataStore<Preferences> by preferencesDataStore(
    name = SETTINGS_NAME
)