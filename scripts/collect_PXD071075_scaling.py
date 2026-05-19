#!/usr/bin/env python3
"""Collect and plot timings for the PXD071075 cluster-scaling sweep.

Walks per-point result directories under $BASE_RESULTS/PXD071075/, reads each
point's run_metadata.json + Nextflow trace.txt (or DIA-NN log for baselines)
+ sacct output, and emits:

  timings.csv           - one row per point
  plots/cores_vs_walltime.png
  plots/cores_vs_speedup.png

Usage:
  ./scripts/collect_PXD071075_scaling.py [--base-results <dir>] [--no-plot]

Idempotent - rerun anytime to refresh from whatever points have completed.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Iterable

DEFAULT_BASE_RESULTS = Path(
    "/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075"
)


def _classify_run_kind(metadata: dict) -> str:
    """sweep / baseline / unknown based on metadata fields."""
    explicit = metadata.get("run_kind")
    if explicit in ("baseline", "sweep"):
        return explicit
    if metadata.get("sweep_cores") is not None:
        return "sweep"
    return "baseline"


def discover_points(base_results: Path) -> list[dict]:
    """Find every point directory under base_results and load its metadata.

    A point is any subdirectory containing run_metadata.json. Subdirectories
    without that file are silently skipped (they're work dirs, plots/, etc.).
    """
    if not base_results.exists():
        return []
    points: list[dict] = []
    for entry in sorted(base_results.iterdir()):
        if not entry.is_dir():
            continue
        metadata_path = entry / "run_metadata.json"
        if not metadata_path.is_file():
            continue
        metadata = json.loads(metadata_path.read_text())
        points.append(
            {
                "point_id": entry.name,
                "path": entry,
                "metadata": metadata,
                "run_kind": _classify_run_kind(metadata),
            }
        )
    return points


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--base-results",
        type=Path,
        default=DEFAULT_BASE_RESULTS,
        help=f"Per-point results root (default: {DEFAULT_BASE_RESULTS})",
    )
    parser.add_argument(
        "--no-plot",
        action="store_true",
        help="Skip PNG generation; only write timings.csv",
    )
    args = parser.parse_args(argv)

    points = discover_points(args.base_results)
    print(f"Discovered {len(points)} point(s) under {args.base_results}")
    for p in points:
        print(f"  - {p['point_id']:<30}  kind={p['run_kind']}  v{p['metadata'].get('diann_version', '?')}")

    # Subsequent tasks will: parse trace.txt / DIA-NN log, run sacct,
    # assemble timings DataFrame, write CSV, generate plots.
    return 0


if __name__ == "__main__":
    sys.exit(main())
