#!/usr/bin/env bash
set -euo pipefail

# Wrapper around record_session.sh with a reminder banner + env defaults.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Starting recording session..."
echo
echo "Notes:"
echo "- This script will run record_session.sh (LiDAR log + optional camera + optional beacon)."
echo "- If you want to watch camera live in VLC, disable camera recording in record_session.sh or use a 2nd camera."
echo

exec "$ROOT/record_session.sh"

