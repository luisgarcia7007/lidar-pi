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

exec "$ROOT/start_camera_stream.sh"

