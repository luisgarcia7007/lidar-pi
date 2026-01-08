#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UDP_HOST="${UDP_HOST:-0.0.0.0}"
UDP_PORT="${UDP_PORT:-6201}"
UDP_FORMAT="${UDP_FORMAT:-auto}"
WS_PORT="${WS_PORT:-8765}"

if [[ "${UNITREE_PRIME_SECONDS:-6}" -gt 0 ]]; then
  # Prime Unitree LiDAR stream if the SDK example exists.
  "$ROOT/scripts/0_prime_unitree_lidar.sh" || true
fi

echo "Starting lidar_server.py (WS port $WS_PORT) reading UDP $UDP_HOST:$UDP_PORT (format=$UDP_FORMAT)"
echo "Stop with Ctrl+C."
echo

exec python3 "$ROOT/lidar_server.py" \
  --ws-port "$WS_PORT" \
  --mode udp \
  --udp-host "$UDP_HOST" \
  --udp-port "$UDP_PORT" \
  --udp-format "$UDP_FORMAT"

