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
    // AGP 8.7.3 (legacy-DSL default) so the llama_flutter_android plugin's
    // legacy android{} block is not a hard error. KGP 2.1.0 matches the version
    // that llama_flutter_android pins, killing the two-KGP classpath conflict.
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

// llama_flutter_android applies its own Kotlin Gradle Plugin (KGP) 2.1.0 via a
// buildscript classpath, which conflicts with the app's built-in Kotlin 2.3.20
// and corrupts the :app:compileReleaseKotlin classpath (unresolved references,
// "overrides nothing" errors). The buildscript classpath alignment that forces a
// single KGP/AGP version lives in android/build.gradle.kts (allprojects {}),
// because allprojects/configurations are not available in a settings script.

include(":app")
