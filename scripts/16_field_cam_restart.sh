#!/usr/bin/env bash
set -euo pipefail

# Restart the camera stream window inside the field tmux session.
# Useful for "video froze" recovery with minimal typing.
#
# Usage:
#   ./scripts/16_field_cam_restart.sh
#
# Controls:
#   SESSION=field

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SESSION="${SESSION:-field}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed."
  exit 1
fi

tmux start-server >/dev/null 2>&1 || true

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "No tmux session '$SESSION'. Run: ./scripts/13_field_setup.sh"
  exit 1
fi

# Kill existing cam window (if any), then recreate with a clean env.
tmux kill-window -t "$SESSION:cam" >/dev/null 2>&1 || true
tmux new-window -t "$SESSION" -n cam -c "$ROOT" \
  'bash -lc "unset CAMERA_DEV CAMERA_SIZE CAMERA_FPS CAMERA_INPUT_FORMAT CAM_STREAM_PORT CAM_STREAM_PATH STREAM_PORT STREAM_PATH; source scripts/00_env.sh 2>/dev/null || true; ./scripts/12_start_camera_stream.sh"'

echo "Camera stream restarted in tmux session '$SESSION' (window: cam)."

