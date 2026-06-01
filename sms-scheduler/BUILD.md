# Building the SMS Scheduler APK

## Option A — let GitHub Actions build it (no setup)

1. Push any change under `sms-scheduler/` (or run the **Build SMS Scheduler APK**
   workflow manually from the Actions tab).
2. Download `sms-scheduler-debug.apk` from the **`sms-apk-latest`** GitHub Release.
3. On your phone: enable *Install unknown apps*, open the APK, tap **Install**.

## Option B — build locally

### Prerequisites

| Tool | Version |
|------|---------|
| JDK | 17 |
| Android SDK | Platform 34 + Build-tools 34.0.0 |

Point the build at your SDK by creating `sms-scheduler/local.properties`:

```properties
sdk.dir=/path/to/Android/sdk
```

(Android Studio writes this file automatically when you open the project.)

### Build a debug APK

```bash
cd sms-scheduler
./gradlew assembleDebug
# Output: app/build/outputs/apk/debug/app-debug.apk
```

### Open in Android Studio

`File → Open…` → select the `sms-scheduler` folder → let Gradle sync → **Run**.

---

## First-run permissions

When the app starts it asks for:

- **Send SMS** — required to send any message.
- **Notifications** (Android 13+) — to tell you when a message was sent/failed.
- **Alarms & reminders** (Android 12+) — tap *Open Settings* and enable it so the
  message fires at the exact time you chose.

## Project layout

```
sms-scheduler/
├── app/src/main/
│   ├── AndroidManifest.xml
│   ├── java/com/limen/smsscheduler/
│   │   ├── MainActivity.kt        # form + list UI
│   │   ├── MessageAdapter.kt      # RecyclerView rows
│   │   ├── ScheduledMessage.kt    # data model (+ JSON)
│   │   ├── MessageStore.kt        # SharedPreferences persistence
│   │   ├── SmsScheduler.kt        # AlarmManager wrapper
│   │   ├── SendSmsReceiver.kt     # fires at send time → SmsManager
│   │   ├── SmsSentReceiver.kt     # records delivery result
│   │   ├── BootReceiver.kt        # re-arms alarms after reboot
│   │   └── Notifications.kt       # status notifications
│   └── res/                       # layouts, theme, launcher icon
├── build.gradle / settings.gradle # Gradle 8.7, AGP 8.5.2, Kotlin 1.9.24
└── gradlew                        # Gradle wrapper
```
