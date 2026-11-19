#!/usr/bin/env bash
# Bring your worker branch up to date with main (and renumber your version if main moved on).
# Run it in YOUR worker folder with everything committed:   bash tools/sync-main.sh
# Safe: it only merges main INTO your branch; main is never touched. A conflict outside the version/changelog/hand-off
# notes aborts and changes nothing.
set -eu
cd "$(dirname "$0")/.."
exec python3 -I tools/sync_main.py "$@"
