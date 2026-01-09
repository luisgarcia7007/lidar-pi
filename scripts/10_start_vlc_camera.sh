#!/usr/bin/env bash
set -euo pipefail

# Launch VLC to preview the rover camera (V4L2).
#
# Uses env vars from scripts/00_env.sh when present:
#   CAMERA_DEV=/dev/video0
#   CAMERA_SIZE=1280x720
#   CAMERA_FPS=30
#   CAMERA_INPUT_FORMAT=mjpeg   (used to set VLC chroma to MJPG by default)
#
# Optional overrides:
#   VLC_CHROMA=MJPG
#   VLC_WIDTH=1280
#   VLC_HEIGHT=720
#   VLC_FPS=30
#
# Notes:
# - Requires a GUI session (DISPLAY set) to open VLC window.
# - Run this on the Pi when a monitor is attached, or via remote desktop.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v vlc >/dev/null 2>&1; then
  echo "VLC not found. Install: sudo apt-get install -y vlc"
  exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
  echo "No DISPLAY found; cannot open VLC window."
  exit 1
fi

CAMERA_DEV="${CAMERA_DEV:-/dev/video0}"
CAMERA_SIZE="${CAMERA_SIZE:-1280x720}"
CAMERA_FPS="${CAMERA_FPS:-30}"
CAMERA_INPUT_FORMAT="${CAMERA_INPUT_FORMAT:-mjpeg}"

VLC_CHROMA="${VLC_CHROMA:-}"
VLC_WIDTH="${VLC_WIDTH:-}"
VLC_HEIGHT="${VLC_HEIGHT:-}"
VLC_FPS="${VLC_FPS:-}"

if [[ -z "$VLC_WIDTH" || -z "$VLC_HEIGHT" ]]; then
  if [[ "$CAMERA_SIZE" =~ ^([0-9]+)x([0-9]+)$ ]]; then
    VLC_WIDTH="${VLC_WIDTH:-${BASH_REMATCH[1]}}"
    VLC_HEIGHT="${VLC_HEIGHT:-${BASH_REMATCH[2]}}"
  else
    VLC_WIDTH="${VLC_WIDTH:-1280}"
    VLC_HEIGHT="${VLC_HEIGHT:-720}"
  fi
fi

VLC_FPS="${VLC_FPS:-$CAMERA_FPS}"

if [[ -z "$VLC_CHROMA" ]]; then
  # VLC expects "MJPG" for MJPEG. If camera input is not mjpeg, let VLC decide.
  if [[ "${CAMERA_INPUT_FORMAT,,}" == "mjpeg" ]]; then
    VLC_CHROMA="MJPG"
  fi
fi

uri="v4l2://${CAMERA_DEV}"
opts=()
if [[ -n "$VLC_CHROMA" ]]; then
  opts+=("chroma=${VLC_CHROMA}")
fi
opts+=("width=${VLC_WIDTH}" "height=${VLC_HEIGHT}" "fps=${VLC_FPS}")

echo "Starting VLC camera preview:"
echo "  device: $CAMERA_DEV"
echo "  size:   ${VLC_WIDTH}x${VLC_HEIGHT}"
echo "  fps:    ${VLC_FPS}"
echo "  chroma: ${VLC_CHROMA:-<auto>}"
echo

exec vlc "${uri}:$(IFS=:; echo "${opts[*]}")"

