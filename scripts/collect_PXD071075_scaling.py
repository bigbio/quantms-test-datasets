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
import re
import subprocess
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


_DURATION_RE = re.compile(r"(?:(\d+)d)?\s*(?:(\d+)h)?\s*(?:(\d+)min)?\s*(?:(\d+(?:\.\d+)?)s)?")
_MEMORY_RE = re.compile(r"^([\d.]+)\s*(KB|MB|GB|TB)$", re.IGNORECASE)


def _parse_duration_to_seconds(text: str) -> float:
    """Parse a Nextflow duration string like '14min 40s' or '1h 30min'."""
    text = (text or "").strip()
    if not text or text == "-":
        return 0.0
    match = _DURATION_RE.fullmatch(text)
    if not match or not any(match.groups()):
        return 0.0
    days, hours, minutes, seconds = match.groups(default="0")
    return (
        int(days) * 86400
        + int(hours) * 3600
        + int(minutes) * 60
        + float(seconds or 0)
    )


def _parse_memory_to_gb(text: str) -> float:
    """Parse '24.2 GB' / '512 MB' / '-' to GB float."""
    text = (text or "").strip()
    if not text or text == "-":
        return 0.0
    match = _MEMORY_RE.match(text)
    if not match:
        return 0.0
    value, unit = float(match.group(1)), match.group(2).upper()
    return {
        "KB": value / 1024 / 1024,
        "MB": value / 1024,
        "GB": value,
        "TB": value * 1024,
    }[unit]


def parse_nextflow_trace(trace_path: Path) -> dict:
    """Summarise a Nextflow trace.txt file.

    Returns counts + aggregates suitable for one row of timings.csv.
    Missing file gives zero counters (lets us run mid-sweep).
    """
    empty = {
        "tasks_submitted": 0,
        "tasks_succeeded": 0,
        "tasks_failed": 0,
        "peak_mem_gb": 0.0,
        "total_cpu_s": 0,
    }
    if not trace_path.is_file():
        return empty

    with trace_path.open() as fh:
        header_line = fh.readline().rstrip("\n")
        if not header_line:
            return empty
        header = header_line.split("\t")
        col = {name: i for i, name in enumerate(header)}

        submitted = succeeded = failed = 0
        peak_mem = 0.0
        total_realtime = 0.0

        for raw in fh:
            row = raw.rstrip("\n").split("\t")
            if len(row) < len(header):
                continue
            submitted += 1
            status = row[col.get("status", -1)] if "status" in col else ""
            if status == "COMPLETED":
                succeeded += 1
            elif status == "FAILED":
                failed += 1
            mem = _parse_memory_to_gb(row[col["peak_rss"]]) if "peak_rss" in col else 0.0
            peak_mem = max(peak_mem, mem)
            total_realtime += _parse_duration_to_seconds(row[col["realtime"]]) if "realtime" in col else 0

    return {
        "tasks_submitted": submitted,
        "tasks_succeeded": succeeded,
        "tasks_failed": failed,
        "peak_mem_gb": round(peak_mem, 2),
        "total_cpu_s": int(round(total_realtime)),
    }


_HMS_RE = re.compile(r"^(?:(\d+)-)?(\d+):(\d+):(\d+)(?:\.\d+)?$")


def _hms_to_seconds(text: str) -> int:
    """SLURM HH:MM:SS or D-HH:MM:SS to seconds."""
    text = (text or "").strip()
    if not text:
        return 0
    match = _HMS_RE.match(text)
    if not match:
        return 0
    days, h, m, s = match.groups(default="0")
    return int(days or 0) * 86400 + int(h) * 3600 + int(m) * 60 + int(s)


def _rss_to_gb(text: str) -> float:
    """SLURM MaxRSS like '8388608K' / '8G' / '' to GB."""
    text = (text or "").strip()
    if not text:
        return 0.0
    unit = text[-1].upper()
    try:
        value = float(text[:-1] if unit in "KMGT" else text)
    except ValueError:
        return 0.0
    return {
        "K": value / (1024 * 1024),
        "M": value / 1024,
        "G": value,
        "T": value * 1024,
    }.get(unit, value / (1024 * 1024 * 1024))  # bytes fallback


def parse_sacct_output(stdout: str) -> dict:
    """Parse `sacct --parsable2 --format=Elapsed,CPUTime,MaxRSS` output.

    Picks the maximum (Elapsed, CPUTime) across rows and the max MaxRSS,
    because sacct reports parent + step rows and the step rows carry MaxRSS.
    """
    walltime = cputime = 0
    maxrss = 0.0
    lines = [ln for ln in stdout.splitlines() if ln.strip()]
    if len(lines) < 2:
        return {"slurm_walltime_s": 0, "slurm_cputime_s": 0, "slurm_maxrss_gb": 0.0}

    header = lines[0].split("|")
    col = {name: i for i, name in enumerate(header)}
    for row_text in lines[1:]:
        row = row_text.split("|")
        if "Elapsed" in col and col["Elapsed"] < len(row):
            walltime = max(walltime, _hms_to_seconds(row[col["Elapsed"]]))
        if "CPUTime" in col and col["CPUTime"] < len(row):
            cputime = max(cputime, _hms_to_seconds(row[col["CPUTime"]]))
        if "MaxRSS" in col and col["MaxRSS"] < len(row):
            maxrss = max(maxrss, _rss_to_gb(row[col["MaxRSS"]]))

    return {
        "slurm_walltime_s": walltime,
        "slurm_cputime_s": cputime,
        "slurm_maxrss_gb": round(maxrss, 2),
    }


def run_sacct(job_id: str) -> dict:
    """Invoke sacct for one job id and return parsed metrics.

    Returns zeros if sacct isn't available or the job isn't in accounting
    (lets the aggregator run off-cluster for fixture-based testing).
    """
    try:
        result = subprocess.run(
            ["sacct", "-j", str(job_id), "--format=Elapsed,CPUTime,MaxRSS", "--parsable2"],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return {"slurm_walltime_s": 0, "slurm_cputime_s": 0, "slurm_maxrss_gb": 0.0}
    if result.returncode != 0:
        return {"slurm_walltime_s": 0, "slurm_cputime_s": 0, "slurm_maxrss_gb": 0.0}
    return parse_sacct_output(result.stdout)


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
