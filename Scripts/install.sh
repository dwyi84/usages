#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$DIR/build/Usages.app" ]; then
    echo "==> Building app first..."
    "$DIR/Scripts/build_app.sh"
fi

TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

echo "==> Installing Usages to $TARGET_DIR/Usages.app..."
# 기존 프로세스 종료
pkill -f "Usages.app/Contents/MacOS/Usages" || true

rm -rf "$TARGET_DIR/Usages.app"
cp -R "$DIR/build/Usages.app" "$TARGET_DIR/Usages.app"

echo "==> Launching installed Usages..."
open "$TARGET_DIR/Usages.app"

echo "==> Installation complete! Usages is now running in your menu bar."
