#!/usr/bin/env bash
# Optional: copy to scripts/00_env.sh and edit for your setup.

# Your Pi's LAN IP (used only for printing URLs)
export LIDAR_WEB_HOST="${LIDAR_WEB_HOST:-192.168.1.205}"

# Viewer web server port
export WEB_PORT="${WEB_PORT:-8000}"

# WebSocket port (lidar_server.py)
export WS_PORT="${WS_PORT:-8765}"

# LiDAR UDP port (Unitree example / your LiDAR sender)
export UDP_PORT="${UDP_PORT:-6201}"

# Unitree priming (runs example_lidar_udp briefly before starting lidar_server.py)
# Set to 0 to disable.
export UNITREE_PRIME_SECONDS="${UNITREE_PRIME_SECONDS:-6}"

# Auto-launch VLC camera preview when running scripts/7_lidar_setup_tmux.sh (only if DISPLAY is set)
export START_VLC="${START_VLC:-1}"

# Auto-open the viewer page in the desktop browser when running scripts/7_lidar_setup_tmux.sh
export OPEN_VIEWER="${OPEN_VIEWER:-1}"

# Camera device (USB camera capture node)
export CAMERA_DEV="${CAMERA_DEV:-/dev/video1}"
export CAMERA_SIZE="${CAMERA_SIZE:-424x240}"
export CAMERA_FPS="${CAMERA_FPS:-10}"
export CAMERA_INPUT_FORMAT="${CAMERA_INPUT_FORMAT:-mjpeg}"

# Camera stream (for viewing video on your laptop/phone over Wi‑Fi)
export CAM_STREAM_PORT="${CAM_STREAM_PORT:-8080}"
export CAM_STREAM_PATH="${CAM_STREAM_PATH:-/cam.mjpg}"

# Recording: keep camera off by default for field driving (VLC/ffplay uses the stream)
export RECORD_CAMERA="${RECORD_CAMERA:-0}"

# Optional VLC overrides (otherwise derived from CAMERA_* above)
# export VLC_CHROMA="MJPG"
# export VLC_WIDTH=1280
# export VLC_HEIGHT=720
# export VLC_FPS=30

# Beacon filter (pick ONE; leave others empty)
export BEACON_MAC="${BEACON_MAC:-dd:88:00:00:0a:bf}"
export BEACON_NAME="${BEACON_NAME:-}"
export BEACON_UUID="${BEACON_UUID:-}"
export BEACON_ADAPTER="${BEACON_ADAPTER:-}"
export BEACON_N="${BEACON_N:-2.0}"

