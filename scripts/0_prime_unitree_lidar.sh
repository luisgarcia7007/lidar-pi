#!/usr/bin/env bash
set -euo pipefail

# Prime Unitree LiDAR streaming by running the SDK UDP example briefly.
# This is useful when the LiDAR won't start sending UDP until the example runs once.
#
# Controls:
#   UNITREE_PRIME_SECONDS=6   # how long to run the example
#
# Notes:
# - This must run when the LiDAR UDP port is NOT already bound by another process.
# - We intentionally ignore failures so normal workflows still run.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

UNITREE_EXAMPLE="${UNITREE_EXAMPLE:-$ROOT/external/unilidar_sdk2/unitree_lidar_sdk/bin/example_lidar_udp}"
UNITREE_PRIME_SECONDS="${UNITREE_PRIME_SECONDS:-6}"

if [[ "${UNITREE_PRIME_SECONDS}" -le 0 ]]; then
  exit 0
fi

if [[ ! -x "$UNITREE_EXAMPLE" ]]; then
  echo "Unitree prime: example not found/executable at: $UNITREE_EXAMPLE (skipping)"
  exit 0
fi

if ! command -v timeout >/dev/null 2>&1; then
  echo "Unitree prime: 'timeout' not found (skipping)"
  exit 0
fi

echo "Unitree prime: running example for ${UNITREE_PRIME_SECONDS}s..."
set +e
timeout "${UNITREE_PRIME_SECONDS}s" "$UNITREE_EXAMPLE" >/dev/null 2>&1
rc=$?
set -e

# timeout returns 124 when it kills the process (expected).
if [[ $rc -ne 0 && $rc -ne 124 ]]; then
  echo "Unitree prime: example exited with code $rc (continuing anyway)"
fi

