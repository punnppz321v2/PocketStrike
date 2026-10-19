pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

// llama_flutter_android applies its own Kotlin Gradle Plugin (KGP) 2.1.0 via a
// buildscript classpath, which conflicts with the app's built-in Kotlin 2.3.20
// and corrupts the :app:compileReleaseKotlin classpath (unresolved references,
// "overrides nothing" errors). The buildscript classpath alignment that forces a
// single KGP/AGP version lives in android/build.gradle.kts (allprojects {}),
// because allprojects/configurations are not available in a settings script.

include(":app")
