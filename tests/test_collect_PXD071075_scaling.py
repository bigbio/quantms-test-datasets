"""Tests for the PXD071075 scaling-benchmark aggregator."""

import sys
from pathlib import Path

import pytest

# Make the script importable as a module.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

import collect_PXD071075_scaling as agg

FIXTURES = Path(__file__).resolve().parent / "fixtures" / "PXD071075"


def test_discover_points_finds_both_kinds():
    points = agg.discover_points(FIXTURES)
    point_ids = sorted(p["point_id"] for p in points)
    assert point_ids == ["v1_8_1_baseline_48cpu", "v2_5_0_sweep_050cores"]


def test_discover_points_attaches_metadata():
    points = {p["point_id"]: p for p in agg.discover_points(FIXTURES)}

    sweep = points["v2_5_0_sweep_050cores"]
    assert sweep["metadata"]["diann_version"] == "2_5_0"
    assert sweep["metadata"]["sweep_cores"] == 50
    assert sweep["metadata"]["queue_size"] == 7
    assert sweep["run_kind"] == "sweep"

    baseline = points["v1_8_1_baseline_48cpu"]
    assert baseline["metadata"]["diann_version"] == "1_8_1"
    assert baseline["metadata"]["sweep_cores"] is None
    assert baseline["run_kind"] == "baseline"


def test_discover_points_skips_dirs_without_metadata(tmp_path):
    # Set up a results tree with one valid + one bogus directory.
    (tmp_path / "valid_point" / "noise.txt").parent.mkdir(parents=True)
    (tmp_path / "valid_point" / "run_metadata.json").write_text(
        '{"diann_version": "2_5_0", "sweep_cores": 100, "queue_size": 13}'
    )
    (tmp_path / "no_metadata_here").mkdir()
    (tmp_path / "no_metadata_here" / "nextflow.log").touch()

    points = agg.discover_points(tmp_path)
    assert [p["point_id"] for p in points] == ["valid_point"]


def test_parse_nextflow_trace_counts_status():
    trace = FIXTURES / "v2_5_0_sweep_050cores" / "nextflow_trace.txt"
    summary = agg.parse_nextflow_trace(trace)
    assert summary["tasks_submitted"] == 5
    assert summary["tasks_succeeded"] == 4
    assert summary["tasks_failed"] == 1


def test_parse_nextflow_trace_peak_memory():
    trace = FIXTURES / "v2_5_0_sweep_050cores" / "nextflow_trace.txt"
    summary = agg.parse_nextflow_trace(trace)
    # Peak across all rows: 24.2 GB from INSILICO_LIBRARY_GENERATION
    assert summary["peak_mem_gb"] == pytest.approx(24.2, abs=0.05)


def test_parse_nextflow_trace_total_realtime():
    trace = FIXTURES / "v2_5_0_sweep_050cores" / "nextflow_trace.txt"
    summary = agg.parse_nextflow_trace(trace)
    # Sum of realtime: 9:30 + 2:50 + 3:20 + 14:40 + 1:50 = 32:10
    # = 570 + 170 + 200 + 880 + 110 = 1930 seconds
    assert summary["total_cpu_s"] == 1930


def test_parse_nextflow_trace_handles_missing_file(tmp_path):
    summary = agg.parse_nextflow_trace(tmp_path / "nope.txt")
    assert summary == {
        "tasks_submitted": 0,
        "tasks_succeeded": 0,
        "tasks_failed": 0,
        "peak_mem_gb": 0.0,
        "total_cpu_s": 0,
    }


from unittest.mock import patch
import subprocess


SACCT_OK = """Elapsed|CPUTime|MaxRSS
01:23:45|01:23:45|
01:23:45|01:23:45|8388608K
"""

SACCT_EMPTY = """Elapsed|CPUTime|MaxRSS
"""


def test_parse_sacct_elapsed_to_seconds():
    summary = agg.parse_sacct_output(SACCT_OK)
    # 1h 23min 45s = 3600 + 1380 + 45 = 5025
    assert summary["slurm_walltime_s"] == 5025
    assert summary["slurm_cputime_s"] == 5025


def test_parse_sacct_extracts_maxrss():
    summary = agg.parse_sacct_output(SACCT_OK)
    # MaxRSS 8388608K = 8 GiB ~ 8.0 GB
    assert summary["slurm_maxrss_gb"] == pytest.approx(8.0, abs=0.05)


def test_parse_sacct_handles_empty():
    summary = agg.parse_sacct_output(SACCT_EMPTY)
    assert summary == {
        "slurm_walltime_s": 0,
        "slurm_cputime_s": 0,
        "slurm_maxrss_gb": 0.0,
    }


def test_run_sacct_invokes_sacct_command():
    expected_argv = ["sacct", "-j", "12345", "--format=Elapsed,CPUTime,MaxRSS", "--parsable2"]
    with patch("subprocess.run") as mock_run:
        mock_run.return_value = subprocess.CompletedProcess(
            args=expected_argv, returncode=0, stdout=SACCT_OK, stderr=""
        )
        result = agg.run_sacct("12345")
    mock_run.assert_called_once_with(expected_argv, capture_output=True, text=True, check=False)
    assert result["slurm_walltime_s"] == 5025


