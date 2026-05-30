# Balloon Pop TD 🎯🎈

A tower-defense game for Android. Build and **level up dart launchers** to pop
waves of **water balloons** marching along the track, earn cash for every pop,
and survive **5 unique water-balloon bosses**.

Written as a pure Android `SurfaceView`/`Canvas` game in Java — **no game engine
and no third-party / AndroidX dependencies**, so it builds fast and the APK is
tiny.

## How to play

1. Tap one of the **7 launcher buttons** along the bottom to select it.
2. Tap an open patch of grass to build it (cost is shown on the button).
3. Tap **START WAVE ▶** to send in the balloons. Launchers auto-target and fire.
4. Popping balloons earns **cash**. Tap a placed launcher to **Upgrade** (up to
   Lv 4) or **Sell** it.
5. Don't let balloons leak off the end of the track — that costs lives. Lose all
   your lives and it's game over.
6. Clear all **25 waves** (a boss every 5th wave) to win.

## The 7 dart launchers

| # | Launcher | Cost | Role |
|---|----------|------|------|
| 1 | **Pin Slinger** | $100 | Cheap, reliable single dart |
| 2 | **Spike Burst** | $280 | Fires darts in 8 directions — owns chokepoints |
| 3 | **Long Shot** | $360 | Sniper: hits anywhere on screen, big single hit |
| 4 | **Bouncer** | $320 | Boomerang dart pierces up to 4 balloons |
| 5 | **Frost Popper** | $340 | Chills balloons, slowing them down |
| 6 | **Splash Cannon** | $480 | Explodes on impact, soaking a whole cluster |
| 7 | **Storm Tower** | $1300 | Elite rapid-fire turret — pricey but devastating |

Every launcher upgrades through **4 levels**, boosting damage, range and fire rate.

## The 5 water-balloon bosses

| Wave | Boss | Gimmick |
|------|------|---------|
| 5  | **Splasher**  | Big and tanky |
| 10 | **Bubbler**   | Splits into a swarm when popped |
| 15 | **Tsunami**   | Fast and regenerates health |
| 20 | **Hailstorm** | Armored — shrugs off small hits |
| 25 | **Leviathan** | The final boss. Enormous health pool |

## Building the APK

The actual `.apk` is built by the GitHub Actions workflow
[`.github/workflows/android-build.yml`](../.github/workflows/android-build.yml),
which runs on GitHub's hosted runners (they have the Android SDK and full
network access). After a push to the game branch — or via **Actions → Build
Android APK → Run workflow** — download the APK from the run's
**Artifacts** section (`BalloonPopTD-debug-apk`), then sideload it onto an
Android device (enable "Install unknown apps").

### Build it yourself

With the Android SDK installed locally (and a machine that can reach
`dl.google.com` / `maven.google.com`):

```bash
cd android
./gradlew assembleDebug
# -> app/build/outputs/apk/debug/app-debug.apk
```

- **minSdk:** 21 (Android 5.0) · **targetSdk/compileSdk:** 34
- **Orientation:** portrait, fullscreen
- **Package:** `com.limenarc.balloonpop`

## Project layout

```
android/
├── app/src/main/
│   ├── AndroidManifest.xml
│   ├── java/com/limenarc/balloonpop/
│   │   ├── MainActivity.java        # fullscreen host activity
│   │   ├── GameView.java            # SurfaceView, game loop, input, HUD/shop
│   │   ├── Game.java                # state, waves, economy, world rendering
│   │   └── model/
│   │       ├── LauncherType.java    # the 7 launcher definitions
│   │       ├── BossType.java        # the 5 boss definitions
│   │       ├── DartLauncher.java    # a placed tower + upgrades
│   │       ├── Balloon.java         # balloon / boss entity
│   │       └── Dart.java            # projectile
│   └── res/                         # icons, theme, strings
└── (Gradle wrapper + build files)
```
