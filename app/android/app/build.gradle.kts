plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.zohal.connect"
    compileSdk = 36

    defaultConfig {
        applicationId = "app.zohal.connect"
        minSdk = 26
        targetSdk = 34
        // A constant versionCode made later APKs fail to upgrade over an
        // installed build.
        versionCode = 12
        versionName = "0.1.12"

        ndk {
            abiFilters.addAll(listOf("arm64-v8a", "armeabi-v7a", "x86_64"))
        }
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = true
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
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

// Stage native libraries before every build:
// 1. Pinned Aether binaries (fetched by tools/fetch-aether.sh in CI) become
//    jniLibs/<abi>/libaether.so so ZohalVpnService can execute them from
//    nativeLibraryDir (extractNativeLibs=true in the manifest).
// 2. libzohal_tun.so is built from engine/crates/zohal-android with
//    cargo-ndk (Rust tun2proxy JNI runner for the VPN fd).
val repoRoot = rootDir.resolve("../..")
val engineDir = repoRoot.resolve("engine")
val distDir = repoRoot.resolve("third_party/dist")
val stagedJniDir = layout.projectDirectory.dir("src/main/jniLibs")

val abiToDist = mapOf(
    "arm64-v8a" to "android-arm64",
    "armeabi-v7a" to "android-armeabi-v7a",
    "x86_64" to "android-x86_64",
)

tasks.register<Exec>("buildZohalTun") {
    group = "zohal"
    description = "Build libzohal_tun.so for all Android ABIs with cargo-ndk."
    workingDir(engineDir)
    val ndkHome = System.getenv("ANDROID_NDK_HOME") ?: ""
    doFirst {
        if (ndkHome.isEmpty()) {
            throw GradleException(
                "ANDROID_NDK_HOME is not set; install the NDK (r28+) to build libzohal_tun.so."
            )
        }
    }
    // 16 KB page alignment required by recent Android (NDK r28+).
    environment(
        "RUSTFLAGS",
        (System.getenv("RUSTFLAGS")?.plus(" ") ?: "") +
            "-C link-arg=-Wl,-z,max-page-size=16384"
    )
    commandLine(
        "cargo", "ndk",
        "-t", "arm64-v8a",
        "-t", "armeabi-v7a",
        "-t", "x86_64",
        "-o", stagedJniDir.asFile.absolutePath,
        "build", "--release", "-p", "zohal-android"
    )
}

tasks.register("stageAetherLibs") {
    group = "zohal"
    description = "Copy pinned Aether binaries into jniLibs as libaether.so."
    doLast {
        for ((abi, dist) in abiToDist) {
            val src = distDir.resolve("$dist/aether")
            if (!src.exists()) {
                throw GradleException(
                    "Missing Aether binary: ${src.absolutePath}. " +
                        "Run tools/fetch-aether.sh $dist first."
                )
            }
            val destDir = stagedJniDir.dir(abi).asFile
            destDir.mkdirs()
            src.copyTo(destDir.resolve("libaether.so"), overwrite = true)
            logger.lifecycle("Staged libaether.so for $abi")
        }
    }
}

tasks.named("preBuild") {
    dependsOn("stageAetherLibs", "buildZohalTun")
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
}
