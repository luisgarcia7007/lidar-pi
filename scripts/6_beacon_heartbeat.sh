#!/usr/bin/env bash
set -euo pipefail

# Show whether beacon logging is "alive" by printing line count + last line.
# Usage:
#   ./scripts/6_beacon_heartbeat.sh logs/beacon_*.jsonl
#
# If no args are provided, it uses logs/beacon_*.jsonl

pattern="${1:-logs/beacon_*.jsonl}"

shopt -s nullglob
files=( $pattern )
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files match: $pattern"
  exit 1
fi

# pick newest by mtime
latest="${files[0]}"
for f in "${files[@]}"; do
  if [[ "$f" -nt "$latest" ]]; then latest="$f"; fi
done

echo "File: $latest"
echo "Lines: $(wc -l <"$latest" | tr -d ' ')"
echo "Last:"
tail -n 1 "$latest"

