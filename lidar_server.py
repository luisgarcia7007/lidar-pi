import argparse
import asyncio
import json
import socket
import time
from collections import deque
from dataclasses import dataclass
from typing import Deque, Optional, Tuple

import numpy as np
import websockets

PORT = 8765

PointArray = np.ndarray


@dataclass
class Frame:
    points: PointArray  # shape (N, 3) or (N, 4) where last column is intensity
    scale: float  # multiply XYZ by this to get meters


def _decode_points(
    payload: bytes,
    *,
    fmt: str,
    header_bytes: int = 0,
) -> Optional[Tuple[PointArray, float]]:
    """
    Decode a UDP payload into points.

    Supported formats:
      - f32xyz:  3x float32 little-endian meters
      - f32xyzi: 4x float32 little-endian meters (last=float intensity)
      - i16xyz_mm:  3x int16 little-endian millimeters
      - i16xyzi_mm: 4x int16 little-endian millimeters (last=int intensity)
      - auto: best-effort guess for the above, assuming no header or a fixed header_bytes
    """
    if header_bytes:
        if len(payload) <= header_bytes:
            return None
        payload = payload[header_bytes:]

    def try_f32(cols: int) -> Optional[Tuple[PointArray, float]]:
        if len(payload) % (4 * cols) != 0:
            return None
        arr = np.frombuffer(payload, dtype="<f4").reshape(-1, cols)
        # sanity check: finite and not absurdly large
        if not np.isfinite(arr).all():
            return None
        xyz = arr[:, :3]
        max_abs = float(np.max(np.abs(xyz))) if xyz.size else 0.0

        # Unit heuristic:
        # - If the device sends float32 in millimeters, values are commonly in the 0..50000 range.
        # - If it sends float32 in meters, values are commonly 0..200 range.
        # This is best-effort; you can always override scaling on the viewer side if needed.
        scale = 0.001 if max_abs > 500.0 else 1.0
        return arr, scale

    def try_i16(cols: int) -> Optional[Tuple[PointArray, float]]:
        if len(payload) % (2 * cols) != 0:
            return None
        arr = np.frombuffer(payload, dtype="<i2").reshape(-1, cols).astype(np.float32)
        # int16 in mm is typically within +-32768mm
        xyz_mm = arr[:, :3]
        if np.max(np.abs(xyz_mm)) > 40000:  # >40m in mm units is suspicious but allow some headroom
            return None
        return arr, 0.001

    fmt = fmt.lower()
    if fmt == "f32xyz":
        return try_f32(3)
    if fmt == "f32xyzi":
        return try_f32(4)
    if fmt == "i16xyz_mm":
        return try_i16(3)
    if fmt == "i16xyzi_mm":
        return try_i16(4)
    if fmt != "auto":
        raise ValueError(f"Unknown format: {fmt}")

    # NOTE: deeper auto-detect (with header + endianness) is implemented in
    # _decode_points_auto() so we can return the detected format and lock onto it.
    return None


def _decode_points_auto(payload: bytes) -> Optional[Tuple[PointArray, float, int, str]]:
    """
    Best-effort decode for unknown UDP payloads.

    Tries:
      - optional headers (0..64 bytes, 4-byte aligned)
      - float32 little/big endian xyz/xyzi
      - int16/uint16 little-endian xyz/xyzi (assumed millimeters)
    Returns (points, scale, header_bytes, fmt_name).
    """

    def score(arr: PointArray) -> float:
        # Prefer more points, non-trivial spread, and finite values.
        if arr.size == 0:
            return -1.0
        xyz = arr[:, :3]
        if not np.isfinite(xyz).all():
            return -1.0
        max_abs = float(np.max(np.abs(xyz)))
        if max_abs == 0.0:
            return -1.0
        # light penalty for absurdly large values (still allow; may be mm)
        penalty = 0.0
        if max_abs > 1e7:
            penalty = 1e6
        return float(arr.shape[0]) * 10.0 - penalty

    candidates = [
        ("<f4", 4, "f32xyz", 3),
        ("<f4", 4, "f32xyzi", 4),
        (">f4", 4, "f32xyz_be", 3),
        (">f4", 4, "f32xyzi_be", 4),
        ("<i2", 2, "i16xyz_mm", 3),
        ("<i2", 2, "i16xyzi_mm", 4),
        ("<u2", 2, "u16xyz_mm", 3),
        ("<u2", 2, "u16xyzi_mm", 4),
    ]

    best = None
    best_score = -1.0

    for hb in range(0, 65, 4):
        if len(payload) <= hb:
            continue
        body = payload[hb:]

        for dtype, width, name, cols in candidates:
            if len(body) % (width * cols) != 0:
                continue
            try:
                arr = np.frombuffer(body, dtype=np.dtype(dtype)).reshape(-1, cols)
            except Exception:
                continue

            # Normalize to float32 for downstream
            if arr.dtype != np.float32:
                arr = arr.astype(np.float32)

            s = score(arr)
            if s > best_score:
                # scale heuristic by type + magnitude
                xyz = arr[:, :3]
                max_abs = float(np.max(np.abs(xyz))) if xyz.size else 0.0
                if name.startswith("f32"):
                    scale = 0.001 if max_abs > 500.0 else 1.0
                else:
                    # int16/uint16 assumed mm
                    scale = 0.001
                best = (arr, scale, hb, name)
                best_score = s

    return best


def _demo_frame(num_points: int = 6000) -> Frame:
    # Demo: generate millimeters so the viewer defaults work.
    pts = np.random.uniform(-12000, 12000, size=(num_points, 3)).astype(np.float32)
    return Frame(points=pts, scale=0.001)


