#!/usr/bin/env bash
set -euo pipefail

# Stop recording (Ctrl+C to record_session.sh) and resume live WS server.
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

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "No tmux session '$SESSION'."
  exit 1
fi

# Stop recording
tmux send-keys -t "$SESSION:rec" C-c

# Resume live WS server
tmux send-keys -t "$SESSION:ws" C-c
tmux send-keys -t "$SESSION:ws" 'source scripts/00_env.sh 2>/dev/null || true; ./scripts/4_start_lidar_server.sh' C-m

echo "Recording stopped; live LiDAR WS resumed (session=$SESSION)."

