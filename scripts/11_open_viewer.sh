#!/usr/bin/env bash
set -euo pipefail

# Open the LiDAR viewer in the desktop browser (if a GUI is available).
# This is meant for "Pi on a monitor" field use.
#
# Controls (via scripts/00_env.sh):
#   LIDAR_WEB_HOST=127.0.0.1 (optional; defaults to 127.0.0.1)
#   WEB_PORT=8000
#   VIEWER_PAGE=viewer.html
#
# Notes:
# - Requires DISPLAY (GUI session).
# - Uses xdg-open if available; otherwise tries chromium-browser/chromium.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ -z "${DISPLAY:-}" ]]; then
  echo "No DISPLAY found; not opening a browser."
  exit 0
fi

WEB_PORT="${WEB_PORT:-8000}"
LIDAR_WEB_HOST="${LIDAR_WEB_HOST:-127.0.0.1}"
VIEWER_PAGE="${VIEWER_PAGE:-viewer.html}"

url="http://${LIDAR_WEB_HOST}:${WEB_PORT}/${VIEWER_PAGE}"

echo "Opening viewer: $url"

if command -v xdg-open >/dev/null 2>&1; then
  exec xdg-open "$url"
fi

if command -v chromium-browser >/dev/null 2>&1; then
  exec chromium-browser "$url"
fi

if command -v chromium >/dev/null 2>&1; then
  exec chromium "$url"
fi

echo "No browser opener found (xdg-open/chromium)."
exit 1

