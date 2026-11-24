import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Production signing material lives outside the source tree: by default
// ~/.soty-keys/keystore.properties, or whatever SOTY_KEYSTORE_PROPS points at.
// The key is never committed and never lands in build-artifacts.
val keystorePropertiesFile: File? = run {
    val fromEnv = System.getenv("SOTY_KEYSTORE_PROPS")
        ?.takeIf { it.isNotBlank() }
        ?.let(::File)
    listOfNotNull(
        fromEnv,
        File(System.getProperty("user.home"), ".soty-keys/keystore.properties"),
    ).firstOrNull { it.isFile }
}

val keystoreProperties = Properties().apply {
    keystorePropertiesFile?.let { file -> FileInputStream(file).use { load(it) } }
}

// Production by default since T-75: every shipped APK/AAB is signed with the
// upload key. `SOTY_SIGNING=debug` (or -PsotySigning=debug) keeps the debug
// certificate for local `flutter run --release` and device experiments.
val productionSigning =
    (System.getenv("SOTY_SIGNING") ?: findProperty("sotySigning") as String?)
        ?.let { it != "debug" } ?: true

android {
    namespace = "ru.dcns.soty"
    // flutter_mesh_network is compiled against API 36.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // flutter_local_notifications requires core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "ru.dcns.soty"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_mesh_network requires API 26+ (BLE/Wi-Fi Direct APIs).
        minSdk = maxOf(flutter.minSdkVersion, 26)
        // Google Play has required API 36 for new apps and updates since
        // 31 August 2026; Flutter 3.32 still defaults to 35.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (productionSigning) {
            create("release") {
                val propsFile = keystorePropertiesFile
                    ?: throw GradleException(
                        "SOTY_SIGNING=production but no keystore.properties was found. " +
                            "Create ~/.soty-keys/keystore.properties or set " +
                            "SOTY_KEYSTORE_PROPS. See scripts/SIGNING.md.",
                    )
                val storePath = keystoreProperties.getProperty("storeFile")
                    ?: throw GradleException("${propsFile.path}: missing storeFile")
                storeFile = File(storePath).let {
                    if (it.isAbsolute) it else File(propsFile.parentFile, storePath)
                }
                storePassword = keystoreProperties.getProperty("storePassword")
                    ?: throw GradleException("${propsFile.path}: missing storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                    ?: throw GradleException("${propsFile.path}: missing keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                    ?: throw GradleException("${propsFile.path}: missing keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Production signing is opt-in (`SOTY_SIGNING=production`); the
            // default keeps the debug key so `flutter run --release` and the
            // published sideload APK stay installable over previous versions.
            signingConfig = if (productionSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    // Two distribution channels from one versionCode and one signature:
    //   site — the APK on soty.su, updates itself from the GitHub release;
    //   play — the bundle for Google Play, no installer permission at all.
    flavorDimensions += "channel"
    productFlavors {
        create("site") {
            dimension = "channel"
        }
        create("play") {
            dimension = "channel"
        }
    }
}

// Flutter passes `--dart-define` values to Gradle as `-Pdart-defines`;
// decode them so a mismatched flavor/define pair fails here instead of
// shipping a build whose UI and manifest disagree about self-updates.
val dartDefines: Set<String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { chunk ->
        try {
            String(Base64.getDecoder().decode(chunk), Charsets.UTF_8)
        } catch (_: IllegalArgumentException) {
            null
        }
    }
    ?.toSet()
    ?: emptySet()

// Only the flavor that is actually being built is checked: `onVariants`
// configures every variant, and a site build must not fail because the play
// variant it is not building lacks its define.
val requestedTasks = gradle.startParameter.taskNames
    .joinToString(" ")
    .lowercase()

androidComponents {
    onVariants { variant ->
        val flavor = variant.flavorName ?: return@onVariants
        if (!requestedTasks.contains(flavor.lowercase())) return@onVariants
        when (flavor) {
            "play" -> check(dartDefines.contains("SOTY_CHANNEL=play")) {
                "the play flavor must be built with " +
                    "--dart-define=SOTY_CHANNEL=play"
            }
            "site" -> check(!dartDefines.contains("SOTY_CHANNEL=play")) {
                "the site flavor cannot use SOTY_CHANNEL=play"
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
