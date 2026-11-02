#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$DIR/build/AI Usages.app" ]; then
    echo "==> Building app first..."
    "$DIR/Scripts/build_app.sh"
fi

TARGET_DIR="/Applications"
if [ ! -w "$TARGET_DIR" ]; then
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

echo "==> Installing AI Usages to $TARGET_DIR/AI Usages.app..."
pkill -f "AI Usages.app/Contents/MacOS/AIUsages" || true

rm -rf "$TARGET_DIR/AI Usages.app"
cp -R "$DIR/build/AI Usages.app" "$TARGET_DIR/AI Usages.app"

echo "==> Launching installed AI Usages..."
open "$TARGET_DIR/AI Usages.app"

echo "==> Installation complete! AI Usages is now running in your menu bar."
