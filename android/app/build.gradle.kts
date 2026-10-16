plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // Diperlukan oleh widget Jetpack Glance (Fitur 4).
    id("org.jetbrains.kotlin.plugin.compose")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pengingattagihan.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        // Jetpack Glance menyusun tampilan widget dengan Compose.
        compose = true
    }

    compileOptions {
        // Diperlukan oleh flutter_local_notifications (Fitur 2).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pengingattagihan.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
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
    // Diperlukan oleh flutter_local_notifications (Fitur 2).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Fitur 4: widget Home Screen. Versinya disamakan dengan yang dipakai
    // plugin home_widget supaya tidak ada dua versi Glance di classpath.
    implementation("androidx.glance:glance-appwidget:1.2.0")

    // Tes unit sisi Android untuk hitungan hari widget (HitungHari.kt).
    // Dijalankan dengan: cd android && ./gradlew :app:testDebugUnitTest
    testImplementation("junit:junit:4.13.2")
}
