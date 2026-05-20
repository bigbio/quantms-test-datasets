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

import matplotlib
matplotlib.use("Agg")  # headless — no display required on the cluster
import matplotlib.pyplot as plt
import pandas as pd

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


SDRF_SAMPLES = 2310  # PXD071075 has 2,310 single-cell DIA samples.


def _classify_exit(submitted: int, succeeded: int, run_kind: str) -> str:
    """OK / PARTIAL / FAIL based on task counts."""
    if run_kind == "baseline":
        # DIA-NN is one process; success/failure determined by trace absence.
        return "OK" if submitted == 0 else ("OK" if succeeded == submitted else "FAIL")
    if submitted == 0:
        return "PENDING"
    if succeeded == submitted:
        return "OK"
    if succeeded == 0:
        return "FAIL"
    return "PARTIAL"


def assemble_timings(base_results: Path) -> pd.DataFrame:
    """Build a DataFrame with one row per discovered point.

    For each point: read run_metadata.json, parse trace.txt (if present),
    call sacct (if slurm_job_id present in metadata).
    """
    rows: list[dict] = []
    for point in discover_points(base_results):
        meta = point["metadata"]
        path = point["path"]

        trace_summary = parse_nextflow_trace(path / "pipeline_info" / "nextflow_trace.txt")
        sacct_summary = (
            run_sacct(meta["slurm_job_id"])
            if meta.get("slurm_job_id")
            else {"slurm_walltime_s": 0, "slurm_cputime_s": 0, "slurm_maxrss_gb": 0.0}
        )

        # peak_mem_gb: prefer trace (per-task RSS sum is wrong, max is right) but
        # fall back to sacct MaxRSS when trace is empty (baselines).
        peak_mem = trace_summary["peak_mem_gb"] or sacct_summary["slurm_maxrss_gb"]
        total_cpu = trace_summary["total_cpu_s"] or sacct_summary["slurm_cputime_s"]

        run_kind = point["run_kind"]
        rows.append(
            {
                "point_id": point["point_id"],
                "version": meta.get("diann_version", ""),
                "run_kind": run_kind,
                "cluster_cores": meta.get("sweep_cores") or meta.get("cluster_cores_requested") or 0,
                "queue_size": meta.get("queue_size"),
                "sdrf_samples": SDRF_SAMPLES,
                "slurm_walltime_s": sacct_summary["slurm_walltime_s"],
                "total_task_realtime_s": total_cpu if run_kind == "sweep" else None,
                "total_cpu_s": total_cpu,
                "peak_mem_gb": peak_mem,
                "tasks_submitted": trace_summary["tasks_submitted"] if run_kind == "sweep" else 1,
                "tasks_succeeded": trace_summary["tasks_succeeded"] if run_kind == "sweep" else (1 if sacct_summary["slurm_walltime_s"] > 0 else 0),
                "exit_status": _classify_exit(
                    trace_summary["tasks_submitted"] if run_kind == "sweep" else 1,
                    trace_summary["tasks_succeeded"] if run_kind == "sweep" else (1 if sacct_summary["slurm_walltime_s"] > 0 else 0),
                    run_kind,
                ),
            }
        )
    return pd.DataFrame(rows)


def write_timings_csv(df: pd.DataFrame, csv_path: Path) -> None:
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(csv_path, index=False)


def plot_scaling(df: pd.DataFrame, plots_dir: Path) -> None:
    """Render cores_vs_walltime.png and cores_vs_speedup.png into plots_dir."""
    plots_dir.mkdir(parents=True, exist_ok=True)
    successful = df[df["exit_status"].isin(["OK", "PARTIAL"])].copy()

    # --- cores_vs_walltime.png -----------------------------------------
    fig, ax = plt.subplots(figsize=(8, 6))
    sweep = successful[successful["run_kind"] == "sweep"].sort_values("cluster_cores")
    if not sweep.empty:
        ax.plot(sweep["cluster_cores"], sweep["slurm_walltime_s"],
                marker="o", label="v2.5.0 sweep", color="C0")
    for version, color in [("1_8_1", "C2"), ("2_5_0", "C3")]:
        b = successful[(successful["run_kind"] == "baseline") & (successful["version"] == version)]
        if not b.empty:
            ax.scatter(b["cluster_cores"], b["slurm_walltime_s"],
                       marker="s", s=120, color=color, label=f"v{version.replace('_', '.')} baseline (single node)")
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Cluster cores")
    ax.set_ylabel("Wall-time (seconds, log)")
    ax.set_title("PXD071075 scaling — cores vs. wall-time")
    ax.grid(True, which="both", linestyle=":", alpha=0.5)
    ax.legend(loc="best")
    fig.tight_layout()
    fig.savefig(plots_dir / "cores_vs_walltime.png", dpi=150)
    plt.close(fig)

    # --- cores_vs_speedup.png ------------------------------------------
    fig, ax = plt.subplots(figsize=(8, 6))
    if not sweep.empty and len(sweep) >= 2:
        ref_row = sweep[sweep["cluster_cores"] == sweep["cluster_cores"].max()].iloc[0]
        ref_walltime = ref_row["slurm_walltime_s"]
        sweep_with_speedup = sweep.copy()
        sweep_with_speedup["speedup"] = ref_walltime / sweep_with_speedup["slurm_walltime_s"].replace(0, pd.NA)
        ax.plot(sweep_with_speedup["cluster_cores"], sweep_with_speedup["speedup"],
                marker="o", label=f"Observed (ref = {int(ref_row['cluster_cores'])} cores)", color="C0")
        # Ideal linear scaling: speedup proportional to cores / ref_cores
        ax.plot(sweep_with_speedup["cluster_cores"],
                sweep_with_speedup["cluster_cores"] / ref_row["cluster_cores"],
                linestyle="--", label="Ideal linear", color="C1")
    else:
        ax.text(0.5, 0.5, "Not enough sweep points to plot speedup",
                ha="center", va="center", transform=ax.transAxes)
    ax.set_xlabel("Cluster cores")
    ax.set_ylabel("Speedup (ref / observed wall-time)")
    ax.set_title("PXD071075 scaling — speedup")
    ax.grid(True, linestyle=":", alpha=0.5)
    if not sweep.empty and len(sweep) >= 2:
        ax.legend(loc="best")
    fig.tight_layout()
    fig.savefig(plots_dir / "cores_vs_speedup.png", dpi=150)
    plt.close(fig)


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--base-results", type=Path, default=DEFAULT_BASE_RESULTS,
                        help=f"Per-point results root (default: {DEFAULT_BASE_RESULTS})")
    parser.add_argument("--no-plot", action="store_true",
                        help="Skip PNG generation; only write timings.csv")
    args = parser.parse_args(argv)

    points = discover_points(args.base_results)
    print(f"Discovered {len(points)} point(s) under {args.base_results}")
    if not points:
        print("(nothing to aggregate yet)")
        return 0

    df = assemble_timings(args.base_results)
    csv_path = args.base_results / "timings.csv"
    write_timings_csv(df, csv_path)
    print(f"Wrote {csv_path} ({len(df)} rows)")
    print(df.to_string(index=False))
    if not args.no_plot:
        plots_dir = args.base_results / "plots"
        plot_scaling(df, plots_dir)
        print(f"Wrote plots to {plots_dir}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
