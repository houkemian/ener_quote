plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Google 登录（与 Google Cloud Console 中「OAuth 2.0 客户端 ID」一致）：
 * - 在 [android/gradle.properties] 中设置 `GOOGLE_SERVER_CLIENT_ID=xxx.apps.googleusercontent.com`
 *   （通常为 **Web 应用** 类型客户端，与 Flutter `--dart-define=GOOGLE_SERVER_CLIENT_ID` 相同）。
 * - 同时在 Google Cloud 为该包名 [one.dothings.enerquote] 创建 **Android** 类型客户端并配置 SHA-1。
 * 若未配置，构建仍可成功；登录依赖 Dart 侧 `serverClientId`，本处 `default_web_client_id` 为可选增强。
 */
val googleServerClientId: String =
    (project.findProperty("GOOGLE_SERVER_CLIENT_ID") as String?)?.trim().orEmpty()

android {
    namespace = "one.dothings.enerquote"
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
        applicationId = "one.dothings.enerquote"
        manifestPlaceholders["appAuthRedirectScheme"] = "one.dothings.enerquote"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        if (googleServerClientId.isNotEmpty()) {
            resValue("string", "default_web_client_id", googleServerClientId)
        }
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
