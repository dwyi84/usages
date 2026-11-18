#!/bin/sh
# Install the AI Usages GNOME Shell extension and collector for the current user.
set -eu

UUID="aiusages@melissasoft"
SRC=$(dirname "$(readlink -f "$0")")
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
EXT_DIR="$DATA_HOME/gnome-shell/extensions/$UUID"
COLLECTOR_DIR="$DATA_HOME/aiusages/collector"
BIN_DIR="$HOME/.local/bin"

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required" >&2
    exit 1
fi

if ! python3 -c 'import gi' >/dev/null 2>&1; then
    echo "python3-gi (PyGObject) is required: sudo apt install python3-gi" >&2
    exit 1
fi

echo "==> Installing collector to $COLLECTOR_DIR"
mkdir -p "$COLLECTOR_DIR" "$BIN_DIR" "$EXT_DIR"
rm -rf "$COLLECTOR_DIR/aiusages"
cp -r "$SRC/collector/aiusages" "$COLLECTOR_DIR/"
find "$COLLECTOR_DIR" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
install -m 0755 "$SRC/bin/aiusages-collect" "$BIN_DIR/aiusages-collect"

echo "==> Installing extension to $EXT_DIR"
rm -rf "$EXT_DIR"
mkdir -p "$EXT_DIR"
cp -r "$SRC/extension/$UUID/." "$EXT_DIR/"
if [ -f "$SRC/remote-install.sh" ]; then
    install -m 0755 "$SRC/remote-install.sh" "$EXT_DIR/remote-install.sh"
fi
glib-compile-schemas "$EXT_DIR/schemas"

echo "==> Enabling $UUID"
if gnome-extensions enable "$UUID" 2>/dev/null; then
    echo "    enabled"
else
    echo "    The shell has not loaded the new extension yet."
    echo "    Reload the shell (X11: Alt+F2, type 'r', Enter) and run:"
    echo "      gnome-extensions enable $UUID"
fi

if ! printf '%s' ":$PATH:" | grep -q ":$HOME/.local/bin:"; then
    echo
    echo "NOTE: $BIN_DIR is not on your PATH."
    echo "      Set the absolute collector path in Settings → General if needed:"
    echo "      $BIN_DIR/aiusages-collect"
fi

echo
echo "Done. Open the AI Usages indicator in the top bar."
