#!/usr/bin/env bash
set -euo pipefail

# Start recording in tmux, stopping the live WS server first.
# - stops ws window (if present) via Ctrl+C
# - starts record_session.sh in window: rec
# - attaches to the session
#
# Controls:
#   SESSION=lidar
#   RECORD_CAMERA=0|1   # forwarded to record_session.sh (default 0)
#   RESET_REC=1         # kill existing rec window before starting

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SESSION="${SESSION:-lidar}"
RESET_REC="${RESET_REC:-0}"
RECORD_CAMERA="${RECORD_CAMERA:-0}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed. Install: sudo apt-get install -y tmux"
  exit 1
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "No tmux session '$SESSION' found. Run: ./scripts/7_lidar_setup_tmux.sh"
  exit 1
fi

# Stop live WS server if window exists
if tmux list-windows -t "$SESSION" -F '#W' | grep -qx 'ws'; then
  tmux send-keys -t "$SESSION:ws" C-c
fi

if [[ "$RESET_REC" == "1" ]]; then
  tmux kill-window -t "$SESSION:rec" >/dev/null 2>&1 || true
fi

if ! tmux list-windows -t "$SESSION" -F '#W' | grep -qx 'rec'; then
  tmux new-window -t "$SESSION" -c "$ROOT" -n rec
fi

tmux send-keys -t "$SESSION:rec" "source scripts/00_env.sh 2>/dev/null || true; RECORD_CAMERA=${RECORD_CAMERA} ./record_session.sh" C-m
tmux select-window -t "$SESSION:rec"
tmux attach -t "$SESSION"

