import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.FileInputStream
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
} // plugins

val keystorePropsFile =
    rootProject.file("keystore.properties")

val keystoreProps =
    Properties()

if (keystorePropsFile.exists()) {
    keystoreProps.load(
        FileInputStream(keystorePropsFile)
    )
} // if

android {

    namespace = "org.danleys.barcode"

    compileSdk = 37

    defaultConfig {
        applicationId = "org.danleys.fourksbarcode"
        minSdk = 24
        targetSdk = 37
        versionCode = 249
        versionName = "4.0.2"
    } // defaultConfig

    compileOptions {
        sourceCompatibility =
            JavaVersion.VERSION_17
        targetCompatibility =
            JavaVersion.VERSION_17
    } // compileOptions

    buildFeatures {
        compose = true
        buildConfig = true
    } // buildFeatures

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        } // compilerOptions
    } // kotlin

    signingConfigs {
        create("release") {
            if (keystorePropsFile.exists()) {
                storeFile = file(keystoreProps["storeFile"] as String)
                storePassword = keystoreProps["storePassword"] as String
                keyAlias = keystoreProps["keyAlias"] as String
                keyPassword = keystoreProps["keyPassword"] as String
            } // if
        } // create
    } // signingConfigs

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            ) // proguardFiles
            signingConfig = signingConfigs.getByName("release")
        } // release
        debug {
        } // debug
    } // buildTypes

    testOptions {
        unitTests.isReturnDefaultValues = true
        managedDevices {
            localDevices {
                create("galaxyFoldSim") {
                    device = "Pixel Fold"
                    apiLevel = 36
                    systemImageSource = "google"
                }
            }
        }
    }
} // android

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(
        platform(
            libs.androidx.compose.bom
        )
    )
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.extended)
    implementation(libs.androidx.camera.core)
    implementation(libs.androidx.camera.camera2)
    implementation(libs.androidx.camera.lifecycle)
    implementation(libs.androidx.camera.view)
    implementation(libs.google.mlkit.barcode)
    implementation(libs.google.accompanist.permissions)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.androidx.datastore.preferences)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.google.material)
    implementation(libs.journeyapps.zxing.embedded)
    implementation(libs.androidx.window)
    implementation("com.google.android.gms:play-services-nearby:19.3.0")
    implementation(project(":xpaddle"))
    implementation(project(":cheaterssolitaire"))
    debugImplementation(libs.androidx.compose.ui.tooling)
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
} // dependencies

tasks.register("bumpVersionCode") {
    description = "Bump Version Code"
    doLast {
        val gradleFile = file("build.gradle.kts")
        val text = gradleFile.readText()
        val regex = Regex(
            """versionCode\s*=\s*(\d+)"""
        )
        val match = regex.find(text)
            ?: error(
                "versionCode not found"
            )
        val current = match.groupValues[1].toInt()
        val next = current + 1
        val updated = text.replaceFirst(
            regex,
            "versionCode = $next"
        )
        gradleFile.writeText(updated)
        println("versionCode bumped from $current to $next")
    } // doLast
} // tasks.register

tasks.configureEach {
    if (name == "bundleRelease" || name == "assembleRelease") {
        dependsOn("bumpVersionCode")
    } // if
} // tasks.configureEach
