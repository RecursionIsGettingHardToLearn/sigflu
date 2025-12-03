plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.sig"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.sig"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    release {
            // CORRECCIÓN: En Kotlin DSL se usa 'isMinifyEnabled =' y 'true' para reducir tamaño
            isMinifyEnabled = true 
            isShrinkResources = true
            
            // Esta línea es CRUCIAL para evitar el error de Google Maps
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
            
            // Usamos la firma de debug por ahora (como tenías en tu código)
            signingConfig = signingConfigs.getByName("debug")
        }
}

flutter {
    source = "../.."
}
