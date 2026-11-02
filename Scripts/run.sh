#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$DIR/build/Usages.app" ]; then
    echo "==> Building app first..."
    "$DIR/Scripts/build_app.sh"
fi

echo "==> Starting Usages toolbar app in background..."
open "$DIR/build/Usages.app"
echo "==> Usages is now running in your macOS menu bar!"
