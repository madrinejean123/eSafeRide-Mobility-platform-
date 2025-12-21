plugins {
    id("com.android.application")
    id("kotlin-android")

    // ✅ Firebase Google Services plugin
    id("com.google.gms.google-services")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.esaferide"
    compileSdk = flutter.compileSdkVersion
    // Use the highest NDK required by plugins (backward compatible)
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Application ID
        applicationId = "com.example.esaferide"

    // Minimum and target SDKs. Some plugins (Firebase, geolocation, etc.)
    // require at least SDK 23 — set explicitly to satisfy those plugins.
    minSdk = 23
        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signing with the debug keys for local testing
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

