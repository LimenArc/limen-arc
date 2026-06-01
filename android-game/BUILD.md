# Building the Android APK

## Prerequisites

| Tool | Version | Download |
|------|---------|----------|
| Node.js | 18+ | https://nodejs.org |
| Android Studio | Latest | https://developer.android.com/studio |
| Java JDK | 17+ | bundled with Android Studio |

Set `ANDROID_HOME` to your SDK path (e.g. `~/Library/Android/sdk` on Mac).

---

## Steps

### 1 — Install dependencies
```bash
cd android-game
npm install
```

### 2 — Init Capacitor (first time only)
```bash
npx cap init "Monster Realm" com.limen.monsterrealm --web-dir .
npx cap add android
```

### 3 — Sync web assets into the Android project
```bash
npx cap sync android
```

### 4a — Open in Android Studio (GUI build)
```bash
npx cap open android
```
In Android Studio: **Build → Generate Signed Bundle / APK → APK → create/select keystore → Release**.

### 4b — Command-line debug APK (no signing needed)
```bash
cd android/app
./gradlew assembleDebug
# Output: android/app/build/outputs/apk/debug/app-debug.apk
```

### 4c — Release APK (signed)
```bash
cd android/app
./gradlew assembleRelease
# Sign with apksigner or let Android Studio handle it
```

---

## Play in browser (no Android needed)
```bash
cd android-game
npx serve . -p 3000
# Open http://localhost:3000
```

---

## Game controls

| Input | Action |
|-------|--------|
| Virtual D-pad (bottom-left) | Move on world map |
| ⚡ Interact button | Enter dungeon / open shop |
| 🐾 Pals button | Open Pal management screen |
| Skill buttons (battle) | Use class skill |
| 🐾 Pal Atk | Active Pal attacks the enemy |
| 🧪 Item | Use first consumable, or throw trap |
| 🏃 Flee | Attempt to escape (wild only) |

---

## Gameplay summary

- **World Zero elements** — 5 dungeons with multiple floors, boss fights on the final floor, class system (Warrior / Mage / Ranger) with 4 skills each
- **Palworld elements** — 30 monster species across 7 biomes, capture with traps, Pal team (up to 6), active Pal attacks in battle
- Procedurally-generated biome map each session
- Equipment shop, level-up system, save/load via localStorage
