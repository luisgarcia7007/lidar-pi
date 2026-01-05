#!/usr/bin/env bash
#
# Optional defaults for record_session.sh
# Edit this file to match your hardware.
#
# Note: environment variables still override these defaults.
#

# --- Beacon (BC021 / Blue Charm) ---
BEACON_MAC="DD:88:00:00:0A:BF"
# BEACON_NAME="BCPro_205501"
# BEACON_UUID=""
# BEACON_ADAPTER="hci0"
BEACON_N="2.0"

# --- Camera (Picam360 via /dev/video0) ---
CAMERA_DEV="/dev/video0"
CAMERA_SIZE="1920x1080"
CAMERA_FPS="30"

