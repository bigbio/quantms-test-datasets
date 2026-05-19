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
