plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
} // plugins

android {
    namespace = "org.danleys.xpaddle"
    compileSdk = 35

    defaultConfig {
        minSdk = 24
    } // defaultConfig

    buildFeatures {
        compose = true
    } // buildFeatures

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    } // compileOptions
} // android

dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.google.material)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation("com.google.android.gms:play-services-nearby:19.3.0")
    debugImplementation(libs.androidx.compose.ui.tooling)
} // dependencies
