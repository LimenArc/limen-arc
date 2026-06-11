import org.gradle.api.tasks.Copy

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.forge.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.forge.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by ARSCLib / apksig and modern AndroidX artifacts.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    composeOptions {
        kotlinCompilerExtensionVersion = "1.5.14"
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.4")
    implementation("androidx.activity:activity-compose:1.9.1")
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.navigation:navigation-compose:2.7.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.4")
    implementation("androidx.documentfile:documentfile:1.0.1")
    implementation("androidx.webkit:webkit:1.11.0")

    // On-device APK manifest / resources.arsc patching (package name, label, icons).
    implementation("io.github.reandroid:ARSCLib:1.3.4")

    // On-device APK Signature Scheme v2/v3 signing (pure Java, no AGP deps).
    implementation("com.android.tools.build:apksig:8.5.2")

    // Self-signed certificate generation for the per-user signing keystore -
    // Android's default JCA provider has no X.509 certificate generator.
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1")
    implementation("org.bouncycastle:bcpkix-jdk18on:1.78.1")

    // Markdown -> HTML for the "Markdown file" input type.
    implementation("org.commonmark:commonmark:0.22.0")

    // HTML parsing for "snapshot" URL imports (rewriting asset references).
    implementation("org.jsoup:jsoup:1.17.2")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
}

// ---------------------------------------------------------------------------
// Embed the compiled template-app APK as a raw resource so Forge can copy and
// patch it on-device at runtime (template injection pattern - aapt2/Gradle
// cannot run on Android, so the "build" step happens here, once, at app
// build time).
// ---------------------------------------------------------------------------
val templateApkTaskName = "assembleRelease"

tasks.register<Copy>("copyTemplateApk") {
    dependsOn(":template-app:$templateApkTaskName")
    from(project(":template-app").layout.buildDirectory.file("outputs/apk/release/template-app-release-unsigned.apk"))
    into(layout.projectDirectory.dir("src/main/res/raw"))
    rename { "template.apk" }
}

afterEvaluate {
    tasks.matching { it.name.startsWith("merge") && it.name.endsWith("Resources") }
        .configureEach { dependsOn("copyTemplateApk") }
    tasks.matching { it.name.startsWith("generate") && it.name.endsWith("Resources") }
        .configureEach { dependsOn("copyTemplateApk") }
}
