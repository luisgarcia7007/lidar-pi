#!/usr/bin/env bash
set -euo pipefail

# One-command live setup:
# - starts viewer web server (window: web)
# - starts LiDAR websocket bridge (window: ws)
# - (optional) starts VLC camera preview (separate process)
# - attaches to the tmux session
#
# Controls:
#   RESET=1        # kill existing session and recreate
#   SESSION=lidar  # tmux session name
#   START_VLC=1    # auto-launch VLC if DISPLAY is set (default 1)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SESSION="${SESSION:-lidar}"
RESET="${RESET:-0}"
START_VLC="${START_VLC:-1}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed. Install: sudo apt-get install -y tmux"
  exit 1
fi

if [[ "$RESET" == "1" ]]; then
  tmux kill-session -t "$SESSION" >/dev/null 2>&1 || true
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach -t "$SESSION"
  exit 0
fi

tmux new-session -d -s "$SESSION" -c "$ROOT" -n web
tmux send-keys -t "$SESSION:web" 'source scripts/00_env.sh 2>/dev/null || true; ./scripts/3_start_web_server.sh' C-m

tmux new-window -t "$SESSION" -c "$ROOT" -n ws
tmux send-keys -t "$SESSION:ws" 'source scripts/00_env.sh 2>/dev/null || true; ./scripts/4_start_lidar_server.sh' C-m

if [[ "$START_VLC" == "1" && -n "${DISPLAY:-}" ]]; then
  # Launch VLC camera preview in the background (do not block tmux).
  # It’s okay if this fails (e.g., VLC not installed).
  ( source scripts/00_env.sh 2>/dev/null || true; "$ROOT/scripts/10_start_vlc_camera.sh" ) >/dev/null 2>&1 &
fi

tmux select-window -t "$SESSION:web"
tmux attach -t "$SESSION"