class UdpPointSource:
    def __init__(
        self,
        host: str,
        port: int,
        fmt: str,
        header_bytes: int,
        frame_ms: int,
        max_points: int,
    ):
        self.host = host
        self.port = port
        self.fmt = fmt
        self.header_bytes = header_bytes
        self.frame_ms = frame_ms
        self.max_points = max_points

        self._sock: Optional[socket.socket] = None
        self._buf: Deque[PointArray] = deque()
        self._last_frame_t = time.monotonic()
        self._last_scale: float = 1.0

        # stats
        self._pkts = 0
        self._decoded_pkts = 0
        self._points = 0
        self._last_stat_t = time.monotonic()

    def start(self) -> None:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind((self.host, self.port))
        sock.setblocking(False)
        self._sock = sock
        print(
            f"UDP listening on {self.host}:{self.port} (format={self.fmt}, header_bytes={self.header_bytes})"
        )

    async def read_frame(self) -> Optional[Frame]:
        """
        Accumulate UDP packets and return a merged frame every frame_ms.
        """
        if self._sock is None:
            self.start()

        assert self._sock is not None

        # Read as many datagrams as are available right now (non-blocking).
        while True:
            try:
                data, _addr = self._sock.recvfrom(65535)
            except (BlockingIOError, InterruptedError):
                break
            except Exception:
                break

            self._pkts += 1
            if self.fmt == "auto":
                auto = _decode_points_auto(data)
                if auto is None:
                    continue
                arr, scale, hb, detected = auto
                # lock onto detected format for performance
                self.fmt = detected
                self.header_bytes = hb
                self._last_scale = scale
                print(f"Auto-detected UDP point format: {detected} (header_bytes={hb}, scale={scale})")
            else:
                decoded = _decode_points(data, fmt=self.fmt, header_bytes=self.header_bytes)
                if decoded is None:
                    continue
                arr, scale = decoded
                self._last_scale = scale
            self._decoded_pkts += 1
            self._points += int(arr.shape[0])
            self._buf.append(arr)

        now = time.monotonic()
        if (now - self._last_stat_t) >= 2.0:
            pps = self._pkts / (now - self._last_stat_t)
            dps = self._decoded_pkts / (now - self._last_stat_t)
            ptsps = self._points / (now - self._last_stat_t)
            print(f"UDP stats: pkts/s={pps:.1f} decoded/s={dps:.1f} points/s={ptsps:.0f}")
            self._pkts = 0
            self._decoded_pkts = 0
            self._points = 0
            self._last_stat_t = now

        if (now - self._last_frame_t) * 1000.0 < self.frame_ms:
            return None

        self._last_frame_t = now
        if not self._buf:
            return None

        merged = np.concatenate(list(self._buf), axis=0)
        self._buf.clear()

        # Cap points to avoid blowing up the browser.
        if merged.shape[0] > self.max_points:
            idx = np.random.choice(merged.shape[0], self.max_points, replace=False)
            merged = merged[idx]

        return Frame(points=merged, scale=self._last_scale)


def _frame_to_message(frame: Frame) -> str:
    # Convert to JSON-friendly lists.
    return json.dumps(
        {
            "points": frame.points.tolist(),
            "scale": frame.scale,
        }
    )

async def lidar_stream(websocket, source_mode: str, udp_source: Optional[UdpPointSource]):
    print("Client connected")

    try:
        while True:
            if source_mode == "demo":
                frame = _demo_frame()
            else:
                assert udp_source is not None
                frame = await udp_source.read_frame()
                if frame is None:
                    await asyncio.sleep(0.005)
                    continue

            msg = _frame_to_message(frame)

            await websocket.send(msg)
            await asyncio.sleep(0.03)  # target ~30 FPS (frames are also gated by frame_ms)

    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    parser = argparse.ArgumentParser(description="WebSocket point cloud server for browser viewer.")
    parser.add_argument("--ws-port", type=int, default=PORT)
    parser.add_argument("--mode", choices=["demo", "udp"], default="demo")
    parser.add_argument("--udp-host", default="0.0.0.0", help="Local interface to bind UDP listener.")
    parser.add_argument("--udp-port", type=int, default=2368, help="UDP port to listen for LiDAR packets.")
    parser.add_argument(
        "--udp-format",
        default="auto",
        choices=["auto", "f32xyz", "f32xyzi", "i16xyz_mm", "i16xyzi_mm"],
        help="How to decode incoming UDP payloads into points.",
    )
    parser.add_argument("--udp-header-bytes", type=int, default=0, help="Bytes to skip at start of each UDP packet.")
    parser.add_argument("--frame-ms", type=int, default=50, help="Frame time in ms (merge packets into a frame).")
    parser.add_argument("--max-points", type=int, default=80000, help="Cap points per frame for browser performance.")

    args = parser.parse_args()

    udp_source = None
    if args.mode == "udp":
        udp_source = UdpPointSource(
            host=args.udp_host,
            port=args.udp_port,
            fmt=args.udp_format,
            header_bytes=args.udp_header_bytes,
            frame_ms=args.frame_ms,
            max_points=args.max_points,
        )

    async def handler(ws):
        return await lidar_stream(ws, args.mode, udp_source)

    async with websockets.serve(handler, "0.0.0.0", args.ws_port):
        print(f"LiDAR server running on port {args.ws_port} (mode={args.mode})")
        if args.mode == "udp":
            print(
                "Tip: if you get no decoded packets, try setting --udp-format explicitly and/or --udp-header-bytes."
            )
        await asyncio.Future()

asyncio.run(main())
