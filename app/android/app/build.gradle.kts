import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Upload (release) key, from environment variables (CI) or the git-ignored
// android/key.properties (a local machine). Null when neither is set up.
val uploadKey: Map<String, String>? =
    run {
        val props = Properties()
        val keyProperties = rootProject.file("key.properties")
        if (keyProperties.exists()) keyProperties.inputStream().use { props.load(it) }
        fun read(env: String, prop: String): String? =
            System.getenv(env)?.takeIf { it.isNotBlank() } ?: props.getProperty(prop)
        val storeFile = read("ROAMIO_KEYSTORE_FILE", "storeFile")
        val storePassword = read("ROAMIO_KEYSTORE_PASSWORD", "storePassword")
        if (storeFile == null || storePassword == null) return@run null
        mapOf(
            "storeFile" to storeFile,
            "storePassword" to storePassword,
            "keyAlias" to (read("ROAMIO_KEY_ALIAS", "keyAlias") ?: "upload"),
            "keyPassword" to (read("ROAMIO_KEY_PASSWORD", "keyPassword") ?: storePassword),
        )
    }

android {
    namespace = "app.roamio.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.roamio.android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "env"
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "Roamio dev"
            manifestPlaceholders["linkHost"] = "roamio-dev-varun.web.app"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "Roamio"
            manifestPlaceholders["linkHost"] = "roamio-prod-varun.web.app"
        }
    }

    signingConfigs {
        if (uploadKey != null) {
            create("release") {
                storeFile = file(uploadKey.getValue("storeFile"))
                storePassword = uploadKey.getValue("storePassword")
                keyAlias = uploadKey.getValue("keyAlias")
                keyPassword = uploadKey.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The upload key when one is set up (docs/RELEASING.md); otherwise the
            // debug key, so local `flutter run --release` still works.
            signingConfig =
                if (uploadKey != null) {
                    signingConfigs.getByName("release")
                } else {
                    check(System.getenv("ROAMIO_REQUIRE_SIGNING") != "true") {
                        "ROAMIO_REQUIRE_SIGNING is set but no upload key was found: set " +
                            "ROAMIO_KEYSTORE_FILE and ROAMIO_KEYSTORE_PASSWORD or add android/key.properties."
                    }
                    signingConfigs.getByName("debug")
                }
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
