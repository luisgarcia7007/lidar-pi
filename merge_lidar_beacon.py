#!/usr/bin/env python3
"""
Merge LiDAR frame logs (JSONL) with beacon logs (JSONL) by timestamp.

Output is JSONL (one record per LiDAR frame) containing:
  - lidar timestamps + basic stats
  - nearest (or window-aggregated) beacon RSSI/distance

This does NOT do SLAM. It only time-aligns data so you can feed it into
downstream mapping / SLAM pipelines.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def read_jsonl(path: Path) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            out.append(json.loads(line))
    return out


def nearest_by_time_ns(records: List[Dict[str, Any]], t_ns: int) -> Optional[Dict[str, Any]]:
    if not records:
        return None
    best = None
    best_dt = None
    for r in records:
        tr = int(r["t_unix_ns"])
        dt = abs(tr - t_ns)
        if best_dt is None or dt < best_dt:
            best_dt = dt
            best = r
    return best


def window_stats(records: List[Dict[str, Any]], t_ns: int, window_ns: int) -> Optional[Dict[str, Any]]:
    if not records:
        return None
    lo = t_ns - window_ns
    hi = t_ns + window_ns
    inwin = [r for r in records if lo <= int(r["t_unix_ns"]) <= hi]
    if not inwin:
        return None

    # Prefer distance_m if present; otherwise RSSI only.
    rssis = [int(r["rssi"]) for r in inwin if r.get("rssi") is not None]
    dists = [float(r["distance_m"]) for r in inwin if r.get("distance_m") is not None]

    # simple robust-ish summaries (median)
    def median(xs: List[float]) -> float:
        xs2 = sorted(xs)
        n = len(xs2)
        mid = n // 2
        return xs2[mid] if (n % 2 == 1) else 0.5 * (xs2[mid - 1] + xs2[mid])

    return {
        "count": len(inwin),
        "t_first_ns": int(min(int(r["t_unix_ns"]) for r in inwin)),
        "t_last_ns": int(max(int(r["t_unix_ns"]) for r in inwin)),
        "rssi_median": median([float(x) for x in rssis]) if rssis else None,
        "distance_m_median": median(dists) if dists else None,
        "mac": inwin[-1].get("address"),
        "name": inwin[-1].get("local_name"),
        "ibeacon": inwin[-1].get("ibeacon"),
    }


def main() -> int:
    ap = argparse.ArgumentParser(description="Merge lidar_*.jsonl with beacon_*.jsonl by timestamp.")
    ap.add_argument("--lidar", required=True, help="Path to lidar_*.jsonl")
    ap.add_argument("--beacon", required=True, help="Path to beacon_*.jsonl")
    ap.add_argument("--out", required=True, help="Output JSONL path")
    ap.add_argument("--window-ms", type=int, default=1000, help="Beacon aggregation half-window (ms).")
    ap.add_argument("--nearest-only", action="store_true", help="Use single nearest beacon record instead of window stats.")
    args = ap.parse_args()

    lidar_path = Path(args.lidar).expanduser()
    beacon_path = Path(args.beacon).expanduser()
    out_path = Path(args.out).expanduser()

    lidar = read_jsonl(lidar_path)
    beacon = read_jsonl(beacon_path)

    window_ns = int(args.window_ms) * 1_000_000

    with out_path.open("w", encoding="utf-8") as out:
        for fr in lidar:
            t_ns = int(fr["t_unix_ns"])

            if args.nearest_only:
                b = nearest_by_time_ns(beacon, t_ns)
                b_out = None if b is None else {
                    "t_unix_ns": int(b["t_unix_ns"]),
                    "rssi": b.get("rssi"),
                    "distance_m": b.get("distance_m"),
                    "address": b.get("address"),
                    "local_name": b.get("local_name"),
                    "ibeacon": b.get("ibeacon"),
                }
            else:
                b_out = window_stats(beacon, t_ns, window_ns)

            pts_shape = fr.get("points", {}).get("shape", [0, 0])
            pts_count = int(pts_shape[0]) if isinstance(pts_shape, list) and pts_shape else None

            merged = {
                "frame_id": fr.get("frame_id"),
                "t_unix_ns": t_ns,
                "t_mono_ns": fr.get("t_mono_ns"),
                "lidar_seq": fr.get("lidar_seq"),
                "lidar_stamp_sec": fr.get("lidar_stamp_sec"),
                "lidar_stamp_nsec": fr.get("lidar_stamp_nsec"),
                "scale": fr.get("scale"),
                "source_format": fr.get("source_format"),
                "points_count": pts_count,
                "beacon": b_out,
            }
            out.write(json.dumps(merged) + "\n")

    print(f"Wrote merged JSONL: {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

