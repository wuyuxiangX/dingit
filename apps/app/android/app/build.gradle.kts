import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing config from android/key.properties if the file
// exists. Kept outside the android {} block so we can branch on its
// presence inside buildTypes without re-reading it twice.
//
// The file is gitignored (see android/.gitignore) and must never land
// in source control. A sibling key.properties.template documents the
// expected keys — duplicate, rename, and fill it in to produce a real
// Play-Store-ready APK.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}

android {
    namespace = "me.dingit.app"
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
        // Matches the iOS bundle identifier — both platforms now use
        // me.dingit.app as the canonical app identity. Renaming this
        // invalidates every Android device token already registered
        // against the old id, because FCM registration tokens are
        // scoped to the application package name. For solo / self-host
        // deploys this is a one-time reset; if Dingit ever ships a
        // hosted backend serving multiple tenants, coordinate with the
        // server team before flipping it again.
        applicationId = "me.dingit.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only declare the release config when key.properties is
        // actually present. Declaring it with null fields would make
        // `flutter build apk --release` fail with a cryptic
        // "Keystore file null not set" error; failing closed here
        // (by keeping release signing undefined) lets the buildTypes
        // block below fall through to the debug key cleanly.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String).let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Fall back to debug signing when key.properties is absent
            // so `flutter run --release` and CI smoke builds still
            // work on a fresh clone. A loud stderr line makes sure
            // nobody accidentally ships a debug-signed APK to the
            // Play Store without noticing.
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
                System.err.println(
                    "⚠️  android/key.properties not found — release build " +
                        "will be signed with the debug keystore. See " +
                        "android/key.properties.template to configure real " +
                        "release signing."
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
