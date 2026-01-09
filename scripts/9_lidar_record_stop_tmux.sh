#!/usr/bin/env bash
set -euo pipefail

# Stop recording in tmux (graceful Ctrl+C to record_session.sh).
#
# Controls:
#   SESSION=lidar
#   RESUME_LIVE=1   # restart the live WS server after stopping recording

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SESSION="${SESSION:-lidar}"
RESUME_LIVE="${RESUME_LIVE:-1}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed. Install: sudo apt-get install -y tmux"
  exit 1
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "No tmux session '$SESSION' found."
  exit 1
fi

if tmux list-windows -t "$SESSION" -F '#W' | grep -qx 'rec'; then
  tmux send-keys -t "$SESSION:rec" C-c
else
  echo "No 'rec' window found; nothing to stop."
fi

if [[ "$RESUME_LIVE" == "1" ]]; then
  # Ensure ws window exists and restart the server there.
  if ! tmux list-windows -t "$SESSION" -F '#W' | grep -qx 'ws'; then
    tmux new-window -t "$SESSION" -c "$ROOT" -n ws
  fi
  tmux send-keys -t "$SESSION:ws" C-c
  tmux send-keys -t "$SESSION:ws" 'source scripts/00_env.sh 2>/dev/null || true; ./scripts/4_start_lidar_server.sh' C-m
fi

tmux attach -t "$SESSION"

