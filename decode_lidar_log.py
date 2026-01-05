#!/usr/bin/env python3
"""
Decode LiDAR JSONL logs produced by lidar_server.py --log.

Outputs:
  - <out_dir>/meta.jsonl            (one JSON record per frame)
  - <out_dir>/frames/frame_000001.csv (per-frame point CSV)

Each input line is a JSON object with a compressed float32 point array:
  points: { shape: [N,3|4], encoding: "base64+zlib", data: "..." }
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import sys
import zlib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, Tuple

import numpy as np


def decode_points(points_obj: Dict[str, Any]) -> np.ndarray:
    if points_obj.get("dtype") != "float32":
        raise ValueError(f"Unsupported dtype: {points_obj.get('dtype')}")
    if points_obj.get("encoding") != "base64+zlib":
        raise ValueError(f"Unsupported encoding: {points_obj.get('encoding')}")
    shape = points_obj.get("shape")
    if not (isinstance(shape, list) and len(shape) == 2):
        raise ValueError(f"Invalid shape: {shape}")
    raw = zlib.decompress(base64.b64decode(points_obj["data"]))
    pts = np.frombuffer(raw, dtype=np.float32).reshape(tuple(shape))  # type: ignore[arg-type]
    return pts


def iso_utc_from_unix_ns(t_unix_ns: int) -> str:
    # ISO 8601 with microsecond precision
    dt = datetime.fromtimestamp(t_unix_ns / 1e9, tz=timezone.utc)
    return dt.isoformat(timespec="microseconds")


def iter_json_lines(path: Path) -> Iterable[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                yield json.loads(line)
            except json.JSONDecodeError as e:
                raise ValueError(f"Invalid JSON on line {line_no}: {e}") from e


def main() -> int:
    ap = argparse.ArgumentParser(description="Decode LiDAR JSONL logs to per-frame CSV + meta.jsonl.")
    ap.add_argument("log", help="Path to lidar_*.jsonl file")
    ap.add_argument("--out", default="decoded", help="Output directory (default: decoded)")
    ap.add_argument("--every", type=int, default=1, help="Export every Nth frame (default: 1)")
    ap.add_argument("--limit", type=int, default=0, help="Maximum frames to export (0 = no limit)")
    ap.add_argument("--no-points", action="store_true", help="Only write meta.jsonl, skip CSV point export")
    args = ap.parse_args()

    log_path = Path(args.log).expanduser()
    out_dir = Path(args.out).expanduser()
    frames_dir = out_dir / "frames"
    out_dir.mkdir(parents=True, exist_ok=True)
    frames_dir.mkdir(parents=True, exist_ok=True)

    meta_path = out_dir / "meta.jsonl"
    meta_f = meta_path.open("w", encoding="utf-8")

    exported = 0
    seen = 0

    try:
        for rec in iter_json_lines(log_path):
            seen += 1
            if args.every > 1 and (seen - 1) % args.every != 0:
                continue
            if args.limit and exported >= args.limit:
                break

            frame_id = int(rec.get("frame_id", seen))
            t_unix_ns = int(rec["t_unix_ns"])
            t_mono_ns = int(rec["t_mono_ns"])

            pts_shape = rec.get("points", {}).get("shape", [0, 0])
            point_count = int(pts_shape[0]) if isinstance(pts_shape, list) and pts_shape else 0
            cols = int(pts_shape[1]) if isinstance(pts_shape, list) and len(pts_shape) >= 2 else 0

            csv_name = f"frame_{frame_id:06d}.csv"
            csv_path = frames_dir / csv_name

            # Write points CSV
            if not args.no_points:
                pts = decode_points(rec["points"])
                header = "x,y,z,intensity" if pts.shape[1] >= 4 else "x,y,z"
                np.savetxt(
                    csv_path,
                    pts,
                    delimiter=",",
                    header=header,
                    comments="",
                )

            meta = {
                "frame_id": frame_id,
                "t_unix_ns": t_unix_ns,
                "t_utc": iso_utc_from_unix_ns(t_unix_ns),
                "t_mono_ns": t_mono_ns,
                "lidar_seq": rec.get("lidar_seq"),
                "lidar_stamp_sec": rec.get("lidar_stamp_sec"),
                "lidar_stamp_nsec": rec.get("lidar_stamp_nsec"),
                "scale": rec.get("scale"),
                "source_format": rec.get("source_format"),
                "points_cols": cols,
                "points_count": point_count,
                "points_csv": str(Path("frames") / csv_name),
            }
            meta_f.write(json.dumps(meta) + "\n")

            exported += 1

    finally:
        meta_f.flush()
        meta_f.close()

    print(f"Decoded {exported} frame(s) to: {out_dir}")
    print(f"Meta: {meta_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

