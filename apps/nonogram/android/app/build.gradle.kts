import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. The secrets live OUTSIDE the repo so `git clean -xdf`
// cannot delete them and they can never be committed by accident —
// see docs/android-signing.md. Lookup order:
//   1. $NONOGRAM_SECRETS/key.properties   (CI, or a custom location)
//   2. ~/.pink-spider/secrets/nonogram/key.properties   (this machine)
//   3. android/key.properties           (legacy, still honoured)
// None found (fresh clone, CI without secrets): the release build falls
// back to debug keys so it still builds; it just cannot be uploaded to Play.
val keystoreProperties = Properties().apply {
    val candidates = listOfNotNull(
        System.getenv("NONOGRAM_SECRETS")?.let { file("$it/key.properties") },
        file("${System.getProperty("user.home")}/.pink-spider/secrets/nonogram/key.properties"),
        rootProject.file("key.properties"),
    )
    candidates.firstOrNull { it.exists() }?.let { f ->
        f.inputStream().use { load(it) }
        logger.lifecycle("signing: using ${f.path}")
    }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "io.pinkspider.nonogram"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.pinkspider.nonogram"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("key.properties missing — release build signed with debug keys, not uploadable")
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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
