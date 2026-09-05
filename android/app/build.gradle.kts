// Release signing is driven by android/key.properties (gitignored — never
// commit it). To produce a signed release:
//
//   1. Generate a keystore (once, keep it safe — losing it means losing the
//      ability to update the app on the Play Store):
//        keytool -genkey -v -keystore ~/vaanix-release-key.jks \
//            -keyalg RSA -keysize 2048 -validity 10000 -alias vaanix
//   2. Create android/key.properties:
//        storePassword=<keystore password>
//        keyPassword=<key password>
//        keyAlias=vaanix
//        storeFile=/absolute/path/to/vaanix-release-key.jks
//
// Without key.properties the release build type falls back to the debug key
// so `flutter run --release` keeps working on developer machines. This
// fallback is intentional; CI and store builds must provide key.properties.
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vaanix.app"

    // Pinned SDK levels (Flutter 3.47 toolchain defaults at the time of
    // pinning). Kept explicit so toolchain upgrades cannot silently move the
    // app's platform contract; bump them deliberately together with
    // dependency requirements and test on the new level.
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vaanix.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signed with the real release key when key.properties exists,
            // debug key otherwise (see the comment at the top of this file).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
