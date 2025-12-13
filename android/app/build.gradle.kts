plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin
}

android {
    namespace = "com.submixtech.churchlink"
    compileSdk = 36

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            storeFile = file("keystore.jks")
            storePassword = "storepassword"
            keyAlias = "key"
            keyPassword = "storepassword"
        }
    }

    defaultConfig {
        applicationId = "com.submixtech.churchlink"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 4
        versionName = "1.0.3"
        multiDexEnabled = true
        ndkVersion = "27.0.12077973"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = signingConfigs.getByName("release")
            buildConfigField("boolean", "IS_DEFERRED_COMPONENT", "false")
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // Core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")


}

flutter {
    source = "../.."
}
