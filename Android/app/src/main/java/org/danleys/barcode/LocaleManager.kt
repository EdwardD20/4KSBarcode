package org.danleys.barcode

import android.content.Context
import android.content.res.Configuration
import android.util.Log
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.LocaleListCompat
import java.util.Locale

object LocaleManager {

    private var currentCode: String = ""

    fun setLocale(languageCode: String) {
        Log.d("LANGUAGE_DEBUG", "Applying locale: $languageCode")

        // 3-letter ISO 639-2/3 codes like 'hmn' and 'arz' are supported
        // by AppCompatDelegate.setApplicationLocales as long as the
        // resources are in b+ prefix folders (e.g., values-b+arz).
        val locales = LocaleListCompat.forLanguageTags(languageCode)
        AppCompatDelegate.setApplicationLocales(locales)

        val locale = Locale.forLanguageTag(languageCode)
        Locale.setDefault(locale)
        currentCode = languageCode
    } // fun setLocale

    fun wrapContextWithLocale(context: Context, languageCode: String): Context {
        val locale = Locale.forLanguageTag(languageCode)
        Locale.setDefault(locale)

        val config = Configuration(context.resources.configuration)
        config.setLocale(locale)

        return context.createConfigurationContext(config)
    } // fun wrapContextWithLocale

} // object LocaleManager