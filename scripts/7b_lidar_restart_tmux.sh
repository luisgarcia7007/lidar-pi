#!/usr/bin/env bash
set -euo pipefail

# Convenience wrapper: hard-reset the tmux live setup session.
# Equivalent to:
#   RESET=1 ./scripts/7_lidar_setup_tmux.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

exec env RESET=1 "$ROOT/scripts/7_lidar_setup_tmux.sh"

