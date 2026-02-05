plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.ringinout"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId = "com.example.ringinout"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            // ✅ 올바른 Kotlin 문법
            manifestPlaceholders += mapOf("dartObfuscation" to "false", "enableDebugging" to "true")
            isDebuggable = true
        }
        release {
            // ✅ 올바른 Kotlin 문법
            proguardFiles(
                    getDefaultProguardFile("proguard-android-optimize.txt"),
                    "proguard-rules.pro"
            )
            isShrinkResources = false
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    dependencies { 
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
        
        // Google Play Services for native location monitoring
        implementation("com.google.android.gms:play-services-location:21.0.1")
        implementation("com.google.android.gms:play-services-maps:18.1.0")
    }
}

flutter { source = "../.." }

// ✅ 하위 모듈 설정
subprojects {
    afterEvaluate {
        extensions.findByType<org.jetbrains.kotlin.gradle.dsl.KotlinJvmOptions>()?.apply {
            jvmTarget = "17"
        }
    }
}
