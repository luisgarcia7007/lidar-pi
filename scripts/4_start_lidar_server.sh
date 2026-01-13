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

PYTHON_BIN="python3"
# If the user uses pyenv, tmux/non-interactive shells may not load it.
# Prefer the pyenv shim explicitly when present so dependencies match.
if [[ -x "$HOME/.pyenv/shims/python3" ]]; then
  PYTHON_BIN="$HOME/.pyenv/shims/python3"
fi

echo "Starting lidar_server.py (WS port $WS_PORT) reading UDP $UDP_HOST:$UDP_PORT (format=$UDP_FORMAT)"
echo "Stop with Ctrl+C."
echo

exec "$PYTHON_BIN" "$ROOT/lidar_server.py" \
  --ws-port "$WS_PORT" \
  --mode udp \
  --udp-host "$UDP_HOST" \
  --udp-port "$UDP_PORT" \
  --udp-format "$UDP_FORMAT"

