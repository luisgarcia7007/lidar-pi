# Streamlined startup/recording protocol

This repo can be run either with full manual commands or with helper scripts under `scripts/`.

## One-time setup

1) (Optional) Create your local env file:

```bash
cd ~/lidar_web
cp scripts/00_env_example.sh scripts/00_env.sh
nano scripts/00_env.sh
```

2) Make scripts executable:

```bash
cd ~/lidar_web
chmod +x scripts/*.sh
```

## Recommended daily workflow (minimal typing)

### A) Quick hardware checks (optional but recommended)

Load your env (if you created it):

```bash
source scripts/00_env.sh 2>/dev/null || true
```

Camera:

```bash
./scripts/1_confirm_camera.sh
```

Beacon:

```bash
./scripts/2_confirm_beacon.sh
```

### B) Live viewing (LiDAR in browser, video in VLC)

#### One-command (tmux) option

If you have `tmux` installed, you can start the web server + LiDAR WS server with one command:

```bash
cd ~/lidar_web
./scripts/7_lidar_setup_tmux.sh
```

(Detach and leave running: `Ctrl+b`, then `d`. Re-attach: re-run the same command.)

Tip: if you ever suspect the session got "stale", restart the tmux commands with:

```bash
cd ~/lidar_web
RESTART=1 ./scripts/7_lidar_setup_tmux.sh
```

#### Manual option

Terminal 1:

```bash
cd ~/lidar_web
source scripts/00_env.sh 2>/dev/null || true
./scripts/3_start_web_server.sh
```

Open the printed `http://<ip>:8000/viewer.html` in your browser.

Terminal 2 (LiDAR WS server for the viewer):

```bash
cd ~/lidar_web
source scripts/00_env.sh 2>/dev/null || true
./scripts/4_start_lidar_server.sh
```

Note: `./scripts/4_start_lidar_server.sh` will automatically "prime" some Unitree LiDARs by running
the SDK `example_lidar_udp` briefly first (configurable via `UNITREE_PRIME_SECONDS` in `scripts/00_env.sh`).

Camera (VLC):

```bash
vlc "v4l2://${CAMERA_DEV:-/dev/video0}:chroma=MJPG:width=1280:height=720:fps=30"
```

### C) Recording a session (LiDAR + optional beacon + optional camera)

#### Two-command (tmux) option

1) Setup live (web + WS): `./scripts/7_lidar_setup_tmux.sh`
2) Start recording: `./scripts/8_lidar_record_start_tmux.sh`
3) Stop recording: `./scripts/9_lidar_record_stop_tmux.sh`

Stop the live LiDAR server if it’s running (Ctrl+C in terminal 2), then:

```bash
cd ~/lidar_web
source scripts/00_env.sh 2>/dev/null || true
./scripts/5_start_recording.sh
```

Beacon “heartbeat” during recording (in another terminal):

```bash
cd ~/lidar_web
./scripts/6_beacon_heartbeat.sh
```

Re-run `./scripts/6_beacon_heartbeat.sh` whenever you want to confirm it’s still writing.

