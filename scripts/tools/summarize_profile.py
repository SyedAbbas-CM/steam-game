#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path


KEYS = [
    "frame_time_ms",
    "physics_time_ms",
    "bullets_active",
    "hazards_active",
    "traps_active",
    "timers_active",
    "particles_active",
    "node_count",
    "object_count",
    "orphan_nodes",
    "video_mem_mb",
]


def load_summary(path: Path) -> dict:
    if path.is_dir():
        path = path / "summary.json"
    return json.loads(path.read_text())


def fmt(v: object) -> str:
    if isinstance(v, float):
        return f"{v:.3f}"
    return str(v)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: summarize_profile.py <session_dir|summary.json>", file=sys.stderr)
        return 2

    path = Path(sys.argv[1]).expanduser()
    data = load_summary(path)

    print(f"session: {data.get('session_name')}")
    print(f"duration_s: {fmt(data.get('duration_s', 0.0))}")
    print()

    baseline = data.get("baseline_metrics", {})
    content_baseline = data.get("content_baseline_metrics", {})
    final = data.get("final_metrics", {})
    peak = data.get("peak_metrics", {})
    delta = data.get("delta_metrics", {})
    content_delta = data.get("content_delta_metrics", {})

    print("metrics:")
    for key in KEYS:
        print(
            f"  {key}: baseline={fmt(baseline.get(key, 0))} "
            f"content_baseline={fmt(content_baseline.get(key, 0))} "
            f"final={fmt(final.get(key, 0))} peak={fmt(peak.get(key, 0))} "
            f"delta={fmt(delta.get(key, 0))} "
            f"content_delta={fmt(content_delta.get(key, 0))}"
        )

    tracked = data.get("tracked_script_counts", {})
    if tracked:
        print()
        print("tracked_script_counts:")
        for key, value in sorted(tracked.items(), key=lambda kv: (-int(kv[1]), kv[0])):
            print(f"  {key}: {value}")

    suspects = data.get("suspect_report", [])
    if suspects:
        print()
        print("suspect_report:")
        for suspect in suspects:
            print(f"  - {suspect.get('kind')}: {suspect.get('message')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
