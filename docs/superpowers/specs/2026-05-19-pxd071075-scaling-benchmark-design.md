# PXD071075 scaling benchmark — design

**Date:** 2026-05-19
**Dataset:** [PXD071075](https://www.ebi.ac.uk/pride/archive/projects/PXD071075) — single-cell DIA, Orbitrap Eclipse, 2,310 samples, human (UP000005640)
**Repo:** `quantms-test-datasets` (branch `feat/add-PXD071075-benchmark`)

## Context

PXD071075 is already routed as a non-ProteoBench benchmark at
[benchmarks/dia/OrbitrapEclipse/PXD071075/](../../../benchmarks/dia/OrbitrapEclipse/PXD071075/).
This spec adds a **scaling benchmark** on top: measure quantmsdiann wall-clock
time as a function of available cluster cores, plus a single-node DIA-NN
baseline for both supported DIA-NN versions.

The motivation is to characterise how the pipeline scales for a large
single-cell DIA workload (2,310 individual files) — useful for capacity
planning and for surfacing parallel-efficiency cliffs in the per-file analysis
stage.

## Goals

1. **Single-node baseline** run of direct DIA-NN (no Nextflow) on one fat
   node — 48 cpu, 300 GB RAM, Singularity — for **both DIA-NN v1.8.1 and
   v2.5.0**. The v1.8.1 baseline reads pre-converted `.mzML` files (see note
   in the Sweep matrix section below).
2. **Cluster scaling sweep** of the full quantmsdiann pipeline through
   Nextflow + SLURM (`pride_slurm` profile) at **{10, 20, 50, 100, 200} total
   in-flight cluster cores**, **v2.5.0 only**, Singularity.
3. **Reproducible measurement** — each point runs against a quiescent cluster
   (sequential dependency chain), records SLURM wall-time + Nextflow trace.
4. **Aggregation + plot** — single `timings.csv` plus `cores_vs_walltime.png`
   and `cores_vs_speedup.png`.

## Non-goals

- Comparing DIA-NN versions across the scaling sweep (only v2.5.0 is swept; the v1.8.1 baseline is a single-node quality check only).
- Per-task cpu-sizing sweeps (cpus per Nextflow task stay at pipeline defaults).
- Multi-node-allocation experiments (no SLURM heterogeneous jobs, no MPI).
- Cross-dataset scaling (Module 9 PXD049412 etc. is a future extension; the
  submitter is intentionally PXD071075-specific so we can validate the
  workflow before generalising).
- Output validation (peptide/protein-level QC). The benchmark measures
  runtime, not result correctness.

## Architecture

### Existing infrastructure (reused unchanged)

- [scripts/run_diann.sh](../../../scripts/run_diann.sh) — direct DIA-NN on one
  fat node. Already singularity-default, multi-version, PXD071075-flavoured
  parameter set. Used as-is for baselines; submitter overrides `--mem=300G`
  via sbatch flag.
- [scripts/run_local.sh](../../../scripts/run_local.sh) — Nextflow head SBATCH
  wrapper, 2 cpu / 8 GB, uses `pride_slurm` profile (per-task SLURM dispatch).
  Receives one **small extension** (see below).
- [scripts/extra.config](../../../scripts/extra.config) — per-process resource
  overrides. Unchanged for v1; sweep points use the file as-is.

### New components

| Component | Path | Purpose |
|---|---|---|
| Benchmark description | `benchmarks/dia/OrbitrapEclipse/PXD071075/DESCRIPTION.md` | Sample/protocol summary, sweep matrix, links to result paths on cluster |
| Sweep matrix | `benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv` | Source-of-truth table (version, run_kind, cluster_cores, queue_size, mem, dependency) consumed by the submitter and the aggregator |
| Submitter | `scripts/run_PXD071075_scaling.sh` | Top-level SLURM submitter for the 7-point sweep (2 baselines + 5 scaling) |
| Aggregator | `scripts/collect_PXD071075_scaling.py` | Walks per-point result directories on cluster, builds `timings.csv` + plots |

### Run_local.sh extension

One small additive change to [scripts/run_local.sh](../../../scripts/run_local.sh):
honor a new `QUEUE_SIZE` env var. When set, the runner writes a tiny inline
config at `$RESULTS_DIR/queue_size.config` containing:

```groovy
executor { queueSize = ${QUEUE_SIZE} }
```

and chains it onto the existing `-c` list (next to the optional `extra.config`
plumbing at lines 163-168). When `QUEUE_SIZE` is unset, the runner behaves
identically to today.

The runner also writes `$RESULTS_DIR/run_metadata.json` with:

```json
{
  "dataset": "PXD071075",
  "diann_version": "2_5_0",
  "sweep_cores": 100,
  "queue_size": 13,
  "slurm_job_id": "12345",
  "slurm_submit_dir": "...",
  "started_at_utc": "2026-05-19T18:30:00Z"
}
```

Aggregator reads this to label each result row.

### Run_diann.sh — no source changes

The existing runner already encodes the exact PXD071075 DIA-NN parameter set
(lines 104-146) and is singularity-default. Baselines override `--mem=300G`
and (optionally) `--cpus-per-task=48` via sbatch flags passed by the
submitter. No script edits.

For baseline points, **the submitter writes `run_metadata.json` into the
result dir before the `sbatch` call** (one-line `cat <<EOF > ... EOF`),
mirroring the schema written by `run_local.sh` for sweep points. This keeps
`run_diann.sh` unchanged and the aggregator's input shape uniform across
baseline and sweep points.

## File layout

### In repo (tracked)

```
quantms-test-datasets/
├── benchmarks/dia/OrbitrapEclipse/PXD071075/
│   ├── PXD071075.sdrf.tsv                 # existing — 2310 samples
│   ├── UP000005640_9606.fasta             # existing
│   ├── run_PXD071075_v1_8_1.config        # existing (reference; not used by sweep)
│   ├── run_PXD071075_v2_5_0.config        # existing (reference; not used by sweep)
│   ├── DESCRIPTION.md                     # NEW
│   └── scaling/
│       └── sweep_matrix.tsv               # NEW
├── scripts/
│   ├── run_PXD071075_scaling.sh           # NEW — submitter
│   ├── collect_PXD071075_scaling.py       # NEW — aggregator + plot
│   ├── run_local.sh                       # extended (QUEUE_SIZE support)
│   ├── run_diann.sh                       # unchanged
│   ├── extra.config                       # unchanged
│   └── proteobench_diann_versions.sh      # unchanged
└── docs/superpowers/specs/2026-05-19-pxd071075-scaling-benchmark-design.md  # this doc
```

### On cluster (not in repo)

```
/hps/nobackup/juan/pride/reanalysis/
├── raw-data/benchmarks/PXD071075/                  # already staged
├── quantmsdiann_work/PXD071075/<point-id>/         # NF work dirs (scratch)
├── logs/PXD071075/<point-id>/slurm_<jobid>.{out,err}
└── quantmsdiann_results/PXD071075/
    ├── v2_5_0_baseline_48cpu/
    │   ├── diann_report.tsv
    │   ├── diann.log
    │   └── run_metadata.json
    ├── v2_5_0_sweep_010cores/
    │   ├── results/                                # quantmsdiann outputs
    │   ├── nextflow.log
    │   ├── nextflow_trace.txt
    │   ├── nextflow_report.html
    │   ├── nextflow_timeline.html
    │   ├── queue_size.config
    │   └── run_metadata.json
    ├── v2_5_0_sweep_020cores/
    ├── v2_5_0_sweep_050cores/
    ├── v2_5_0_sweep_100cores/
    ├── v2_5_0_sweep_200cores/
    ├── timings.csv                                 # aggregator output
    └── plots/
        ├── cores_vs_walltime.png
        └── cores_vs_speedup.png
```

`<point-id>` mirrors the result subfolder name (e.g. `v2_5_0_sweep_050cores`).

## Sweep matrix

`benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv`:

> **Note on DIA-NN 1.8.1:** DIA-NN 1.8.1's bundled ThermoRawFileReader rejects
> the 2024 Orbitrap Eclipse `.raw` format. To keep the cross-version baseline
> meaningful, the v1.8.1 baseline reads pre-converted `.mzML` files produced by
> `scripts/convert_PXD071075_raw_to_mzml.sh` (ThermoRawFileParser, Singularity).
> The `raw_dir_override` column in the sweep matrix points the submitter to the
> mzML directory for that row. DIA-NN 2.5.0 and the Nextflow sweep read `.raw`
> directly. **Format-asymmetry caveat:** I/O timing is not directly comparable
> across v1.8.1 (mzML) and v2.5.0 (raw) baselines; the comparison is meaningful
> for *identification quality* only.

| version | run_kind | cluster_cores | queue_size | head_mem | per_job_mem | raw_dir_override | sdrf_samples |
|---------|----------|---------------|------------|----------|-------------|-----------------|--------------|
| 1.8.1   | baseline | 48            | n/a        | n/a      | 300 GB      | PXD071075-mzml  | 2310 |
| 2.5.0   | baseline | 48            | n/a        | n/a      | 300 GB      | -               | 2310 |
| 2.5.0   | sweep    | 10            | 2          | 8 GB     | pipeline default | -            | 2310 |
| 2.5.0   | sweep    | 20            | 3          | 8 GB     | pipeline default | -            | 2310 |
| 2.5.0   | sweep    | 50            | 7          | 8 GB     | pipeline default | -            | 2310 |
| 2.5.0   | sweep    | 100           | 13         | 8 GB     | pipeline default | -            | 2310 |
| 2.5.0   | sweep    | 200           | 25         | 8 GB     | pipeline default | -            | 2310 |

**queueSize formula:** `ceil(cluster_cores / 8)` where 8 is the cpu count of
the dominant per-file analysis step (`process_medium` in nf-core quantmsdiann).
This is an **approximation** — other steps (`process_low`, `process_high`)
share the queue and have different cpu sizings, so actual in-flight core count
will drift around the target. The mapping is documented in DESCRIPTION.md so
users can interpret the resulting numbers correctly. If a more precise mapping
becomes important, the future refinement is to pin per-process cpus in
`extra.config` (out of scope for v1).

## Dependency chain

Points run **strictly sequentially** via `sbatch --dependency=afterok:<prev>`.
Reasoning:

- Running concurrently would cause sweep points to fight for the same cluster
  cores, invalidating wall-time measurements.
- `afterok` (not `afterany`): if a point fails, downstream points abort —
  measurement requires successful completion, and the failure should be
  investigated before continuing.

Order:

```
v1_8_1_baseline_48cpu
  └─→ v2_5_0_baseline_48cpu
        └─→ v2_5_0_sweep_010cores
              └─→ v2_5_0_sweep_020cores
                    └─→ v2_5_0_sweep_050cores
                          └─→ v2_5_0_sweep_100cores
                                └─→ v2_5_0_sweep_200cores
```

Total estimated wall-time (rough, for capacity planning):
- Baselines: 2 × ~12h ≈ 24h
- Sweep: 200-core ~8h, 100-core ~16h, 50-core ~32h, 20-core ~80h, 10-core ~160h
- **Total: ~14 days** end-to-end if every point succeeds first try.

This is intentional: the 10-core point is the most informative for showing
where parallel efficiency starts to flatten, and skipping it would lose the
left tail of the curve. If runtime becomes a concern in practice, the easy
escape is `DRY_RUN=1` to preview the plan, then a manual `sbatch --dependency=`
chain that excludes the slowest points.

## Submitter (`scripts/run_PXD071075_scaling.sh`)

Mirrors the style of [scripts/proteobench_diann_versions.sh](../../../scripts/proteobench_diann_versions.sh):

1. **Plan-first**: builds the full list of jobs, prints it, then submits.
2. **Hardcoded paths** at top of script for `REPO_ROOT`, `RAW_DIR`,
   `BASE_RESULTS`, `BASE_WORK`, `LOGS_DIR` — same defaults as
   `proteobench_diann_versions.sh`.
3. **Reads sweep matrix from** `benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv`
   (so adjusting the sweep is a data change, not a code change).
4. **Per-row sbatch invocation** (7 rows: 2 baselines + 5 sweep):
   - For `run_kind=baseline`: `sbatch --mem=300G --cpus-per-task=48 --time=72:00:00 scripts/run_diann.sh <RAW_DIR> <FASTA> <RESULTS> <VERSION>`
   - For `run_kind=sweep`: `sbatch --export=ALL,QUEUE_SIZE=<N>,SWEEP_CORES=<C> scripts/run_local.sh <SDRF> <RAW_DIR> <FASTA> <WORK> <RESULTS> 2_5_0`
5. **Sequential dependency**: each submission after the first adds
   `--dependency=afterok:<previous_jid>`.
6. **`DRY_RUN=1`** prints sbatch lines without submitting.
7. **No retry logic** — if a point fails, the user investigates and resubmits
   downstream points manually with `-resume` (Nextflow runs) or fresh
   (baselines).

The script does **not** accept dataset/version args — it's intentionally
PXD071075-specific. Generalising to multi-dataset scaling is a future task
(approach C in the design discussion).

## Aggregator (`scripts/collect_PXD071075_scaling.py`)

Pure Python (pandas + matplotlib). Inputs:

- `$BASE_RESULTS/PXD071075/*/run_metadata.json` — point identity
- `$BASE_RESULTS/PXD071075/*/nextflow_trace.txt` (sweep) or `diann.log` (baseline) — task-level timings
- `sacct -j <head_jid> --format=Elapsed,CPUTime,MaxRSS --parsable2` — SLURM head-job wall + cpu + memory

Output: `$BASE_RESULTS/PXD071075/timings.csv`:

| Column | Type | Notes |
|---|---|---|
| `version` | str | `1_8_1` or `2_5_0` |
| `run_kind` | str | `baseline` or `sweep` |
| `cluster_cores` | int | nominal target (matches sweep_matrix.tsv) |
| `queue_size` | int? | null for baselines |
| `sdrf_samples` | int | 2310 |
| `slurm_walltime_s` | int | head-job Elapsed in seconds |
| `total_task_realtime_s` | int? | sum of per-task realtime from trace.txt, null for baselines |
| `total_cpu_s` | int | sum across all SLURM jobs (head + children) |
| `peak_mem_gb` | float | max MaxRSS observed |
| `tasks_submitted` | int | count from trace.txt (sweep) or 1 (baseline) |
| `tasks_succeeded` | int | count of `COMPLETED` |
| `exit_status` | str | OK / FAIL / PARTIAL |

Plots:

- `plots/cores_vs_walltime.png` — x=cluster_cores (log), y=slurm_walltime_s
  (log). Baselines plotted at x=48 as separate markers. Both DIA-NN versions
  shown for baselines; sweep is v2.5.0 only.
- `plots/cores_vs_speedup.png` — x=cluster_cores, y=walltime_at_200 / walltime.
  Reference line for ideal linear scaling. Sweep points only.

Aggregator is idempotent: rerun anytime to refresh `timings.csv` and plots
from whatever points have completed so far. Designed to work mid-sweep.

## Failure modes

| Scenario | Behaviour |
|---|---|
| A baseline DIA-NN run crashes | Downstream sweep points abort (afterok chain). User inspects `diann.log`, fixes, resubmits from the failed point onward. |
| A sweep point times out | quantmsdiann supports `-resume`, so re-running the same point picks up where it left off. User cancels downstream dependents, fixes, resubmits with `-resume` (already default in `run_local.sh`). |
| A child Nextflow task fails permanently | The Nextflow head returns non-zero → SLURM head job marked FAILED → afterok chain aborts. Same recovery as above. |
| `databases/` FASTA or SDRF missing on cluster | Submitter validates these exist at submit time and refuses to plan (consistent with `proteobench_diann_versions.sh:200`). |
| `RAW_DIR` missing or empty | Same validation, planning refuses. |
| Aggregator runs before any point completes | Emits a header-only `timings.csv` and an empty plot dir. Idempotent — rerun once data exists. |

## What this design explicitly does NOT include

- Automated cluster-side dispatch (you run `sbatch scripts/run_PXD071075_scaling.sh`
  manually after copying the repo + scripts to the cluster, same as today).
- A `make`-style entrypoint or top-level `Makefile`.
- Comparison to reference results (no correctness validation step).
- Email notifications beyond what `run_local.sh` / `run_diann.sh` already
  emit via `#SBATCH --mail-type`.
- Splitting the SDRF into smaller chunks for the smaller-core sweep points
  (the user chose to run the full 2,310-sample SDRF at every point).

## Open questions for review

1. Is the queueSize formula (`ceil(cluster_cores / 8)`) acceptable for v1,
   or do you want per-task cpus pinned in `extra.config` first to make the
   "total cores" interpretation tight?
2. Are the rough runtime estimates (~14 days end-to-end) tolerable, or
   should we drop the 10-core point to bring the total under ~1 week?
3. Should the submitter live in `scripts/` (matching
   `proteobench_diann_versions.sh`) or in `benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/`
   (closer to the artifact it produces)? Current design puts it in `scripts/`.
