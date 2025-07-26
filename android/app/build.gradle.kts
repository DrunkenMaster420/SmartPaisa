plugins {
    id("com.android.application")
    id("kotlin-android")
    // Do NOT specify 'org.jetbrains.kotlin.android' with a version here!
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    ndkVersion = "27.0.12077973"
    namespace = "com.example.smartpaisaa"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.smartpaisaa"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
