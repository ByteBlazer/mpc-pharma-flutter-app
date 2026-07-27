import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun Project.parseDartDefines(): Map<String, String> {
    val raw = findProperty("dart-defines")?.toString().orEmpty()
    if (raw.isEmpty()) {
        return emptyMap()
    }

    return raw.split(",")
        .filter { it.isNotEmpty() }
        .mapNotNull { encoded ->
            runCatching {
                val decoded = String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
                val separator = decoded.indexOf('=')
                if (separator <= 0) {
                    null
                } else {
                    decoded.substring(0, separator) to decoded.substring(separator + 1)
                }
            }.getOrNull()
        }
        .toMap()
}

fun Project.readGoogleMapApiKey(): String {
    val dartDefines = parseDartDefines()
    val appEnv = dartDefines["APP_ENV"]
        ?: findProperty("APP_ENV")?.toString()
        ?: "local"

    val envFile = rootProject.file("../env/$appEnv.env")
    if (envFile.exists()) {
        envFile.readLines()
            .map { it.trim() }
            .firstOrNull { it.startsWith("GOOGLE_MAP_API_KEY=") }
            ?.substringAfter("=")
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.let { return it }
    }

    val localProps = Properties()
    val localPropsFile = rootProject.file("local.properties")
    if (localPropsFile.exists()) {
        localPropsFile.inputStream().use { localProps.load(it) }
        localProps.getProperty("GOOGLE_MAP_API_KEY")
            ?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?.let { return it }
    }

    return ""
}

android {
    namespace = "com.mpc.pharma.mpc_pharma"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.mpc.pharma.mpc_pharma"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = readGoogleMapApiKey()
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            if (!keystorePath.isNullOrBlank()) {
                storeFile = file(keystorePath)
                storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (System.getenv("ANDROID_KEYSTORE_PATH").isNullOrBlank()) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}
