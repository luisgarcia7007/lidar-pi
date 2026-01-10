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
# - We intentionally *tolerate* failures so normal workflows still run, but we
#   now print a short warning when priming clearly didn't succeed.

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
tmp="${TMPDIR:-/tmp}/unitree_prime_${$}.log"
set +e
# Use SIGINT (like Ctrl+C) instead of SIGTERM so behavior matches manual priming.
# Some devices behave better with an INT-style stop.
timeout --signal=INT --kill-after=2s "${UNITREE_PRIME_SECONDS}s" "$UNITREE_EXAMPLE" >"$tmp" 2>&1
rc=$?
set -e

ok=0
if grep -q "A Cloud msg is parsed" "$tmp" 2>/dev/null; then
  ok=1
fi

if [[ $ok -eq 1 ]]; then
  echo "Unitree prime: OK (cloud parsed)"
  rm -f "$tmp" >/dev/null 2>&1 || true
  exit 0
fi

# timeout returns 124 when it kills the process (expected).
if [[ $rc -ne 0 && $rc -ne 124 ]]; then
  echo "Unitree prime: example exited with code $rc (continuing anyway)"
fi

if grep -q "bind udp port failed" "$tmp" 2>/dev/null; then
  echo "Unitree prime: WARNING - example couldn't bind UDP port (port already in use?)"
elif grep -q "Unilidar initialization failed" "$tmp" 2>/dev/null; then
  echo "Unitree prime: WARNING - example initialization failed"
else
  echo "Unitree prime: WARNING - no cloud parsed during prime window"
fi

echo "Unitree prime: last lines:"
tail -n 6 "$tmp" 2>/dev/null || true
rm -f "$tmp" >/dev/null 2>&1 || true

