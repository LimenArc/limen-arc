#!/usr/bin/env bash
# build-apk.sh — Build the LimenArc Terminal debug APK
# Usage:
#   ./build-apk.sh              # auto-detect: local SDK or Docker
#   ./build-apk.sh --docker     # force Docker build
#   ./build-apk.sh --local      # force local SDK build
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
APK_NAME="limenarcterminal-debug.apk"
GRADLE_VERSION="8.7"

green() { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()   { printf '\033[0;31m%s\033[0m\n' "$*"; }

# ── Argument parsing ──────────────────────────────────────────────────────────
FORCE_DOCKER=false
FORCE_LOCAL=false
for arg in "$@"; do
  case $arg in
    --docker) FORCE_DOCKER=true ;;
    --local)  FORCE_LOCAL=true  ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────
has_android_sdk() {
  [[ -n "${ANDROID_HOME:-}" ]] && \
  [[ -d "$ANDROID_HOME/platforms" ]] && \
  [[ -d "$ANDROID_HOME/build-tools" ]]
}

has_java17() {
  command -v java &>/dev/null && \
  java -version 2>&1 | grep -qE '"(17|2[0-9])\.'
}

has_docker() { command -v docker &>/dev/null && docker info &>/dev/null 2>&1; }

ensure_wrapper_jar() {
  if [[ ! -f "$SCRIPT_DIR/gradle/wrapper/gradle-wrapper.jar" ]]; then
    yellow "gradle-wrapper.jar missing — generating with system Gradle..."
    if command -v gradle &>/dev/null; then
      (cd "$SCRIPT_DIR" && gradle wrapper --gradle-version="$GRADLE_VERSION" --distribution-type=bin)
    else
      red "ERROR: Neither gradle-wrapper.jar nor system 'gradle' found."
      red "Install Gradle $GRADLE_VERSION from https://gradle.org/releases/ and re-run."
      exit 1
    fi
  fi
  chmod +x "$SCRIPT_DIR/gradlew"
}

# ── Local build ───────────────────────────────────────────────────────────────
build_local() {
  green "▶ Building locally..."

  if ! has_java17; then
    red "JDK 17+ required. Install from https://adoptium.net/ and set JAVA_HOME."
    exit 1
  fi

  if ! has_android_sdk; then
    red "Android SDK not found."
    red "Set ANDROID_HOME to your SDK path (e.g. ~/Library/Android/sdk on macOS)."
    red "Minimum required SDK components:"
    red "  platforms;android-35   (or higher)"
    red "  build-tools;34.0.0"
    exit 1
  fi

  ensure_wrapper_jar

  mkdir -p "$OUT_DIR"
  (cd "$SCRIPT_DIR" && ./gradlew assembleDebug --no-daemon)

  SRC="$SCRIPT_DIR/app/build/outputs/apk/debug/app-debug.apk"
  cp "$SRC" "$OUT_DIR/$APK_NAME"
  green "✓ APK written to: $OUT_DIR/$APK_NAME"
  green "  Size: $(du -sh "$OUT_DIR/$APK_NAME" | cut -f1)"
}

# ── Docker build ──────────────────────────────────────────────────────────────
build_docker() {
  green "▶ Building with Docker..."

  if ! has_docker; then
    red "Docker is not running. Install from https://docs.docker.com/get-docker/"
    exit 1
  fi

  mkdir -p "$OUT_DIR"
  docker build -t limenarcterminal-builder "$SCRIPT_DIR"
  docker run --rm -v "$OUT_DIR:/out" limenarcterminal-builder

  if [[ -f "$OUT_DIR/limenarcterminal-debug.apk" ]]; then
    green "✓ APK written to: $OUT_DIR/$APK_NAME"
    green "  Size: $(du -sh "$OUT_DIR/$APK_NAME" | cut -f1)"
  else
    red "Build failed — APK not found in $OUT_DIR"
    exit 1
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo ""
green "═══════════════════════════════════════"
green "  LimenArc Terminal — APK Builder"
green "═══════════════════════════════════════"
echo ""

if $FORCE_DOCKER; then
  build_docker
elif $FORCE_LOCAL; then
  build_local
elif has_android_sdk && has_java17; then
  green "Android SDK detected → building locally"
  build_local
elif has_docker; then
  yellow "Android SDK not found → building with Docker"
  build_docker
else
  red "Neither Android SDK nor Docker found."
  echo ""
  yellow "Options:"
  echo "  1. Install Android Studio: https://developer.android.com/studio"
  echo "     Then: export ANDROID_HOME=~/Library/Android/sdk   (macOS)"
  echo "           export ANDROID_HOME=~/Android/Sdk           (Linux)"
  echo "     Then: ./build-apk.sh --local"
  echo ""
  echo "  2. Install Docker: https://docs.docker.com/get-docker/"
  echo "     Then: ./build-apk.sh --docker"
  echo ""
  echo "  3. Push to GitHub — the CI workflow builds it automatically."
  echo "     Download from: Actions → Build APK → Artifacts"
  exit 1
fi
