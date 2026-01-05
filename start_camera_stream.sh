#!/usr/bin/env bash
set -euo pipefail

# Start an MJPEG HTTP stream from the camera for embedding in viewer.html.
# Stop with Ctrl+C.
#
# Environment overrides:
#   CAMERA_DEV=/dev/video0
#   CAMERA_SIZE=1280x720
#   CAMERA_FPS=30
#   CAMERA_INPUT_FORMAT=mjpeg
#   STREAM_PORT=8090
#   STREAM_PATH=/cam.mjpg
#
# Then view:
#   http://<pi-ip>:8090/cam.mjpg

CAMERA_DEV="${CAMERA_DEV:-/dev/video0}"
CAMERA_SIZE="${CAMERA_SIZE:-1280x720}"
CAMERA_FPS="${CAMERA_FPS:-30}"
CAMERA_INPUT_FORMAT="${CAMERA_INPUT_FORMAT:-mjpeg}"
STREAM_PORT="${STREAM_PORT:-8090}"
STREAM_PATH="${STREAM_PATH:-/cam.mjpg}"

URL="http://0.0.0.0:${STREAM_PORT}${STREAM_PATH}"

echo "Starting MJPEG stream: $URL"
echo "Camera: $CAMERA_DEV ${CAMERA_SIZE} @ ${CAMERA_FPS}fps (${CAMERA_INPUT_FORMAT})"
echo "Stop with Ctrl+C."
echo

# ffmpeg acts as an HTTP server with -listen 1 and serves multipart MJPEG.
exec ffmpeg -hide_banner -loglevel warning -nostdin \
  -f v4l2 -input_format "$CAMERA_INPUT_FORMAT" -framerate "$CAMERA_FPS" -video_size "$CAMERA_SIZE" -i "$CAMERA_DEV" \
  -vf "scale=${CAMERA_SIZE}" \
  -f mjpeg -q:v 5 -listen 1 "$URL"

