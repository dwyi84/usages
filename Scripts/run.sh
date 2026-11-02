#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -d "$DIR/build/AI Usages.app" ]; then
    echo "==> Building app first..."
    "$DIR/Scripts/build_app.sh"
fi

echo "==> Starting AI Usages menu bar app..."
open "$DIR/build/AI Usages.app"
echo "==> AI Usages is now running in your macOS menu bar!"
