#!/usr/bin/env bash
# tools/cast-fix.sh - Reload Google Cast credentials after setupwraith disablement
# Compatible with Linux and macOS. Verified with shellcheck.
#
# Usage:
#   TV_HOST=192.168.1.19 ./tools/cast-fix.sh
#   ./tools/cast-fix.sh 192.168.1.19

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

if [ $# -gt 0 ]; then
    export TV_HOST="$1"
fi

TV_HOST="${TV_HOST:-}"
if [ -z "$TV_HOST" ]; then
    echo "Error: Set TV_HOST or pass TV IP address / hostname as first argument." >&2
    echo "Usage: TV_HOST=192.168.1.19 ./tools/cast-fix.sh" >&2
    exit 1
fi

PY="tools/venv/bin/python"
if [ ! -x "$PY" ]; then
    PY="python3"
fi

echo "==> Running Cast credential recovery ritual on ${TV_HOST}..."

# 1. Temporarily re-enable setupwraith
echo "==> Re-enabling setupwraith for credential provision..."
"$PY" -I tools/tv.py "pm enable --user 0 com.google.android.tungsten.setupwraith"

# 2. Force stop mediashell so framework restarts it with fresh credentials
echo "==> Cycling Cast receiver (mediashell)..."
"$PY" -I tools/tv.py "am force-stop com.google.android.apps.mediashell"

# 3. Wait for Cast certificate handshake to complete
echo "==> Waiting 30 seconds for credentials to register in RAM..."
sleep 30

# 4. Disable setupwraith again
echo "==> Disabling setupwraith to maintain debloat..."
"$PY" -I tools/tv.py "pm disable-user --user 0 com.google.android.tungsten.setupwraith"

echo "==> Cast credential ritual complete! You can now cast to this Chromecast."
