#!/usr/bin/env bash
set -euo pipefail

# Field setup: start everything needed for remote operation from a laptop.
# - Web server (viewer) on WEB_PORT
# - LiDAR websocket server on WS_PORT (with optional Unitree priming)
# - Camera stream on CAM_STREAM_PORT (MJPEG over HTTP)
#
# This is designed to be launched over SSH and to keep running via tmux.
#
# Controls (via scripts/00_env.sh or environment):
#   SESSION=field
#   WEB_PORT=8000
#   WS_PORT=8765
#   UDP_HOST=0.0.0.0
#   UDP_PORT=6201
#   UDP_FORMAT=unitree_l2_packet|auto
#   UNITREE_PRIME_SECONDS=20
#   CAMERA_DEV=/dev/video1
#   CAMERA_SIZE=424x240
#   CAMERA_FPS=10
#   CAMERA_INPUT_FORMAT=mjpeg
#   CAM_STREAM_PORT=8080
#   CAM_STREAM_PATH=/cam.mjpg
#
# After running, from the laptop:
#   Viewer: http://<pi-ip>:WEB_PORT/viewer.html
#   Camera: http://<pi-ip>:CAM_STREAM_PORT/cam.mjpg (use ffplay/VLC)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SESSION="${SESSION:-field}"
RESET="${RESET:-1}"

# Load env if present so we can print accurate URLs.
if [[ -f "$ROOT/scripts/00_env.sh" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT/scripts/00_env.sh"
fi

PI_IP="${LIDAR_WEB_HOST:-}"
if [[ -z "$PI_IP" ]]; then
  PI_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed. Installing..."
  sudo apt-get update -y && sudo apt-get install -y tmux
fi

# Ensure the tmux server is running (avoids "No such file or directory" socket errors).
tmux start-server >/dev/null 2>&1 || true

if [[ "$RESET" == "1" ]]; then
  tmux kill-session -t "$SESSION" >/dev/null 2>&1 || true
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$ROOT" -n web
  tmux new-window -t "$SESSION" -c "$ROOT" -n ws
  tmux new-window -t "$SESSION" -c "$ROOT" -n cam
  tmux new-window -t "$SESSION" -c "$ROOT" -n rec
fi

tmux send-keys -t "$SESSION:web" C-c
tmux send-keys -t "$SESSION:web" 'bash -lc "source scripts/00_env.sh 2>/dev/null || true; ./scripts/3_start_web_server.sh"' C-m

tmux send-keys -t "$SESSION:ws" C-c
tmux send-keys -t "$SESSION:ws" 'bash -lc "source scripts/00_env.sh 2>/dev/null || true; ./scripts/4_start_lidar_server.sh"' C-m

tmux send-keys -t "$SESSION:cam" C-c
tmux send-keys -t "$SESSION:cam" 'bash -lc "unset CAMERA_DEV CAMERA_SIZE CAMERA_FPS CAMERA_INPUT_FORMAT CAM_STREAM_PORT CAM_STREAM_PATH STREAM_PORT STREAM_PATH; source scripts/00_env.sh 2>/dev/null || true; ./scripts/12_start_camera_stream.sh"' C-m

echo "Field setup started in tmux session: $SESSION"
echo
echo "Attach: tmux attach -t $SESSION"
echo "Stop all: tmux kill-session -t $SESSION"
echo
echo "From laptop:"
echo "  Viewer: http://${PI_IP}:${WEB_PORT:-8000}/viewer.html"
echo "  Camera: http://${PI_IP}:${CAM_STREAM_PORT:-8080}${CAM_STREAM_PATH:-/cam.mjpg}"

