# LimenArc Terminal

An Android terminal emulator with a modern graphical interface, inspired by Termux.

## Features

| Screen | Description |
|--------|-------------|
| **Terminal** | Full shell emulator with multi-session tabs, command history, ANSI color output, and an interrupt button |
| **File Browser** | Graphical file explorer with folder navigation, hidden-file toggle, file-type icons, and size/date metadata |
| **Packages** | Package manager UI — search, install, uninstall, and upgrade packages with live progress indicators |
| **Settings** | Configurable font size, color scheme, font family, cursor blink, scrollback buffer, and more |

## Architecture

```
app/src/main/java/com/limenArc/terminal/
├── MainActivity.kt              # Entry point, nav drawer + NavHost
├── model/                       # Data classes (TerminalLine, FileItem, Package)
├── terminal/
│   ├── CommandExecutor.kt       # Shell process runner with built-in cd/pwd/clear
│   ├── TerminalSession.kt       # Per-session state: lines, history, running flag
│   └── TerminalService.kt       # Foreground service to keep sessions alive
├── viewmodel/
│   ├── TerminalViewModel.kt     # Multi-session management
│   ├── FileBrowserViewModel.kt  # Directory navigation + file listing
│   └── PackagesViewModel.kt     # Package list, search, install/uninstall state
└── ui/
    ├── theme/                   # Dark color scheme + monospace typography
    ├── components/              # TerminalOutput, CommandInput, SessionTabs, AppDrawer
    └── screens/                 # TerminalScreen, FileBrowserScreen, PackagesScreen, SettingsScreen
```

## Tech Stack

- **Language**: Kotlin
- **UI**: Jetpack Compose + Material 3
- **Navigation**: Navigation Compose
- **State**: `StateFlow` + `collectAsStateWithLifecycle`
- **Concurrency**: Kotlin Coroutines
- **Min SDK**: 26 (Android 8.0)
- **Target SDK**: 35 (Android 15)

## Building the APK

### Option 1 — GitHub Actions (easiest, no SDK needed)

Push to any branch. The workflow at `.github/workflows/build-apk.yml` runs
automatically and uploads `limenarcterminal-debug.apk` as a downloadable artifact:

```
GitHub repo → Actions → Build APK → (latest run) → Artifacts → limenarcterminal-debug
```

Tag a release to get a permanent GitHub Release with the APK attached:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

---

### Option 2 — Docker (no Android Studio needed)

```bash
# Build the image and extract the APK into ./out/
./build-apk.sh --docker

# or manually:
docker build -t limenarcterminal-builder .
mkdir -p out
docker run --rm -v "$PWD/out:/out" limenarcterminal-builder
# APK → out/limenarcterminal-debug.apk
```

---

### Option 3 — Local Android SDK

```bash
# Requires: JDK 17+, Android SDK with platforms;android-35 + build-tools;34.0.0
export ANDROID_HOME=~/Android/Sdk          # Linux
# export ANDROID_HOME=~/Library/Android/sdk  # macOS

./build-apk.sh          # auto-detects SDK
# or
./gradlew assembleDebug
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`

---

### Requirements (local build)

- Android Studio Hedgehog or newer
- JDK 17
- Android SDK 35 + build-tools 34.0.0
