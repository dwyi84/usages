#!/usr/bin/env bash
set -euo pipefail

# Bump the Homebrew tap cask to a released AI Usages version.
# Usage:
#   Scripts/update_cask.sh <version> [path-to-tap-cask]

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:?usage: update_cask.sh <version> [path-to-tap-cask]}"
CASK="${2:-$ROOT/../homebrew-tap/Casks/aiusages.rb}"
ZIP="$ROOT/dist/AIUsages-$VERSION.zip"

[ -f "$ZIP" ] || { echo "zip not found: $ZIP (run Scripts/package_release.sh first)"; exit 1; }
[ -f "$CASK" ] || { echo "cask not found: $CASK"; exit 1; }

SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"

/usr/bin/sed -i '' -E "s/^(  version )\"[^\"]+\"/\1\"$VERSION\"/" "$CASK"
/usr/bin/sed -i '' -E "s/^(  sha256 )(:no_check|\"[^\"]+\")/\1\"$SHA\"/" "$CASK"

echo "Updated $CASK"
echo "  version $VERSION"
echo "  sha256  $SHA"
echo ""
echo "Next: commit & push the tap, then verify with 'brew audit --cask aiusages'."
