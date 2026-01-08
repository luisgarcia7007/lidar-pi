#!/usr/bin/env bash
set -euo pipefail

# Record a synchronized session:
#  - LiDAR frames (JSONL) via lidar_server.py --log
#  - (Optional) Camera video (MKV) via ffmpeg (V4L2)
#
# Stop with Ctrl+C. A session meta JSON is written with start/stop timestamps.
#
# Environment overrides:
#   WS_PORT=8765
#   UDP_HOST=0.0.0.0
#   UDP_PORT=6201
#   UDP_FORMAT=auto
#   LOG_DIR=/home/pi/lidar_web/logs
#   RECORD_CAMERA=0           # 0=don't record camera (lets VLC use it), 1=record camera
#   CAMERA_DEV=/dev/video0
#   CAMERA_SIZE=1920x1080
#   CAMERA_FPS=5
#   CAMERA_INPUT_FORMAT=mjpeg
#   CAMERA_CODEC=libx264
#   CAMERA_CRF=23
#   BEACON_MAC=AA:BB:CC:DD:EE:FF
#   BEACON_NAME=BC021
#   BEACON_UUID=74278bda-b644-4520-8f0c-720eaf059935
#   BEACON_ADAPTER=hci0
#   BEACON_N=2.0

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# Load optional defaults (do not override environment variables).
if [[ -f "$PROJECT_DIR/session_defaults.sh" ]]; then
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/session_defaults.sh"
fi

WS_PORT="${WS_PORT:-8765}"
UDP_HOST="${UDP_HOST:-0.0.0.0}"
UDP_PORT="${UDP_PORT:-6201}"
UDP_FORMAT="${UDP_FORMAT:-auto}"

LOG_DIR="${LOG_DIR:-$PROJECT_DIR/logs}"
mkdir -p "$LOG_DIR"

RECORD_CAMERA="${RECORD_CAMERA:-0}"

CAMERA_DEV="${CAMERA_DEV:-/dev/video0}"
CAMERA_SIZE="${CAMERA_SIZE:-1920x1080}"
CAMERA_FPS="${CAMERA_FPS:-5}"
CAMERA_INPUT_FORMAT="${CAMERA_INPUT_FORMAT:-mjpeg}"
CAMERA_CODEC="${CAMERA_CODEC:-libx264}"
CAMERA_CRF="${CAMERA_CRF:-23}"

BEACON_MAC="${BEACON_MAC:-}"
BEACON_NAME="${BEACON_NAME:-}"
BEACON_UUID="${BEACON_UUID:-}"
BEACON_ADAPTER="${BEACON_ADAPTER:-}"
BEACON_N="${BEACON_N:-2.0}"

STAMP="$(date +%Y%m%d_%H%M%S)"
LIDAR_LOG="$LOG_DIR/lidar_${STAMP}.jsonl"
VIDEO_OUT="$LOG_DIR/video_${STAMP}.mkv"
BEACON_OUT="$LOG_DIR/beacon_${STAMP}.jsonl"
META_OUT="$LOG_DIR/session_${STAMP}.json"
LIDAR_STDLOG="$LOG_DIR/lidar_server_${STAMP}.log"
CAMERA_STDLOG="$LOG_DIR/camera_${STAMP}.log"
BEACON_STDLOG="$LOG_DIR/beacon_${STAMP}.log"

start_unix_ns="$(python3 - <<'PY'
import time
print(time.time_ns())
PY
)"

echo "Session: $STAMP"
echo "LiDAR log:  $LIDAR_LOG"
if [[ "$RECORD_CAMERA" == "1" ]]; then
  echo "Video out:  $VIDEO_OUT"
else
  echo "Video out:  (disabled; set RECORD_CAMERA=1 to enable)"
fi
if [[ -n "$BEACON_MAC" || -n "$BEACON_NAME" || -n "$BEACON_UUID" ]]; then
  echo "Beacon out: $BEACON_OUT"
fi
echo "Meta:       $META_OUT"
echo "Logs:       $LIDAR_STDLOG  $CAMERA_STDLOG  $BEACON_STDLOG"
echo
echo "Starting LiDAR server (logs even without browser)..."
lidar_args=(
  --ws-port "$WS_PORT"
  --mode udp
  --udp-host "$UDP_HOST"
  --udp-port "$UDP_PORT"
  --udp-format "$UDP_FORMAT"
  --log "$LIDAR_LOG"
)

if [[ -n "$BEACON_MAC" || -n "$BEACON_NAME" || -n "$BEACON_UUID" ]]; then
  # beacon_logger writes JSONL to $BEACON_OUT; lidar_server will tail it and attach latest to WS messages.
  lidar_args+=(--beacon-log "$BEACON_OUT")
fi

python3 "$PROJECT_DIR/lidar_server.py" \
  "${lidar_args[@]}" \
  >"$LIDAR_STDLOG" 2>&1 &
LIDAR_PID=$!

CAMERA_PID=""
if [[ "$RECORD_CAMERA" == "1" ]]; then
  echo "Starting camera capture (V4L2)..."
  ffmpeg -hide_banner -loglevel warning -nostdin -y \
    -f v4l2 -input_format "$CAMERA_INPUT_FORMAT" -framerate "$CAMERA_FPS" -video_size "$CAMERA_SIZE" -i "$CAMERA_DEV" \
    -use_wallclock_as_timestamps 1 \
    -c:v "$CAMERA_CODEC" -preset veryfast -crf "$CAMERA_CRF" \
    -f matroska "$VIDEO_OUT" \
    >"$CAMERA_STDLOG" 2>&1 &
  CAMERA_PID=$!
