#!/usr/bin/env bash
set -euo pipefail

# Records BLE beacon advertisements (RSSI + optional iBeacon fields) to JSONL.
# Stop with Ctrl+C. Re-run to create a new log file.
#
# Environment overrides:
#   LOG_DIR=/home/pi/lidar_web/logs
#   BEACON_MAC=AA:BB:CC:DD:EE:FF
#   BEACON_NAME=BC021
#   BEACON_UUID=74278bda-b644-4520-8f0c-720eaf059935
#   BEACON_ADAPTER=hci0
#   BEACON_N=2.0

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

LOG_DIR="${LOG_DIR:-$PROJECT_DIR/logs}"
mkdir -p "$LOG_DIR"

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT="$LOG_DIR/beacon_${STAMP}.jsonl"

BEACON_MAC="${BEACON_MAC:-}"
BEACON_NAME="${BEACON_NAME:-}"
BEACON_UUID="${BEACON_UUID:-}"
BEACON_ADAPTER="${BEACON_ADAPTER:-}"
BEACON_N="${BEACON_N:-2.0}"

args=(--out "$OUT" --n "$BEACON_N")
if [[ -n "$BEACON_MAC" ]]; then args+=(--mac "$BEACON_MAC"); fi
if [[ -n "$BEACON_NAME" ]]; then args+=(--name "$BEACON_NAME"); fi
if [[ -n "$BEACON_UUID" ]]; then args+=(--ibeacon-uuid "$BEACON_UUID"); fi
if [[ -n "$BEACON_ADAPTER" ]]; then args+=(--adapter "$BEACON_ADAPTER"); fi

echo "Recording beacon to: $OUT"
echo "Stop with Ctrl+C."
echo

exec python3 "$PROJECT_DIR/beacon_logger.py" "${args[@]}"

