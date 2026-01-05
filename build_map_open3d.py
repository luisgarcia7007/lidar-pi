#!/usr/bin/env python3
"""
Build a global point cloud map from a LiDAR log via simple frame-to-frame ICP (baseline LiDAR odometry).

This produces a map where points are no longer all at the same origin.

Requirements:
  pip install open3d

Notes:
  - This is a baseline. Real SLAM (especially in shafts) benefits from IMU + loop closure.
  - Run this on a desktop/laptop; Open3D is heavy on Raspberry Pi.
"""

from __future__ import annotations

import argparse
import base64
import json
import zlib
from pathlib import Path
from typing import Any, Dict, Iterator, Tuple

import numpy as np


def iter_jsonl(path: Path) -> Iterator[Dict[str, Any]]:
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            yield json.loads(line)


def decode_points(rec: Dict[str, Any]) -> np.ndarray:
    pm = rec["points"]
    shape = tuple(pm["shape"])
    raw = zlib.decompress(base64.b64decode(pm["data"]))
    pts = np.frombuffer(raw, dtype=np.float32).reshape(shape)
    return pts


def main() -> int:
    ap = argparse.ArgumentParser(description="Build a global map from LiDAR JSONL using Open3D ICP.")
    ap.add_argument("lidar_log", help="Path to lidar_*.jsonl")
    ap.add_argument("--out", default="map.ply", help="Output PLY filename")
    ap.add_argument("--every", type=int, default=1, help="Use every Nth frame (default 1)")
    ap.add_argument("--limit", type=int, default=0, help="Max frames to process (0 = no limit)")
    ap.add_argument("--voxel", type=float, default=0.05, help="Downsample voxel size (meters)")
    ap.add_argument("--max-correspondence", type=float, default=0.25, help="ICP max correspondence distance (m)")
    args = ap.parse_args()

    try:
        import open3d as o3d  # type: ignore
    except Exception as e:
        raise SystemExit(f"Open3D not installed. Install with: pip install open3d\n{e}")

    log_path = Path(args.lidar_log).expanduser()

    # Accumulated map
    global_map = o3d.geometry.PointCloud()

    T = np.eye(4, dtype=np.float64)
    prev = None
    processed = 0
    used = 0

    for rec in iter_jsonl(log_path):
        processed += 1
        if args.every > 1 and (processed - 1) % args.every != 0:
            continue
        if args.limit and used >= args.limit:
            break

        pts = decode_points(rec)
        scale = float(rec.get("scale", 1.0))
        xyz = pts[:, :3] * scale

        # Filter obviously bad points
        xyz = xyz[np.isfinite(xyz).all(axis=1)]
        if xyz.shape[0] < 200:
            continue

        pcd = o3d.geometry.PointCloud()
        pcd.points = o3d.utility.Vector3dVector(xyz.astype(np.float64))
        pcd = pcd.voxel_down_sample(args.voxel)
        pcd.estimate_normals()

        if prev is None:
            global_map += pcd
            prev = pcd
            used += 1
            continue

        # ICP relative pose
        reg = o3d.pipelines.registration.registration_icp(
            pcd,
            prev,
            args.max_correspondence,
            np.eye(4),
            o3d.pipelines.registration.TransformationEstimationPointToPlane(),
        )

        T = T @ reg.transformation  # compose
        pcd_global = pcd.transform(T.copy())
        global_map += pcd_global
        prev = pcd
        used += 1

    # Final downsample for output
    global_map = global_map.voxel_down_sample(args.voxel)
    out_path = Path(args.out).expanduser()
    o3d.io.write_point_cloud(str(out_path), global_map)
    print(f"Wrote map: {out_path} (frames used: {used}, processed: {processed})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

