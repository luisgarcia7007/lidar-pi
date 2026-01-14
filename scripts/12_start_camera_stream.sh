#!/usr/bin/env bash
set -euo pipefail

# Start the MJPEG camera HTTP stream (works over SSH; no GUI needed).
#
# Uses env vars from scripts/00_env.sh when present:
#   CAMERA_DEV, CAMERA_SIZE, CAMERA_FPS, CAMERA_INPUT_FORMAT
#   CAM_STREAM_PORT (defaults to 8080)
#   CAM_STREAM_PATH (defaults to /cam.mjpg)
#
# Then view from your laptop:
#   http://<pi-ip>:8080/cam.mjpg

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CAM_STREAM_PORT="${CAM_STREAM_PORT:-8080}"
CAM_STREAM_PATH="${CAM_STREAM_PATH:-/cam.mjpg}"

export STREAM_PORT="$CAM_STREAM_PORT"
export STREAM_PATH="$CAM_STREAM_PATH"

# Forward camera settings explicitly (avoids stale tmux env / default fallback).
export CAMERA_DEV="${CAMERA_DEV:-/dev/video0}"
export CAMERA_SIZE="${CAMERA_SIZE:-320x180}"
export CAMERA_FPS="${CAMERA_FPS:-10}"
export CAMERA_INPUT_FORMAT="${CAMERA_INPUT_FORMAT:-mjpeg}"

# If the preferred device node doesn't exist (USB cameras can re-enumerate),
# fall back to the first available /dev/video{0..9}.
if [[ ! -e "$CAMERA_DEV" ]]; then
  for d in /dev/video{0..9}; do
    if [[ -e "$d" ]]; then
      echo "Camera device '$CAMERA_DEV' not found; falling back to '$d'"
      export CAMERA_DEV="$d"
      break
    fi
  done
fi

exec "$ROOT/start_camera_stream.sh"

