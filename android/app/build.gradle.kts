// Release signing is driven by android/key.properties (gitignored — never
// commit it). To produce a signed release:
//
//   1. Generate a keystore (once, keep it safe — losing it means losing the
//      ability to update the app on the Play Store):
//        keytool -genkeypair -v -keystore ~/vaanix-release-key.jks \
//            -keyalg RSA -keysize 2048 -validity 10000 -alias vaanix
//   2. Create android/key.properties (see android/key.properties.example):
//        storePassword=<keystore password>
//        keyPassword=<key password>
//        keyAlias=vaanix
//        storeFile=/absolute/path/to/vaanix-release-key.jks
//
// RELEASE BUILDS MUST NEVER FALL BACK TO THE DEBUG KEY. When key.properties
// is missing or incomplete, release tasks fail fast with a clear error (see
// the taskGraph guard at the bottom of this file) instead of silently
// producing a debug-signed artifact. Debug builds keep using the debug key
// and remain fully usable on developer machines.
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { stream -> keystoreProperties.load(stream) }
}

// True only when key.properties exists, every required entry is non-blank,
// and the keystore file it points at is actually present on disk. Used by
// the taskGraph guard below so release builds fail fast with a clear
// message instead of silently producing debug-signed artifacts.
val releaseSigningReady: Boolean =
    keystorePropertiesFile.exists() &&
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all { prop ->
        keystoreProperties.getProperty(prop)?.isNotBlank() == true
    } &&
    keystoreProperties.getProperty("storeFile")?.let { file(it).exists() } == true

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

    // Keep the Kotlin JVM target aligned with the Java compile target.
    // With JDK 21 toolchains the Kotlin plugin defaults to 21, which fails
    // the JVM-target consistency check against the Java 17 compileOptions
    // above ("Inconsistent JVM Target Compatibility").
    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.vaanix.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Explicitly pinned to Flutter's configured NDK. Without this, AGP
        // falls back to its own default (27.0.12077973) for the synthetic
        // externalNativeBuild the Flutter plugin registers, which then
        // fails with CXX1101 when that NDK is not installed.
        ndkVersion = "28.2.13676358"
    }

    signingConfigs {
        create("release") {
            // Only populated when key.properties is complete and the
            // keystore exists; otherwise release builds are blocked by the
            // taskGraph guard below instead of signing with the debug key.
            if (releaseSigningReady) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // ALWAYS the production signing config — never the debug key.
            // If credentials are missing, the taskGraph guard below fails
            // the build before any task runs, so a debug-signed release
            // artifact is impossible.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// Guard: release tasks must never run without valid production signing
// credentials. Debug builds do not match this check and keep working on
// developer machines without android/key.properties.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.path.endsWith("Release") } && !releaseSigningReady) {
        throw GradleException(
            "VaaniX RELEASE BUILD BLOCKED: production signing credentials are missing or incomplete.\n" +
            "Expected android/key.properties (gitignored) with non-blank storeFile, storePassword, keyAlias and keyPassword,\n" +
            "and an existing keystore file at the path given by storeFile.\n" +
            "See android/key.properties.example and the header of android/app/build.gradle.kts for setup instructions.\n" +
            "Release builds are never silently signed with the Android debug key."
        )
    }
}
