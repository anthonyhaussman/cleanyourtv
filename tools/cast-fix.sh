#!/usr/bin/env bash
# tools/cast-fix.sh - Reload Google Cast credentials after setupwraith disablement
# Compatible with Linux and macOS. Verified with shellcheck.

set -euo pipefail

TV_HOST="${TV_HOST:-${1:-192.168.1.19}}"
PORT="${PORT:-5555}"
TARGET="${TV_HOST}:${PORT}"

echo "==> Running Cast credential recovery ritual on ${TARGET}..."

# 1. Temporarily re-enable setupwraith
echo "==> Re-enabling setupwraith for credential provision..."
adb -s "${TARGET}" shell "pm enable com.google.android.tungsten.setupwraith"

# 2. Force stop mediashell so framework restarts it with fresh credentials
echo "==> Cycling Cast receiver (mediashell)..."
adb -s "${TARGET}" shell "am force-stop com.google.android.apps.mediashell"

# 3. Wait for Cast certificate handshake to complete
echo "==> Waiting 15 seconds for credentials to register in RAM..."
sleep 15

# 4. Disable setupwraith again
echo "==> Disabling setupwraith to maintain debloat..."
adb -s "${TARGET}" shell "pm disable-user --user 0 com.google.android.tungsten.setupwraith"

echo "==> Cast credential ritual complete! You can now cast to this Chromecast."
