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