def test_run_sacct_returns_zeros_when_sacct_missing():
    with patch("subprocess.run", side_effect=FileNotFoundError):
        result = agg.run_sacct("12345")
    assert result == {
        "slurm_walltime_s": 0,
        "slurm_cputime_s": 0,
        "slurm_maxrss_gb": 0.0,
    }


def test_assemble_timings_columns():
    expected_cols = {
        "point_id", "version", "run_kind",
        "cluster_cores", "queue_size", "sdrf_samples",
        "slurm_walltime_s", "nextflow_walltime_s", "total_cpu_s", "peak_mem_gb",
        "tasks_submitted", "tasks_succeeded", "exit_status",
    }
    with patch.object(agg, "run_sacct") as mock_sacct:
        mock_sacct.return_value = {
            "slurm_walltime_s": 5025, "slurm_cputime_s": 5025, "slurm_maxrss_gb": 8.0
        }
        df = agg.assemble_timings(FIXTURES)
    assert set(df.columns) == expected_cols


def test_assemble_timings_uses_sdrf_samples_constant():
    with patch.object(agg, "run_sacct") as mock_sacct:
        mock_sacct.return_value = {
            "slurm_walltime_s": 5025, "slurm_cputime_s": 5025, "slurm_maxrss_gb": 8.0
        }
        df = agg.assemble_timings(FIXTURES)
    assert (df["sdrf_samples"] == agg.SDRF_SAMPLES).all()


def test_assemble_timings_marks_partial_when_some_failed():
    with patch.object(agg, "run_sacct") as mock_sacct:
        mock_sacct.return_value = {
            "slurm_walltime_s": 5025, "slurm_cputime_s": 5025, "slurm_maxrss_gb": 8.0
        }
        df = agg.assemble_timings(FIXTURES)
    sweep_row = df[df["point_id"] == "v2_5_0_sweep_050cores"].iloc[0]
    # Fixture trace has 4 succeeded + 1 failed -> PARTIAL
    assert sweep_row["exit_status"] == "PARTIAL"
    assert sweep_row["tasks_submitted"] == 5
    assert sweep_row["tasks_succeeded"] == 4


def test_write_timings_csv_round_trip(tmp_path):
    with patch.object(agg, "run_sacct") as mock_sacct:
        mock_sacct.return_value = {
            "slurm_walltime_s": 5025, "slurm_cputime_s": 5025, "slurm_maxrss_gb": 8.0
        }
        df = agg.assemble_timings(FIXTURES)

    csv_path = tmp_path / "timings.csv"
    agg.write_timings_csv(df, csv_path)
    assert csv_path.is_file()

    import pandas as pd
    reloaded = pd.read_csv(csv_path)
    assert len(reloaded) == len(df)
    assert set(reloaded.columns) == set(df.columns)


def _fake_timings_df():
    """Hand-built DataFrame for plot tests — doesn't need fixtures."""
    return pd.DataFrame([
        {"point_id": "v1_8_1_baseline_48cpu", "version": "1_8_1", "run_kind": "baseline",
         "cluster_cores": 48, "queue_size": None, "sdrf_samples": 2310,
         "slurm_walltime_s": 50000, "nextflow_walltime_s": None,
         "total_cpu_s": 50000, "peak_mem_gb": 280.0,
         "tasks_submitted": 1, "tasks_succeeded": 1, "exit_status": "OK"},
        {"point_id": "v2_5_0_baseline_48cpu", "version": "2_5_0", "run_kind": "baseline",
         "cluster_cores": 48, "queue_size": None, "sdrf_samples": 2310,
         "slurm_walltime_s": 40000, "nextflow_walltime_s": None,
         "total_cpu_s": 40000, "peak_mem_gb": 270.0,
         "tasks_submitted": 1, "tasks_succeeded": 1, "exit_status": "OK"},
        {"point_id": "v2_5_0_sweep_010cores", "version": "2_5_0", "run_kind": "sweep",
         "cluster_cores": 10, "queue_size": 2, "sdrf_samples": 2310,
         "slurm_walltime_s": 600000, "nextflow_walltime_s": 590000,
         "total_cpu_s": 590000, "peak_mem_gb": 60.0,
         "tasks_submitted": 2400, "tasks_succeeded": 2400, "exit_status": "OK"},
        {"point_id": "v2_5_0_sweep_200cores", "version": "2_5_0", "run_kind": "sweep",
         "cluster_cores": 200, "queue_size": 25, "sdrf_samples": 2310,
         "slurm_walltime_s": 30000, "nextflow_walltime_s": 29500,
         "total_cpu_s": 29500, "peak_mem_gb": 65.0,
         "tasks_submitted": 2400, "tasks_succeeded": 2400, "exit_status": "OK"},
    ])


import pandas as pd  # for test fixture builder

def test_plot_scaling_writes_two_pngs(tmp_path):
    df = _fake_timings_df()
    plots_dir = tmp_path / "plots"
    agg.plot_scaling(df, plots_dir)
    assert (plots_dir / "cores_vs_walltime.png").is_file()
    assert (plots_dir / "cores_vs_speedup.png").is_file()


def test_plot_scaling_handles_no_sweep_rows(tmp_path):
    # Only baselines -> walltime plot still drawn, speedup plot is a stub.
    df = _fake_timings_df().head(2)
    plots_dir = tmp_path / "plots"
    agg.plot_scaling(df, plots_dir)
    assert (plots_dir / "cores_vs_walltime.png").is_file()
    assert (plots_dir / "cores_vs_speedup.png").is_file()
