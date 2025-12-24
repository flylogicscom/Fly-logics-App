plugins {
  id("com.android.application")
  id("org.jetbrains.kotlin.android")
  id("com.google.gms.google-services") // <- aplicado aquí
  id("dev.flutter.flutter-gradle-plugin")
  
}

flutter { source = "../.." }

android {
    lint { checkReleaseBuilds = false; abortOnError = false }

    namespace = "com.flylogicdlogbookapp"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.flylogicdlogbookapp"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") { isDebuggable = true; isMinifyEnabled = false; isShrinkResources = false }
        getByName("release") { isMinifyEnabled = false; isShrinkResources = false; signingConfig = signingConfigs.getByName("debug") }
    }

    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    kotlinOptions { jvmTarget = "17" }
}

kotlin { jvmToolchain(17) }
