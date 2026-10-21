#!/usr/bin/env bash
# Automated restore script for Chromecast with Google TV (Sabrina 4K / Boreal HD).
# Restores disabled packages, re-enables stock launcher (launcherx), and restores Home activity.
#
# Usage:
#   TV_HOST=192.168.1.19 ./restore.sh [debloat_list.txt]
#   ./restore.sh 192.168.1.19 [debloat_list.txt]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    export TV_HOST="$1"
    shift
fi

TV_HOST="${TV_HOST:-}"
if [ -z "$TV_HOST" ]; then
    echo "Error: Set TV_HOST or pass TV IP address as first argument." >&2
    echo "Usage: TV_HOST=192.168.1.19 ./restore.sh [debloat_list.txt]" >&2
    exit 1
fi

PY="tools/venv/bin/python"
if [ ! -x "$PY" ]; then
    PY="python3"
fi

STOCK_LAUNCHER="com.google.android.apps.tv.launcherx"
LIST_FILE="${1:-}"

echo "=== CleanYourTV Restore Script ==="
echo "Target TV: $TV_HOST"
echo "Stock Launcher: $STOCK_LAUNCHER"

if [ -n "$LIST_FILE" ] && [ -f "$LIST_FILE" ]; then
    echo "Restoring packages from: $LIST_FILE"
    tools/restore.sh "$LIST_FILE" "$STOCK_LAUNCHER"
else
    echo "Restoring stock launcher and default home..."
    "$PY" -I tools/tv.py "pm enable --user 0 $STOCK_LAUNCHER" || true
    "$PY" -I tools/tv.py "cmd package set-home-activity $STOCK_LAUNCHER/.MainActivity" || true
    "$PY" -I tools/tv.py "settings put global window_animation_scale 1.0" || true
    "$PY" -I tools/tv.py "settings put global transition_animation_scale 1.0" || true
    "$PY" -I tools/tv.py "settings put global animator_duration_scale 1.0" || true
fi

echo "Verifying home package resolution..."
CURRENT_HOME=$("$PY" -I tools/tv.py "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME" | tr -d '\r')
echo "Current Home: $CURRENT_HOME"
echo "Restore completed successfully."
