#!/usr/bin/env python3
"""
BLE beacon logger (Blue Charm / iBeacon / Eddystone).

Records timestamped advertisements to JSONL for later merging with LiDAR logs.
Does NOT require pairing; it passively scans.

Examples:
  python3 beacon_logger.py --out logs/beacon_$(date +%Y%m%d_%H%M%S).jsonl --mac AA:BB:CC:DD:EE:FF
  python3 beacon_logger.py --out logs/beacon.jsonl --ibeacon-uuid 74278bda-b644-4520-8f0c-720eaf059935

Distance notes:
  If the packet includes Tx Power, we estimate distance via a simple path-loss model.
  Indoors (and especially in shafts), RSSI distance is noisy—treat as a weak signal.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Optional, Tuple

from bleak import BleakScanner


def utc_iso_from_unix_ns(t_unix_ns: int) -> str:
    return datetime.fromtimestamp(t_unix_ns / 1e9, tz=timezone.utc).isoformat(timespec="microseconds")


def normalize_uuid(u: str) -> str:
    return u.strip().lower()


def parse_ibeacon(manufacturer_data: Dict[int, bytes]) -> Optional[Dict[str, Any]]:
    """
    iBeacon is Apple company ID 0x004C, payload starts with:
      0x02 0x15 + 16-byte UUID + major(2) + minor(2) + txPower(1)
    """
    apple = manufacturer_data.get(0x004C)
    if not apple or len(apple) < 2:
        return None
    if apple[0] != 0x02 or apple[1] != 0x15:
        return None
    if len(apple) < 2 + 16 + 2 + 2 + 1:
        return None
    b = apple[2:]
    uuid_bytes = b[:16]
    major = int.from_bytes(b[16:18], "big")
    minor = int.from_bytes(b[18:20], "big")
    tx_power = int.from_bytes(b[20:21], "big", signed=True)
    # Format UUID bytes as 8-4-4-4-12
    hexs = uuid_bytes.hex()
    uuid = f"{hexs[0:8]}-{hexs[8:12]}-{hexs[12:16]}-{hexs[16:20]}-{hexs[20:32]}"
    return {"uuid": uuid.lower(), "major": major, "minor": minor, "tx_power": tx_power}


def parse_eddystone(service_data: Dict[str, bytes]) -> Optional[Dict[str, Any]]:
    """
    Eddystone uses service UUID 0xFEAA. Bleak reports service UUID keys as strings.
    Frame types:
      UID: 0x00 [txPower][namespace(10)][instance(6)][rfu(2)]
      URL: 0x10 ...
      TLM: 0x20 ...
    We'll parse UID if present.
    """
    for k, v in service_data.items():
        if k.lower() in ("0000feaa-0000-1000-8000-00805f9b34fb", "feaa"):
            if not v or len(v) < 2:
                return None
            frame = v[0]
            if frame == 0x00 and len(v) >= 18:
                tx_power = int.from_bytes(v[1:2], "big", signed=True)
                namespace = v[2:12].hex()
                instance = v[12:18].hex()
                return {"type": "uid", "tx_power": tx_power, "namespace": namespace, "instance": instance}
            return {"type": f"0x{frame:02x}"}
    return None


def estimate_distance_m(rssi: int, tx_power: Optional[int], n: float) -> Optional[float]:
    # Simple log-distance path loss model
    if tx_power is None:
        return None
    return float(10 ** ((tx_power - rssi) / (10 * n)))


@dataclass
class BeaconRecord:
    t_unix_ns: int
    t_utc: str
    address: str
    rssi: int
    local_name: Optional[str] = None
    tx_power: Optional[int] = None
    distance_m: Optional[float] = None
    ibeacon: Optional[Dict[str, Any]] = None
    eddystone: Optional[Dict[str, Any]] = None


async def main() -> int:
    ap = argparse.ArgumentParser(description="Log BLE beacon RSSI/intensity to JSONL.")
    ap.add_argument("--out", required=True, help="Output JSONL path")
    ap.add_argument("--mac", default="", help="Filter by MAC address (optional)")
    ap.add_argument("--name", default="", help="Filter by local name (optional substring match)")
    ap.add_argument("--ibeacon-uuid", default="", help="Filter by iBeacon UUID (optional)")
    ap.add_argument("--adapter", default="", help="Bluetooth adapter (optional, e.g. hci0)")
    ap.add_argument("--n", type=float, default=2.0, help="Path-loss exponent for distance estimate (default 2.0)")
    ap.add_argument("--duration", type=float, default=0.0, help="Run for N seconds then stop (0=run forever)")
    args = ap.parse_args()

    out_path = args.out
    mac_filter = args.mac.strip().lower()
    name_filter = args.name.strip().lower()
    uuid_filter = normalize_uuid(args.ibeacon_uuid) if args.ibeacon_uuid else ""

    fh = open(out_path, "a", buffering=1, encoding="utf-8")
    print(f"Beacon logging to: {out_path}")
    if mac_filter:
        print(f"Filter: mac={mac_filter}")
    if name_filter:
        print(f"Filter: name contains '{name_filter}'")
    if uuid_filter:
        print(f"Filter: ibeacon_uuid={uuid_filter}")

    def on_adv(device, adv_data):
        addr = (device.address or "").lower()
        if mac_filter and addr != mac_filter:
            return
        local_name = (adv_data.local_name or "") if adv_data.local_name else None
        if name_filter and (not local_name or name_filter not in local_name.lower()):
            return

        ibeacon = parse_ibeacon(adv_data.manufacturer_data or {})
        if uuid_filter and (not ibeacon or normalize_uuid(ibeacon["uuid"]) != uuid_filter):
            return

        eddy = parse_eddystone(adv_data.service_data or {})

        tx = None
        if ibeacon and "tx_power" in ibeacon:
            tx = int(ibeacon["tx_power"])
        elif eddy and "tx_power" in eddy:
            tx = int(eddy["tx_power"])
        elif adv_data.tx_power is not None:
            tx = int(adv_data.tx_power)

        t_unix_ns = time.time_ns()
        rec = BeaconRecord(
            t_unix_ns=t_unix_ns,
            t_utc=utc_iso_from_unix_ns(t_unix_ns),
            address=addr,
            rssi=int(adv_data.rssi),
            local_name=local_name,
            tx_power=tx,
            distance_m=estimate_distance_m(int(adv_data.rssi), tx, args.n),
            ibeacon=ibeacon,
            eddystone=eddy,
        )
        fh.write(json.dumps(asdict(rec)) + "\n")

    scanner = BleakScanner(on_adv, adapter=args.adapter or None)
    await scanner.start()
    try:
        if args.duration and args.duration > 0:
            await asyncio.sleep(args.duration)
        else:
            while True:
                await asyncio.sleep(1)
    except KeyboardInterrupt:
        pass
    finally:
        await scanner.stop()
        fh.flush()
        fh.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))

