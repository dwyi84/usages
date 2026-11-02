#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "==> Building fresh AI Usages.app..."
"$DIR/Scripts/build_app.sh"

TARGET_APP="/Applications/AI Usages.app"

echo "==> Terminating running instances..."
pkill -f "AIUsages" || true
sleep 1

echo "==> Installing AI Usages to /Applications/AI Usages.app..."
rm -rf "$TARGET_APP"
cp -R "$DIR/build/AI Usages.app" "$TARGET_APP"

# Quarantine 속성 제거
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

echo "==> Launching installed app from /Applications..."
open "$TARGET_APP"

echo "==> Installation complete! AI Usages is now installed in /Applications and active in your menu bar."
