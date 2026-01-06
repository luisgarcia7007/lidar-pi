#!/usr/bin/env bash
set -euo pipefail

# Quick camera sanity check:
# - lists V4L2 devices
# - prints which CAMERA_DEV will be used
# - attempts a short ffmpeg probe (no output file)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Optional user overrides
CAMERA_DEV="${CAMERA_DEV:-/dev/video0}"
CAMERA_SIZE="${CAMERA_SIZE:-1280x720}"
CAMERA_FPS="${CAMERA_FPS:-30}"
CAMERA_INPUT_FORMAT="${CAMERA_INPUT_FORMAT:-mjpeg}"

echo "### Camera devices (v4l2-ctl --list-devices)"
if command -v v4l2-ctl >/dev/null 2>&1; then
  v4l2-ctl --list-devices
else
  echo "v4l2-ctl not found. Install: sudo apt-get install -y v4l-utils"
fi
echo

echo "### Using"
echo "CAMERA_DEV=$CAMERA_DEV"
echo "CAMERA_SIZE=$CAMERA_SIZE"
echo "CAMERA_FPS=$CAMERA_FPS"
echo "CAMERA_INPUT_FORMAT=$CAMERA_INPUT_FORMAT"
echo

if [[ ! -e "$CAMERA_DEV" ]]; then
  echo "ERROR: $CAMERA_DEV does not exist."
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg not found. Install: sudo apt-get install -y ffmpeg"
  exit 1
fi

echo "### Probing camera for 2 seconds (no file written)"
set +e
ffmpeg -hide_banner -loglevel warning -nostdin \
  -f v4l2 -input_format "$CAMERA_INPUT_FORMAT" -framerate "$CAMERA_FPS" -video_size "$CAMERA_SIZE" -i "$CAMERA_DEV" \
  -t 2 -f null - >/dev/null 2>&1
rc=$?
set -e
if [[ $rc -ne 0 ]]; then
  echo "Probe FAILED. Try a different /dev/videoX or size/fps/format."
  exit $rc
fi
echo "Probe OK."

