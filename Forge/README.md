# Forge

Forge is an on-device Android app that turns user-supplied web content
(HTML/CSS/JS, a website, Markdown, plain text, or a PDF) into its own,
separately-installable APK - **with no PC, no cloud build service, and no
internet required for local content**.

This document explains how it's built, how the on-device "compiler" works,
and what the security model is.

---

## 1. Why template injection?

`aapt2` and the Gradle/AGP build chain cannot run on Android. So Forge can't
"compile" a new APK from source the normal way. Instead it uses **template
injection**:

1. At **app build time** (on a normal dev machine, via Gradle), a tiny
   second app module - [`template-app`](template-app) - is compiled into a
   real, working APK. That APK is embedded inside Forge as a raw resource:
   [`app/src/main/res/raw/template.apk`](app/src/main/res/raw).
2. At **runtime**, Forge:
   - copies that template APK to its private storage,
   - opens it as a zip and replaces `assets/www/*` with the user's content,
   - rewrites the binary `AndroidManifest.xml` and `resources.arsc` to give
     the new app a unique package name, display name, and launcher icon,
   - re-aligns and re-signs the result,
   - and saves it to `Downloads/Forge/<name>.apk`, ready to install.

No compilation happens on-device - only **zip surgery and binary XML/resource
editing**, which is exactly what [ARSCLib](https://github.com/REAndroid/ARSCLib)
and Google's [`apksig`](https://android.googlesource.com/platform/tools/apksig/)
are designed for, both as pure-Java libraries with no native toolchain
dependency.

---

## 2. The template app (`template-app`)

[`template-app`](template-app) is a minimal Material/AppCompat WebView shell
(`MainActivity.kt`). On launch it reads `assets/forge.json`:

```json
{ "mode": "local" }
```
loads `file:///android_asset/www/index.html` - the user's bundled content.

```json
{ "mode": "url", "url": "https://example.com" }
```
loads the given URL directly ("online wrapper" mode).

The WebView has JavaScript and DOM storage enabled, file access for its own
bundled assets (but **not** `allowFileAccessFromFileURLs` /
`allowUniversalAccessFromFileURLs`, to avoid letting bundled pages reach
arbitrary device files), and the back button navigates WebView history before
falling back to closing the activity.

`template-app` is built once as part of the normal Gradle build
(`:template-app:assembleRelease`) and its output APK is copied into
`app/src/main/res/raw/template.apk` by the `:app:copyTemplateApk` task (see
`app/build.gradle.kts`), which runs automatically before resources are merged.
It is intentionally **unsigned** - Forge re-signs every generated APK on
device, so the template's own signature is irrelevant and is discarded.

---

## 3. The Forge pipeline (`app/.../packaging`)

`ApkForge.forge(...)` runs the whole pipeline off the main thread (a `Flow`
collected from a coroutine), emitting [`ForgeStage`](app/src/main/java/com/forge/app/packaging/ForgeStage.kt)
updates the UI uses to drive the progress screen:

| Stage | Class | What happens |
| --- | --- | --- |
| 1. Inject | [`ZipContentInjector`](app/src/main/java/com/forge/app/packaging/ZipContentInjector.kt) | Copies the extracted template APK entry-by-entry into a new zip, **dropping** `assets/www/*` and `assets/forge.json`, and writing the user's `assets/www/**` plus a fresh `forge.json` in their place. |
| 2. Patch manifest | [`ManifestPatcher`](app/src/main/java/com/forge/app/packaging/ManifestPatcher.kt) | Uses **ARSCLib** to load the APK's binary `AndroidManifest.xml`, set a unique `package` (application ID), rewrite `android:label` to the user's chosen name (as a raw string, so `resources.arsc` doesn't need touching), and set the main activity's `android:screenOrientation`. |
| 3. Patch icon | [`IconPatcher`](app/src/main/java/com/forge/app/packaging/IconPatcher.kt) | Replaces every `res/mipmap-*/ic_launcher(.*).png` entry with a density-appropriate resize of the user's chosen image (or a generated initials icon). |
| 4. Align | [`ApkRealigner`](app/src/main/java/com/forge/app/packaging/ApkRealigner.kt) + [`ZipAligner`](app/src/main/java/com/forge/app/packaging/ZipAligner.kt) | Re-implements the relevant part of `zipalign`: every `STORED` (uncompressed) entry's data is padded (via a zip "extra field") so it starts on a 4-byte boundary. |
| 5. Sign | [`ApkSigner`](app/src/main/java/com/forge/app/packaging/ApkSigner.kt) + [`KeystoreManager`](app/src/main/java/com/forge/app/packaging/KeystoreManager.kt) | Signs with **APK Signature Scheme v2/v3** using Google's standalone `apksig` library and a per-user keystore. |
| 6. Output | [`OutputWriter`](app/src/main/java/com/forge/app/output/OutputWriter.kt) | Writes the signed APK to `Downloads/Forge/<name>.apk` via `MediaStore` (API 29+) or directly (API 26-28). |

Each stage writes to its own temp file in `cacheDir/forge_build/<uuid>/`,
which is deleted when the run finishes (success or failure). Any exception is
caught and surfaced to the UI as `ForgeStage.Error(message)` with the real
exception message - no silent failures.

### Unique package names

Each forged app gets `com.forge.gen.<10 hex chars>`, derived from a
SHA-256 hash of the app name + a timestamp + a random UUID
([`PackageNameGenerator`](app/src/main/java/com/forge/app/packaging/PackageNameGenerator.kt)).
This guarantees apps don't collide on install, even if the user picks the
same name twice.

### zipalign, implemented

`zipalign`/`aapt2` aren't available on Android, so
[`ZipAligner`](app/src/main/java/com/forge/app/packaging/ZipAligner.kt)
re-implements the core idea: for each `STORED` zip entry, it computes a
"padding" extra-field (header ID `0x0000`, a value the ZIP spec marks
reserved/ignorable) sized so the entry's data starts on a 4-byte boundary.
[`ApkRealigner`](app/src/main/java/com/forge/app/packaging/ApkRealigner.kt)
runs this as the last rewrite before signing, since both ARSCLib's manifest
patching and the icon-replacement pass rewrite the zip and don't preserve
alignment themselves.

---

## 4. Input types

All importers live in [`app/src/main/java/com/forge/app/input`](app/src/main/java/com/forge/app/input)
and produce a [`ProcessedContent`](app/src/main/java/com/forge/app/data/ProcessedContent.kt)
(a `wwwDir` to inject, or a URL for "online wrapper" mode), plus any warnings
shown on the preview screen.

- **Folder (SAF)** - [`FolderImporter`](app/src/main/java/com/forge/app/input/FolderImporter.kt)
  copies the picked tree via `DocumentFile`. If there's no top-level
  `index.html`, it promotes the first `.html` file it finds, or generates a
  simple file-listing page as a last resort.
- **Single HTML file** - [`HtmlFileImporter`](app/src/main/java/com/forge/app/input/HtmlFileImporter.kt)
  becomes `index.html`. If it references other local files, a warning is
  shown (SAF only grants access to the one picked file).
- **URL** - [`UrlImporter`](app/src/main/java/com/forge/app/input/UrlImporter.kt):
  - *Online wrapper*: `forge.json` is `{"mode":"url","url":...}` and the
    template's WebView loads it live (needs internet at runtime).
  - *Snapshot* (best effort): downloads the HTML with Jsoup, inlines
    same-origin `<link rel=stylesheet>`, `<script src>`, and `<img src>`
    resources into `assets/`, and rewrites their paths. Cross-origin
    resources and JS-driven content are left as live links/warnings - this
    is explicitly **best effort**, and the UI says so.
- **Markdown** - [`MarkdownImporter`](app/src/main/java/com/forge/app/input/MarkdownImporter.kt)
  renders to HTML with [commonmark-java](https://github.com/commonmark/commonmark-java)
  and wraps it in a small dark-mode-aware stylesheet.
- **Plain text / PDF** - [`TextAndPdfImporter`](app/src/main/java/com/forge/app/input/TextAndPdfImporter.kt):
  text is wrapped in a `<pre>` viewer; PDFs are rasterised page-by-page with
  Android's built-in `PdfRenderer` into PNGs and laid out as a scrolling
  image gallery (capped at 60 pages, with a warning if truncated).

---

## 5. UI flow

Single-activity Compose app (`MainActivity` + `ForgeApp`), Material 3,
dark-mode aware (`ForgeTheme`, with dynamic color on Android 12+):

```
Home (pick input) -> Preview (WebView) -> Customize (name / icon / orientation)
   -> Forging (progress: inject -> patch -> icon -> align -> sign -> save)
   -> Success (Install / Share / Forge another)
```

- **Customize**: a default icon is generated from the app name's initials
  ([`InitialsIconGenerator`](app/src/main/java/com/forge/app/icon/InitialsIconGenerator.kt));
  the user can replace it with any image.
- **Forging**: shows each pipeline stage, ticking off as it completes; on
  error, shows the real exception message and a "Try again" button.
- **Success**: if Forge doesn't yet have the "install unknown apps"
  permission, an explainer card links straight to the relevant Settings
  screen (`Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES`). Install opens the
  system package installer via `ACTION_VIEW`; Share opens the normal share
  sheet. Both use a `FileProvider` for the `content://` URI.

---

## 6. Security model

- **Per-user signing key** ([`KeystoreManager`](app/src/main/java/com/forge/app/packaging/KeystoreManager.kt)):
  on first forge, Forge generates a 2048-bit RSA key and a self-signed
  certificate (via BouncyCastle, since Android's default JCA provider has no
  certificate generator), stored as a PKCS#12 file in Forge's private app
  storage. Every app Forge ever builds is signed with this same key, so:
  - a forged app can be re-forged and reinstalled as an "update" (Android
    requires matching signatures for updates) without uninstalling first;
  - if Forge is uninstalled or its data cleared, the key is gone -
    previously-forged apps remain installed and runnable, but can no longer
    be "updated" in place (a future forge of the same content would need a
    fresh install).
- **What forged apps *can* do**: render the bundled HTML/CSS/JS (or a live
  URL) in a WebView with JavaScript and DOM storage enabled. If built in
  "online wrapper"/"snapshot" mode, they hold `INTERNET` /
  `ACCESS_NETWORK_STATE` permissions (inherited from the template) to load
  that content.
- **What forged apps *can't* do**: they request **no other dangerous
  permissions** - no camera, contacts, location, storage, etc. The WebView
  does **not** enable `allowFileAccessFromFileURLs` or
  `allowUniversalAccessFromFileURLs`, so bundled pages can't read arbitrary
  files on the device or bypass same-origin restrictions. They are ordinary,
  sandboxed Android apps like any other.
- **Forge itself** requests `REQUEST_INSTALL_PACKAGES` (to launch the
  installer for what it builds), `INTERNET`/`ACCESS_NETWORK_STATE` (for URL
  input/snapshot), and on API 26-28 only, legacy storage permissions to write
  into `Downloads/Forge`.
- **Isolation between forged apps**: each gets a distinct `com.forge.gen.*`
  package name, so they install and run as fully separate apps with separate
  data directories - even though they share a signing key.

---

## 7. Building

This is a standard multi-module Android Studio project with the Gradle
wrapper included.

```sh
./gradlew :app:assembleDebug
```

That single command:
1. builds `:template-app` (`assembleRelease`, unsigned),
2. copies its output APK into `app/src/main/res/raw/template.apk`
   (`:app:copyTemplateApk`, wired into the resource-merge tasks), and
3. builds Forge itself with that template embedded.

Run unit tests (zip injection + package-name generation) with:

```sh
./gradlew :app:testDebugUnitTest
```

Open the project root in Android Studio as-is; both modules are registered
in `settings.gradle.kts`.

**Requirements**: JDK 17, Android SDK with `compileSdk 34` / a recent build
tools version, and network access to Google's Maven (`dl.google.com`) and
Maven Central for dependencies (ARSCLib, apksig, BouncyCastle, commonmark,
Jsoup, AndroidX/Compose).

---

## 8. Library choices & notes

- **ARSCLib** (`io.github.reandroid:ARSCLib`) for binary
  `AndroidManifest.xml` / `resources.arsc` editing - the only actively
  maintained pure-Java library for this; AAPT2 itself can't run on Android.
  If a future ARSCLib release renames a method used in `ManifestPatcher`
  (e.g. `getOrCreateAndroidAttribute`, `refresh`), it's a small, isolated fix
  in that one file - all manifest editing is centralized there. The root
  `settings.gradle.kts` also adds JitPack as a repository: if the
  `io.github.reandroid:ARSCLib` coordinate isn't available on Maven Central
  for the pinned version, use JitPack's `com.github.REAndroid:ARSCLib:<tag>`
  coordinate instead (same code, published from the GitHub repo directly).
- **apksig** (`com.android.tools.build:apksig`) for v2/v3 signing - it's the
  same engine `apksigner` uses, is pure Java/Kotlin (just `RandomAccessFile`
  I/O), and has no dependency on the Android Gradle Plugin or a desktop JDK
  feature unavailable on Android.
- **BouncyCastle** (`bcprov-jdk18on` / `bcpkix-jdk18on`) only for generating
  the one self-signed certificate used for the per-user signing key - the
  stock Android JCA provider can produce key pairs but not X.509
  certificates.
- **commonmark-java** for Markdown - small, pure Java, no Android-specific
  APIs.
- **Jsoup** for snapshot-mode HTML parsing/rewriting - robust HTML parsing
  with a simple DOM API, works fine on Android.
- **Custom zipalign** instead of `zipflinger`/`apkzlib` - those are AGP-internal
  tools designed to run on a desktop JDK as part of a Gradle build and pull
  in a large dependency graph; the alignment algorithm itself is short
  enough (`ZipAligner`, ~40 lines) to reimplement directly with
  `java.util.zip`, which is guaranteed available on Android.

---

## 9. Acceptance walkthrough

1. Install Forge (only app on the device).
2. **Home -> "A folder of web files"** -> pick a folder containing
   `index.html` -> **Preview** shows it rendering -> **Customize**, name it
   "Test", keep the generated icon -> **Forge APK** -> progress runs through
   inject/patch/icon/align/sign/save -> **Success** -> **Install** -> grant
   "install unknown apps" if prompted -> open "Test" -> page renders, fully
   offline (airplane mode).
3. **Home -> "A website URL"** -> enter a URL, choose "Online" or "Offline
   copy" -> **Preview** -> **Customize**, give it a different name and icon
   -> **Forge APK** -> **Install**.
4. Both "Test" and the second app appear as separate launcher icons with
   distinct names/icons and distinct `com.forge.gen.*` package names, and
   both can be opened independently.
