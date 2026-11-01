plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val stagingKeystorePath = System.getenv("ANDROID_STAGING_KEYSTORE_PATH")
val stagingKeystorePassword = System.getenv("ANDROID_STAGING_KEYSTORE_PASSWORD")
val stagingKeyAlias = System.getenv("ANDROID_STAGING_KEY_ALIAS")
val stagingKeyPassword = System.getenv("ANDROID_STAGING_KEY_PASSWORD")
val hasStagingSigning = listOf(
    stagingKeystorePath,
    stagingKeystorePassword,
    stagingKeyAlias,
    stagingKeyPassword,
).all { !it.isNullOrBlank() }

android {
    namespace = "com.example.glown_scan_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (hasStagingSigning) {
            create("staging") {
                storeFile = file(stagingKeystorePath!!)
                storePassword = stagingKeystorePassword!!
                keyAlias = stagingKeyAlias!!
                keyPassword = stagingKeyPassword!!
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.glown_scan_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(
                if (hasStagingSigning) "staging" else "debug",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
