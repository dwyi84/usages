#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

export JAVA_HOME="${JAVA_HOME:-$HOME/Android/jdk-17}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"

echo "==> Running Android unit tests..."
./gradlew testDebugUnitTest

echo "==> Building Debug & Release APKs..."
./gradlew assembleDebug assembleRelease

DIST_DIR="$ROOT/dist"
mkdir -p "$DIST_DIR"
cp "$ROOT/app/build/outputs/apk/debug/app-debug.apk" "$DIST_DIR/AIUsages-debug.apk"
cp "$ROOT/app/build/outputs/apk/release/app-release.apk" "$DIST_DIR/AIUsages-release.apk"

echo "==> APKs ready in $DIST_DIR:"
ls -lh "$DIST_DIR"/*.apk
