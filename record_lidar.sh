#!/usr/bin/env bash
set -euo pipefail

# Records Unitree L2 LiDAR frames to a timestamped log file.
# Stop with Ctrl+C. Re-run to create a new log file.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

WS_PORT="${WS_PORT:-8765}"
UDP_HOST="${UDP_HOST:-0.0.0.0}"
UDP_PORT="${UDP_PORT:-6201}"
UDP_FORMAT="${UDP_FORMAT:-auto}"

LOG_DIR="${LOG_DIR:-$PROJECT_DIR/logs}"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/lidar_${STAMP}.jsonl"

echo "Recording LiDAR to: $LOG_FILE"
echo "WebSocket: ws://0.0.0.0:${WS_PORT}  UDP: ${UDP_HOST}:${UDP_PORT}  format=${UDP_FORMAT}"
echo "Stop with Ctrl+C."
echo

exec python3 "$PROJECT_DIR/lidar_server.py" \
  --ws-port "$WS_PORT" \
  --mode udp \
  --udp-host "$UDP_HOST" \
  --udp-port "$UDP_PORT" \
  --udp-format "$UDP_FORMAT" \
  --log "$LOG_FILE"

