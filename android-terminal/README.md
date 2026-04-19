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

## Building

```bash
./gradlew assembleDebug
```

APK output: `app/build/outputs/apk/debug/app-debug.apk`

## Requirements

- Android Studio Hedgehog or newer
- JDK 17
- Android SDK 35
