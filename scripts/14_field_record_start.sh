#!/usr/bin/env bash
set -euo pipefail

# Start recording (LiDAR + beacon; camera recording disabled by default).
# Intended to be run after scripts/13_field_setup.sh.
#
# Controls:
#   SESSION=field
#   RECORD_CAMERA=0|1   (default 0)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SESSION="${SESSION:-field}"
RECORD_CAMERA="${RECORD_CAMERA:-0}"

if ! command -v tmux >/dev/null 2>&1; then
  echo "tmux not installed."
  exit 1
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "No tmux session '$SESSION'. Run: ./scripts/13_field_setup.sh"
  exit 1
fi

# Stop the live WS server to avoid port conflicts with record_session.sh
tmux send-keys -t "$SESSION:ws" C-c

# Start recording in the rec window
tmux send-keys -t "$SESSION:rec" C-c
tmux send-keys -t "$SESSION:rec" "source scripts/00_env.sh 2>/dev/null || true; RECORD_CAMERA=${RECORD_CAMERA} ./record_session.sh" C-m

echo "Recording started (session=$SESSION, RECORD_CAMERA=$RECORD_CAMERA)."
echo "Stop with: ./scripts/15_field_record_stop.sh"

