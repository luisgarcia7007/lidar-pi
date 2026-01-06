#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

WEB_PORT="${WEB_PORT:-8000}"
LIDAR_WEB_HOST="${LIDAR_WEB_HOST:-$(hostname -I | awk '{print $1}')}"

echo "Serving $ROOT on port $WEB_PORT"
echo "Open: http://$LIDAR_WEB_HOST:$WEB_PORT/viewer.html"
echo "Stop with Ctrl+C."
echo

exec python3 -m http.server "$WEB_PORT"

