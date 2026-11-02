#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$ROOT/Resources/Info.plist")"
APP_BUNDLE="$ROOT/build/AI Usages.app"
DIST_DIR="$ROOT/dist"

echo "==> Building AI Usages release bundle..."
"$ROOT/Scripts/build_app.sh"

mkdir -p "$DIST_DIR"
ZIP_OUT="$DIST_DIR/AIUsages-$VERSION.zip"
rm -f "$ZIP_OUT"

echo "==> Packaging $ZIP_OUT..."
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_OUT"

SHA="$(shasum -a 256 "$ZIP_OUT" | awk '{print $1}')"

echo "==> Successfully packaged AI Usages v$VERSION:"
echo "    File:   $ZIP_OUT"
echo "    SHA256: $SHA"
