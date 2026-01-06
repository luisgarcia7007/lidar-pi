#!/usr/bin/env bash
set -euo pipefail

# Quick beacon sanity check:
# runs beacon_logger.py briefly with your filter and confirms >0 lines.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p logs

DURATION="${DURATION:-10}"
OUT="${OUT:-logs/beacon_check.jsonl}"

BEACON_MAC="${BEACON_MAC:-}"
BEACON_NAME="${BEACON_NAME:-}"
BEACON_UUID="${BEACON_UUID:-}"
BEACON_ADAPTER="${BEACON_ADAPTER:-}"
BEACON_N="${BEACON_N:-2.0}"

args=(--out "$OUT" --duration "$DURATION" --n "$BEACON_N")
if [[ -n "$BEACON_MAC" ]]; then args+=(--mac "$BEACON_MAC"); fi
if [[ -n "$BEACON_NAME" ]]; then args+=(--name "$BEACON_NAME"); fi
if [[ -n "$BEACON_UUID" ]]; then args+=(--ibeacon-uuid "$BEACON_UUID"); fi
if [[ -n "$BEACON_ADAPTER" ]]; then args+=(--adapter "$BEACON_ADAPTER"); fi

echo "### Beacon check (duration=${DURATION}s)"
echo "Output: $OUT"
echo "Filter: mac=${BEACON_MAC:-<none>} name=${BEACON_NAME:-<none>} uuid=${BEACON_UUID:-<none>} adapter=${BEACON_ADAPTER:-<none>}"
echo

python3 "$ROOT/beacon_logger.py" "${args[@]}"

lines="$(wc -l <"$OUT" | tr -d ' ')"
echo
echo "### Result"
echo "Lines written: $lines"
if [[ "$lines" -eq 0 ]]; then
  echo "FAIL: no beacon records captured."
  exit 2
fi
echo "Last record:"
tail -n 1 "$OUT"

