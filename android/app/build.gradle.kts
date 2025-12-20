import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.time_capsule"
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
        applicationId = "com.example.time_capsule"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

      // ---- Signing: read from key.properties (Kotlin DSL) ----
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties") // 注意：在 android/key.properties
    val hasReleaseKeystore = keystorePropertiesFile.exists()

    if (hasReleaseKeystore) {
        FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
    }

    signingConfigs {
        // Flutter/AGP 默认已有 debug，这里只定义 release
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storePassword = keystoreProperties["storePassword"] as String

                val storeFilePath = keystoreProperties["storeFile"] as String
                storeFile = file(storeFilePath)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
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
