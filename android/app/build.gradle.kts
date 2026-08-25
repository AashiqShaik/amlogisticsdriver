import java.security.KeyStore
import java.security.cert.Certificate
import java.security.MessageDigest
import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Helper: compute SHA-256 fingerprint of a certificate file (JKS/PKCS12)
// Returns uppercase colon-separated hex, e.g. "AB:CD:EF:..."
// ---------------------------------------------------------------------------
fun keystoreSha256(
    keystorePath: String,
    keystorePassword: String,
    keyAlias: String
): String {
    val ks = KeyStore.getInstance(KeyStore.getDefaultType())
    java.io.FileInputStream(keystorePath).use { fis ->
        ks.load(fis, keystorePassword.toCharArray())
    }
    val cert: Certificate = ks.getCertificate(keyAlias)
        ?: throw GradleException(
            "Alias '$keyAlias' not found in keystore '$keystorePath'."
        )
    val md = MessageDigest.getInstance("SHA-256")
    val digest = md.digest(cert.encoded)
    return digest.joinToString(":") { "%02X".format(it) }
}

// ---------------------------------------------------------------------------
// Helper: read the first sha256_cert_fingerprints entry from assetlinks.json
// ---------------------------------------------------------------------------
fun assetlinksSha256(): String? {
    val assetlinksFile = rootProject.file("../web/.well-known/assetlinks.json")
    if (!assetlinksFile.exists()) return null
    @Suppress("UNCHECKED_CAST")
    val parsed = JsonSlurper().parse(assetlinksFile) as List<Map<String, Any>>
    for (entry in parsed) {
        val target = entry["target"] as? Map<*, *> ?: continue
        val fingerprints = target["sha256_cert_fingerprints"] as? List<*> ?: continue
        val first = fingerprints.firstOrNull()?.toString() ?: continue
        if (first.isNotBlank()) return first
    }
    return null
}

android {
    namespace = "in.amlogistics.driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "in.amlogistics.driver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // TODO (Google Play Console): Replace with your actual keystore details.
            // Generate with: keytool -genkey -v -keystore amlogistics-release.jks
            //                        -alias amlogistics -keyalg RSA -keysize 2048 -validity 10000
            // Then set these via environment variables or a local keystore.properties file.
            // DO NOT commit the keystore or passwords to version control.
            storeFile = file(System.getenv("KEYSTORE_PATH") ?: "amlogistics-release.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("KEY_ALIAS") ?: "amlogistics"
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Use release signing if keystore env vars are set, otherwise fall back to debug
            signingConfig = if (System.getenv("KEYSTORE_PATH") != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

// ---------------------------------------------------------------------------
// Build-time App Link SHA-256 validation task
//
// Runs automatically before every release assembly/bundle task.
// Compares the SHA-256 fingerprint of the signing certificate against the
// value declared in web/.well-known/assetlinks.json.
//
// Outcomes:
//   SKIP  – keystore env vars not set (local/debug build) → warning only
//   SKIP  – assetlinks.json still has the placeholder value → warning only
//   PASS  – fingerprints match → build continues
//   FAIL  – fingerprints differ → build aborted with a clear error message
// ---------------------------------------------------------------------------
tasks.register("validateAppLinkSha256") {
    group = "verification"
    description = "Confirms the signing certificate SHA-256 matches assetlinks.json before release."

    doLast {
        val keystorePath = System.getenv("KEYSTORE_PATH")
        val keystorePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
        val keyAlias = System.getenv("KEY_ALIAS") ?: "amlogistics"

        // Skip gracefully when no release keystore is configured (debug / CI without signing)
        if (keystorePath.isNullOrBlank()) {
            println(
                "\n[AppLink SHA-256 Validation] SKIPPED — KEYSTORE_PATH not set. " +
                "Set KEYSTORE_PATH, KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD " +
                "to enable validation for release builds.\n"
            )
            return@doLast
        }

        val keystoreFile = file(keystorePath)
        if (!keystoreFile.exists()) {
            throw GradleException(
                "\n[AppLink SHA-256 Validation] FAILED — Keystore file not found: $keystorePath\n"
            )
        }

        val assetlinksFingerprint = assetlinksSha256()

        // Skip when assetlinks.json still contains the placeholder
        if (assetlinksFingerprint == null ||
            assetlinksFingerprint.contains("REPLACE_WITH") ||
            assetlinksFingerprint.isBlank()
        ) {
            println(
                "\n[AppLink SHA-256 Validation] SKIPPED — assetlinks.json still contains " +
                "the placeholder fingerprint. Update it with the real SHA-256 from " +
                "Google Play Console → Release → Setup → App signing before publishing.\n"
            )
            return@doLast
        }

        val certFingerprint = try {
            keystoreSha256(keystorePath, keystorePassword, keyAlias)
        } catch (e: Exception) {
            throw GradleException(
                "\n[AppLink SHA-256 Validation] FAILED — Could not read signing certificate: " +
                "${e.message}\n"
            )
        }

        if (certFingerprint.equals(assetlinksFingerprint, ignoreCase = true)) {
            println(
                "\n[AppLink SHA-256 Validation] PASSED — " +
                "Signing certificate SHA-256 matches assetlinks.json.\n" +
                "  Fingerprint : $certFingerprint\n"
            )
        } else {
            throw GradleException(
                "\n╔══════════════════════════════════════════════════════════════════╗\n" +
                "║          APP LINK SHA-256 MISMATCH — BUILD ABORTED              ║\n" +
                "╠══════════════════════════════════════════════════════════════════╣\n" +
                "║ Signing certificate SHA-256 does NOT match assetlinks.json.     ║\n" +
                "║                                                                  ║\n" +
                "║ Certificate (keystore) : $certFingerprint\n" +
                "║ assetlinks.json        : $assetlinksFingerprint\n" +
                "║                                                                  ║\n" +
                "║ Android App Links will NOT work with this mismatch.             ║\n" +
                "║                                                                  ║\n" +
                "║ If using Google Play App Signing:                               ║\n" +
                "║   1. Upload the AAB to Play Console (Internal Testing).         ║\n" +
                "║   2. Go to Release → Setup → App signing.                       ║\n" +
                "║   3. Copy the App signing key certificate SHA-256.              ║\n" +
                "║   4. Update web/.well-known/assetlinks.json with that value.    ║\n" +
                "║   5. Deploy assetlinks.json to amlogistics.co.in.               ║\n" +
                "║                                                                  ║\n" +
                "║ If using your own keystore (self-distribution):                 ║\n" +
                "║   Update assetlinks.json with the fingerprint shown above.      ║\n" +
                "╚══════════════════════════════════════════════════════════════════╝\n"
            )
        }
    }
}

// Wire the validation task to run before every release assembly and bundle task
afterEvaluate {
    tasks.matching { task ->
        task.name.startsWith("assemble") && task.name.contains("Release", ignoreCase = true) ||
        task.name.startsWith("bundle")   && task.name.contains("Release", ignoreCase = true)
    }.configureEach {
        dependsOn("validateAppLinkSha256")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.material:material:1.13.0")
    implementation("androidx.concurrent:concurrent-futures:1.3.0")
    implementation("com.google.android.gms:play-services-location:21.3.0")
}