else
  echo "Camera recording disabled (RECORD_CAMERA=0)."
fi

BEACON_PID=""
if [[ -n "$BEACON_MAC" || -n "$BEACON_NAME" || -n "$BEACON_UUID" ]]; then
  echo "Starting beacon scan logger (BLE)..."
  args=(--out "$BEACON_OUT" --n "$BEACON_N")
  if [[ -n "$BEACON_MAC" ]]; then args+=(--mac "$BEACON_MAC"); fi
  if [[ -n "$BEACON_NAME" ]]; then args+=(--name "$BEACON_NAME"); fi
  if [[ -n "$BEACON_UUID" ]]; then args+=(--ibeacon-uuid "$BEACON_UUID"); fi
  if [[ -n "$BEACON_ADAPTER" ]]; then args+=(--adapter "$BEACON_ADAPTER"); fi
  python3 "$PROJECT_DIR/beacon_logger.py" "${args[@]}" >"$BEACON_STDLOG" 2>&1 &
  BEACON_PID=$!
fi

cleanup() {
  echo
  echo "Stopping session..."
  stop_unix_ns="$(python3 - <<'PY'
import time
print(time.time_ns())
PY
)"

  # Stop children
  if [[ -n "$CAMERA_PID" ]]; then
    kill "$CAMERA_PID" >/dev/null 2>&1 || true
  fi
  kill "$LIDAR_PID" >/dev/null 2>&1 || true
  if [[ -n "$BEACON_PID" ]]; then
    kill "$BEACON_PID" >/dev/null 2>&1 || true
  fi

  # Wait a moment for flush
  if [[ -n "$CAMERA_PID" ]]; then
    wait "$CAMERA_PID" >/dev/null 2>&1 || true
  fi
  wait "$LIDAR_PID" >/dev/null 2>&1 || true
  if [[ -n "$BEACON_PID" ]]; then
    wait "$BEACON_PID" >/dev/null 2>&1 || true
  fi

  python3 - <<PY
import json
meta = {
  "session": "$STAMP",
  "start_unix_ns": int("$start_unix_ns"),
  "stop_unix_ns": int("$stop_unix_ns"),
  "lidar_log": "$LIDAR_LOG",
  "video_out": "$VIDEO_OUT" if "$RECORD_CAMERA" == "1" else None,
  "beacon_out": "$BEACON_OUT" if (${#BEACON_PID} > 0) else None,
  "ws_port": int("$WS_PORT"),
  "udp_host": "$UDP_HOST",
  "udp_port": int("$UDP_PORT"),
  "udp_format": "$UDP_FORMAT",
  "record_camera": True if "$RECORD_CAMERA" == "1" else False,
  "camera_dev": "$CAMERA_DEV" if "$RECORD_CAMERA" == "1" else None,
  "camera_size": "$CAMERA_SIZE" if "$RECORD_CAMERA" == "1" else None,
  "camera_fps": int("$CAMERA_FPS") if "$RECORD_CAMERA" == "1" else None,
  "camera_codec": "$CAMERA_CODEC" if "$RECORD_CAMERA" == "1" else None,
  "camera_crf": int("$CAMERA_CRF") if "$RECORD_CAMERA" == "1" else None,
  "beacon_mac": "$BEACON_MAC" or None,
  "beacon_name": "$BEACON_NAME" or None,
  "beacon_uuid": "$BEACON_UUID" or None,
  "beacon_adapter": "$BEACON_ADAPTER" or None,
  "beacon_n": float("$BEACON_N"),
}
with open("$META_OUT", "w", encoding="utf-8") as f:
  json.dump(meta, f, indent=2)
print("Wrote:", "$META_OUT")
PY
}

trap cleanup INT TERM

echo "Recording... press Ctrl+C to stop."
if [[ "$RECORD_CAMERA" == "1" ]]; then
  echo "(If it exits immediately, check: $CAMERA_STDLOG and $BEACON_STDLOG)"
else
  echo "(If it exits immediately, check: $LIDAR_STDLOG and $BEACON_STDLOG)"
fi
echo

# If a process dies right away, report which one.
sleep 1
if ! kill -0 "$LIDAR_PID" >/dev/null 2>&1; then
  echo "LiDAR process exited early. See: $LIDAR_STDLOG"
  cleanup
  exit 1
fi
if [[ -n "$CAMERA_PID" ]] && ! kill -0 "$CAMERA_PID" >/dev/null 2>&1; then
  echo "Camera process exited early. See: $CAMERA_STDLOG"
  cleanup
  exit 1
fi
if [[ -n "$BEACON_PID" ]] && ! kill -0 "$BEACON_PID" >/dev/null 2>&1; then
  echo "Beacon process exited early. See: $BEACON_STDLOG"
  cleanup
  exit 1
fi

# Wait until one of the processes exits (or Ctrl+C).
while kill -0 "$LIDAR_PID" >/dev/null 2>&1; do
  if [[ -n "$CAMERA_PID" ]] && ! kill -0 "$CAMERA_PID" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

cleanup

