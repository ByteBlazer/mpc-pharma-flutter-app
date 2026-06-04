import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use { localProperties.load(it) }
}

// Android needs its own key (Maps SDK for Android + package/SHA-1 restriction).
// The web/index.html browser key often loads the widget but not map tiles on Android.
val googleMapsApiKey: String =
    localProperties.getProperty("GOOGLE_MAPS_API_KEY_ANDROID")
        ?: localProperties.getProperty("GOOGLE_MAPS_API_KEY")
        // Same as web/index.html when local.properties omits the key (dev only).
        ?: "AIzaSyB-M95qSZan9nDkd1kcg7HYhTjG8gwd2FE"

if (googleMapsApiKey.isEmpty()) {
    logger.warn(
        "GOOGLE_MAPS_API_KEY_ANDROID is not set in android/local.properties — " +
            "Maps SDK will not load tiles on Android (see README.md).",
    )
}

android {
    namespace = "com.mpc.pharma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mpc.pharma"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = googleMapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
