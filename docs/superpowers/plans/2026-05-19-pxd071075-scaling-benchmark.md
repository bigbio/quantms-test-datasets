# PXD071075 Scaling Benchmark — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a sequential 7-point cluster-scaling benchmark for PXD071075 (single-cell DIA, 2,310 samples): two single-node DIA-NN baselines (v1.8.1 + v2.5.0 @ 48 cpu / 300 GB / singularity) followed by a Nextflow + `pride_slurm` sweep at 10/20/50/100/200 in-flight cluster cores (v2.5.0 only), then aggregate timings + plot scaling curves.

**Architecture:** Reuse `scripts/run_diann.sh` (unchanged) for baselines and `scripts/run_local.sh` (one small `QUEUE_SIZE` env-var extension) for sweep points. A new bash submitter `scripts/run_PXD071075_scaling.sh` reads a TSV sweep matrix and chains the 7 SLURM jobs with `--dependency=afterok`. A new Python aggregator `scripts/collect_PXD071075_scaling.py` walks the per-point result directories on cluster and emits `timings.csv` + two PNG plots.

**Tech Stack:** bash 4+, SLURM (`sbatch`/`sacct`), Nextflow (`pride_slurm` profile, singularity), Python 3 (pandas, matplotlib), pytest for aggregator tests.

**Design spec:** [docs/superpowers/specs/2026-05-19-pxd071075-scaling-benchmark-design.md](../specs/2026-05-19-pxd071075-scaling-benchmark-design.md) (commit `090250b`).

**Branch:** `feat/add-PXD071075-benchmark` (already checked out).

---

## File Structure Overview

| File | Type | Purpose |
|---|---|---|
| `benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv` | NEW data | 7-row TSV — source of truth for points, read by submitter |
| `benchmarks/dia/OrbitrapEclipse/PXD071075/DESCRIPTION.md` | NEW doc | Benchmark description + sweep matrix + result paths |
| `benchmarks/dia/OrbitrapEclipse/PXD071075/run_diann_v2_5_0_PXD071075.sh` | DELETE | Redundant with `scripts/run_diann.sh` |
| `scripts/run_PXD071075_scaling.sh` | NEW bash | Top-level submitter (plan + dispatch + `DRY_RUN=1`) |
| `scripts/collect_PXD071075_scaling.py` | NEW python | Aggregator (run_metadata.json + trace.txt + `sacct` → `timings.csv` + plots) |
| `scripts/run_local.sh` | MODIFY | Honor `QUEUE_SIZE` env var → emit `queue_size.config`, write `run_metadata.json` |
| `tests/test_collect_PXD071075_scaling.py` | NEW python | pytest suite for the aggregator |
| `tests/fixtures/PXD071075/v2_5_0_sweep_050cores/run_metadata.json` | NEW fixture | Sample for aggregator |
| `tests/fixtures/PXD071075/v2_5_0_sweep_050cores/nextflow_trace.txt` | NEW fixture | Sample for aggregator |
| `tests/fixtures/PXD071075/v1_8_1_baseline_48cpu/run_metadata.json` | NEW fixture | Sample (baseline) |
| `tests/fixtures/sacct_output.txt` | NEW fixture | Sample `sacct --parsable2` output |

Working tree state today: `run_diann_v2_5_0_PXD071075.sh` is already deleted from disk but unstaged (`git status` shows ` D `). Task 3 re-stages it as a git deletion.

---

## Task 1: Create sweep matrix

**Files:**
- Create: `benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv`

- [ ] **Step 1: Create the scaling/ folder and write the TSV**

```bash
mkdir -p benchmarks/dia/OrbitrapEclipse/PXD071075/scaling
```

Write `benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv` with the following content (tab-separated, exactly 7 data rows + 1 header):

```
point_id	version	run_kind	cluster_cores	queue_size	per_job_mem_gb	head_mem_gb	cpus_per_task
v1_8_1_baseline_48cpu	1_8_1	baseline	48	0	300	0	48
v2_5_0_baseline_48cpu	2_5_0	baseline	48	0	300	0	48
v2_5_0_sweep_010cores	2_5_0	sweep	10	2	0	8	2
v2_5_0_sweep_020cores	2_5_0	sweep	20	3	0	8	2
v2_5_0_sweep_050cores	2_5_0	sweep	50	7	0	8	2
v2_5_0_sweep_100cores	2_5_0	sweep	100	13	0	8	2
v2_5_0_sweep_200cores	2_5_0	sweep	200	25	0	8	2
```

Notes:
- `queue_size = 0` for baselines means "n/a" (baselines don't use Nextflow).
- `per_job_mem_gb = 0` for sweep points means "use pipeline default" (the head wrapper only allocates `head_mem_gb`; child SLURM tasks size themselves via the pipeline's `process_*` labels).
- `cpus_per_task = 2` for sweep points is the head-process budget, mirroring `run_local.sh` line 8.
- `cpus_per_task = 48` for baselines is the fat-node `--cpus-per-task` for direct DIA-NN.

- [ ] **Step 2: Verify the TSV parses cleanly**

Run:
```bash
awk -F'\t' 'NR==1 {n=NF; print "header_cols="NF; next} NF != n {print "ROW "NR" has "NF" cols, expected "n; exit 1} END{print "rows="NR-1}' benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv
```

Expected output:
```
header_cols=8
rows=7
```

- [ ] **Step 3: Commit**

```bash
git add benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv
git commit -m "feat(PXD071075): add scaling sweep matrix (7 points)"
```

---

## Task 2: Write benchmark DESCRIPTION.md

**Files:**
- Create: `benchmarks/dia/OrbitrapEclipse/PXD071075/DESCRIPTION.md`

- [ ] **Step 1: Write the description**

Write `benchmarks/dia/OrbitrapEclipse/PXD071075/DESCRIPTION.md`:

```markdown
# PXD071075 — single-cell DIA on Orbitrap Eclipse

**PRIDE:** [PXD071075](https://www.ebi.ac.uk/pride/archive/projects/PXD071075)
**Instrument:** Thermo Orbitrap Eclipse
**Acquisition:** Label-free DIA, single-cell (FACS-sorted, ~1 cell per well)
**Samples:** 2,310
**Organism:** *Homo sapiens* (brain — neurons)
**FASTA:** [`UP000005640_9606.fasta`](UP000005640_9606.fasta) (human reference proteome, copy of `databases/shared/UP000005640_9606.fasta`)
**SDRF:** [`PXD071075.sdrf.tsv`](PXD071075.sdrf.tsv)

## Search parameters (canonical)

- Enzyme: Trypsin (`K*,R*,!*P`), missed cleavages: 2
- Modifications: Carbamidomethyl/C (fixed); Oxidation/M (variable); max-mods = 2
- Peptide length: 7–30; precursor charge: 2–4
- Precursor m/z: 400–800; fragment m/z: 200–1800
- Mass tolerances: MS1 5 ppm, MS2 10 ppm
- DIA window: 6 m/z
- q-value: 0.01; protein-group level: 2

These are encoded in `scripts/run_diann.sh` (lines 104–146) for the baseline
runs and resolved from the SDRF by the quantmsdiann pipeline for the sweep.

## Reference configs

The two reference Nextflow configs in this folder are kept for documentation —
they show the parameters used by ProteoBench-style version-comparison runs:

- [`run_PXD071075_v1_8_1.config`](run_PXD071075_v1_8_1.config) — DIA-NN 1.8.1
- [`run_PXD071075_v2_5_0.config`](run_PXD071075_v2_5_0.config) — DIA-NN 2.5.0

The scaling benchmark does **not** use these configs directly — it drives the
pipeline via `scripts/run_local.sh` (Nextflow head) and `scripts/run_diann.sh`
(direct DIA-NN) so it can vary cluster-side knobs without forking these files.

## Scaling benchmark

This benchmark also drives a 7-point scaling sweep documented in
[scaling/sweep_matrix.tsv](scaling/sweep_matrix.tsv):

| Point | Version | Kind | Cluster cores | queueSize | Notes |
|---|---|---|---|---|---|
| `v1_8_1_baseline_48cpu` | 1.8.1 | baseline | 48 | n/a | Single fat node, 300 GB, direct DIA-NN |
| `v2_5_0_baseline_48cpu` | 2.5.0 | baseline | 48 | n/a | Single fat node, 300 GB, direct DIA-NN |
| `v2_5_0_sweep_010cores` | 2.5.0 | sweep | 10 | 2 | Nextflow `pride_slurm`, queueSize = ceil(10/8) |
| `v2_5_0_sweep_020cores` | 2.5.0 | sweep | 20 | 3 | Nextflow `pride_slurm`, queueSize = ceil(20/8) |
| `v2_5_0_sweep_050cores` | 2.5.0 | sweep | 50 | 7 | Nextflow `pride_slurm`, queueSize = ceil(50/8) |
| `v2_5_0_sweep_100cores` | 2.5.0 | sweep | 100 | 13 | Nextflow `pride_slurm`, queueSize = ceil(100/8) |
| `v2_5_0_sweep_200cores` | 2.5.0 | sweep | 200 | 25 | Nextflow `pride_slurm`, queueSize = ceil(200/8) |

**queueSize formula** is `ceil(cluster_cores / 8)` where 8 ≈ cpus of the
dominant `process_medium` step in nf-core quantmsdiann. The total in-flight
core count is approximate — other `process_*` labels share the queue with
different sizings.

### How to run

From the cluster head node, after staging this repo:

```bash
# Preview the plan (no sbatch):
DRY_RUN=1 ./scripts/run_PXD071075_scaling.sh

# Submit the chain (7 sbatch calls, sequential via afterok):
./scripts/run_PXD071075_scaling.sh

# After the chain completes, aggregate + plot:
./scripts/collect_PXD071075_scaling.py
```

Result paths:
- Per-point: `/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075/<point_id>/`
- Aggregate: `/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075/timings.csv`
- Plots: `/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075/plots/`
```

- [ ] **Step 2: Commit**

```bash
git add benchmarks/dia/OrbitrapEclipse/PXD071075/DESCRIPTION.md
git commit -m "docs(PXD071075): add DESCRIPTION.md with sweep matrix overview"
```

---

## Task 3: Remove redundant docker DIA-NN script

**Files:**
- Delete: `benchmarks/dia/OrbitrapEclipse/PXD071075/run_diann_v2_5_0_PXD071075.sh`

This file is already deleted from disk but the deletion is unstaged. Re-stage it.

- [ ] **Step 1: Stage the deletion**

```bash
git rm benchmarks/dia/OrbitrapEclipse/PXD071075/run_diann_v2_5_0_PXD071075.sh
```

Expected output:
```
rm 'benchmarks/dia/OrbitrapEclipse/PXD071075/run_diann_v2_5_0_PXD071075.sh'
```

(If git reports "did not match any files", the deletion is already staged — verify with `git status` showing `D` in the index column.)

- [ ] **Step 2: Verify status**

```bash
git status --short benchmarks/dia/OrbitrapEclipse/PXD071075/
```

Expected: a `D ` (deleted, staged) line for the `.sh` file.

- [ ] **Step 3: Commit**

```bash
git commit -m "refactor(PXD071075): remove redundant docker DIA-NN runner

run_diann_v2_5_0_PXD071075.sh duplicates scripts/run_diann.sh, which
already encodes the exact PXD071075 parameter set (lines 104-146) and
defaults to singularity. The generic runner is strictly more capable
(multi-version, env-driven, SLURM-aware)."
```

---

## Task 4: Extend `scripts/run_local.sh` with `QUEUE_SIZE` support

**Files:**
- Modify: `scripts/run_local.sh:160-168` (insert next to the existing `extra.config` plumbing)
- Modify: `scripts/run_local.sh:120-134` (add `run_metadata.json` write before the `nextflow run` block)

**Goal:** When `QUEUE_SIZE` env var is set, write `$RESULTS_DIR/queue_size.config` containing `executor { queueSize = N }` and add it to the `-c` chain. Also always write `$RESULTS_DIR/run_metadata.json` so the aggregator can label sweep points.

- [ ] **Step 1: Inspect current state of run_local.sh around the integration points**

```bash
sed -n '120,170p' scripts/run_local.sh
```

You should see:
- Around line 120: the banner echo block
- Around line 163-168: the `EXTRA_CFG_ARGS=()` / `$SCRIPT_DIR/extra.config` block

- [ ] **Step 2: Write a smoke test for the new behavior**

Create `tests/test_run_local_queue_size.sh`:

```bash
#!/usr/bin/env bash
# Smoke test for the QUEUE_SIZE / run_metadata.json extension in run_local.sh.
# Extracts the relevant snippets and runs them against a temp dir, asserting
# the resulting files match expectations. Does NOT exercise nextflow itself.

set -euo pipefail

TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT

RESULTS_DIR="$TMP/results"
mkdir -p "$RESULTS_DIR"

# --- Case A: QUEUE_SIZE set ---------------------------------------------
QUEUE_SIZE=7
SWEEP_CORES=50
SLURM_JOB_ID="999"
DIANN_VERSION="2_5_0"

# Inline reproduction of the snippet that lives in run_local.sh.
# Keep in sync with the EXTRA_CFG_ARGS / metadata block.
EXTRA_CFG_ARGS=()
if [ -n "${QUEUE_SIZE:-}" ]; then
    cat >"$RESULTS_DIR/queue_size.config" <<EOF
executor { queueSize = $QUEUE_SIZE }
EOF
    EXTRA_CFG_ARGS+=( -c "$RESULTS_DIR/queue_size.config" )
fi

cat >"$RESULTS_DIR/run_metadata.json" <<EOF
{
  "dataset": "PXD071075",
  "diann_version": "$DIANN_VERSION",
  "sweep_cores": ${SWEEP_CORES:-null},
  "queue_size": ${QUEUE_SIZE:-null},
  "slurm_job_id": "${SLURM_JOB_ID:-}",
  "started_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

grep -q "queueSize = 7" "$RESULTS_DIR/queue_size.config" || { echo "FAIL: queue_size.config missing 'queueSize = 7'"; exit 1; }
grep -q '"sweep_cores": 50' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing sweep_cores"; exit 1; }
grep -q '"queue_size": 7' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing queue_size"; exit 1; }

# --- Case B: QUEUE_SIZE unset (baseline of sweep extension behaviour) ----
RESULTS_DIR_B="$TMP/results_b"
mkdir -p "$RESULTS_DIR_B"
unset QUEUE_SIZE SWEEP_CORES

EXTRA_CFG_ARGS=()
if [ -n "${QUEUE_SIZE:-}" ]; then
    cat >"$RESULTS_DIR_B/queue_size.config" <<EOF
executor { queueSize = $QUEUE_SIZE }
EOF
    EXTRA_CFG_ARGS+=( -c "$RESULTS_DIR_B/queue_size.config" )
fi

[ ! -f "$RESULTS_DIR_B/queue_size.config" ] || { echo "FAIL: queue_size.config should NOT exist when QUEUE_SIZE unset"; exit 1; }

echo "OK: queue_size + metadata smoke test passed"
```

Make it executable:
```bash
chmod +x tests/test_run_local_queue_size.sh
```

- [ ] **Step 3: Run the test — it should pass standalone (it's testing the snippet directly)**

```bash
./tests/test_run_local_queue_size.sh
```

Expected: `OK: queue_size + metadata smoke test passed`

If it fails, the snippet logic is wrong — fix in the test first since this is the spec for what we're about to add to run_local.sh.

- [ ] **Step 4: Add the QUEUE_SIZE + metadata blocks to `scripts/run_local.sh`**

In `scripts/run_local.sh`, find the existing `EXTRA_CFG_ARGS=()` block (around line 163). Replace it with the extended version. The full block now reads (find the existing `# Optional per-process resource overrides.` comment and replace through to the `fi` that closes the `extra.config` check):

```bash
# Optional per-process resource overrides. If scripts/extra.config exists
# next to this script, pass it to Nextflow via -c. Lets you bump cpu/mem
# for specific steps (e.g. INSILICO_LIBRARY_GENERATION) without editing
# this runner. Quietly skipped if the file isn't there.
EXTRA_CFG_ARGS=()
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/extra.config" ]; then
    EXTRA_CFG_ARGS=( -c "$SCRIPT_DIR/extra.config" )
    echo "Extra NF config: $SCRIPT_DIR/extra.config"
fi

# Scaling-sweep knob: if QUEUE_SIZE is set, generate a small inline
# config that caps the SLURM in-flight task count. Used by
# run_PXD071075_scaling.sh to vary cluster-core budget per sweep point.
# When unset, behaviour is identical to the historical runner.
if [ -n "${QUEUE_SIZE:-}" ]; then
    cat >"$RESULTS_DIR/queue_size.config" <<EOF
executor { queueSize = $QUEUE_SIZE }
EOF
    EXTRA_CFG_ARGS+=( -c "$RESULTS_DIR/queue_size.config" )
    echo "Queue size cfg : $RESULTS_DIR/queue_size.config (queueSize=$QUEUE_SIZE)"
fi

# Record what we're about to run so the aggregator can match results to
# sweep points later. SWEEP_CORES and QUEUE_SIZE are optional; if unset,
# null is written so the JSON is still valid.
cat >"$RESULTS_DIR/run_metadata.json" <<EOF
{
  "dataset": "PXD071075",
  "diann_version": "$DIANN_VERSION",
  "sweep_cores": ${SWEEP_CORES:-null},
  "queue_size": ${QUEUE_SIZE:-null},
  "slurm_job_id": "${SLURM_JOB_ID:-}",
  "slurm_submit_dir": "${SLURM_SUBMIT_DIR:-$PWD}",
  "started_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

Important: `$RESULTS_DIR` must exist by this point — it does (the `mkdir -p` at line 119 creates it before this block runs).

- [ ] **Step 5: Re-run the smoke test (and a syntax check of run_local.sh)**

```bash
bash -n scripts/run_local.sh && echo "run_local.sh syntax OK"
./tests/test_run_local_queue_size.sh
```

Expected:
```
run_local.sh syntax OK
OK: queue_size + metadata smoke test passed
```

- [ ] **Step 6: Commit**

```bash
git add scripts/run_local.sh tests/test_run_local_queue_size.sh
git commit -m "feat(scripts): run_local.sh honors QUEUE_SIZE + writes run_metadata.json

When QUEUE_SIZE env var is set, emit a small queue_size.config capping
executor.queueSize and chain it into the -c list. Always write
run_metadata.json so the aggregator can match results to sweep points
(dataset / version / sweep_cores / queue_size / slurm_job_id).
QUEUE_SIZE unset = behaviour unchanged."
```

---

## Task 5: Scaffold `scripts/run_PXD071075_scaling.sh` — DRY_RUN + sweep_matrix reader

**Files:**
- Create: `scripts/run_PXD071075_scaling.sh`
- Create: `tests/test_run_PXD071075_scaling.sh`

**Goal:** Implement the parts that don't require sbatch — argument parsing, sweep_matrix reading, validation, and `DRY_RUN=1` output. End of this task: `DRY_RUN=1 ./scripts/run_PXD071075_scaling.sh` prints 7 planned sbatch lines with correct env-var exports and dependency placeholders.

- [ ] **Step 1: Write the smoke test that asserts DRY_RUN output structure**

Create `tests/test_run_PXD071075_scaling.sh`:

```bash
#!/usr/bin/env bash
# Smoke test: DRY_RUN of the PXD071075 scaling submitter must print exactly
# 7 sbatch lines, with the first two using run_diann.sh, the next five
# using run_local.sh, and a dependency chain wiring them sequentially.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Stage fake raw + fasta + sdrf so the submitter's validation passes.
TMP=$(mktemp -d)
trap "rm -rf '$TMP'" EXIT
mkdir -p "$TMP/raw"
touch "$TMP/raw/example.raw"
mkdir -p "$TMP/results"
mkdir -p "$TMP/work"
mkdir -p "$TMP/logs"
mkdir -p "$TMP/singularity"

# Override every path env-var the submitter accepts:
export RAW_DIR="$TMP/raw"
export BASE_RESULTS="$TMP/results"
export BASE_WORK="$TMP/work"
export LOGS_DIR="$TMP/logs"
export NXF_SINGULARITY_CACHEDIR="$TMP/singularity"
export DRY_RUN=1

OUTPUT=$(./scripts/run_PXD071075_scaling.sh 2>&1)

echo "$OUTPUT"
echo "---"

# Assertions
echo "$OUTPUT" | grep -qE "run_diann.sh.*1_8_1"      || { echo "FAIL: missing v1_8_1 baseline (run_diann.sh)"; exit 1; }
echo "$OUTPUT" | grep -qE "run_diann.sh.*2_5_0"      || { echo "FAIL: missing v2_5_0 baseline (run_diann.sh)"; exit 1; }
echo "$OUTPUT" | grep -qE "run_local.sh.*2_5_0"      || { echo "FAIL: missing sweep points (run_local.sh)"; exit 1; }
echo "$OUTPUT" | grep -qE "QUEUE_SIZE=2"             || { echo "FAIL: missing 10-core point (QUEUE_SIZE=2)"; exit 1; }
echo "$OUTPUT" | grep -qE "QUEUE_SIZE=25"            || { echo "FAIL: missing 200-core point (QUEUE_SIZE=25)"; exit 1; }
echo "$OUTPUT" | grep -qE -- "--mem=300G"            || { echo "FAIL: baseline missing --mem=300G"; exit 1; }
echo "$OUTPUT" | grep -qE -- "--cpus-per-task=48"    || { echo "FAIL: baseline missing --cpus-per-task=48"; exit 1; }
echo "$OUTPUT" | grep -qE -- "--dependency=afterok:" || { echo "FAIL: chain missing afterok dependency"; exit 1; }

# Exactly 7 sbatch invocations
SBATCH_COUNT=$(echo "$OUTPUT" | grep -cE "^\[dry-run.*\] sbatch")
[ "$SBATCH_COUNT" -eq 7 ] || { echo "FAIL: expected 7 sbatch lines, got $SBATCH_COUNT"; exit 1; }

echo "OK: DRY_RUN produces 7 expected sbatch invocations"
```

Make it executable:
```bash
chmod +x tests/test_run_PXD071075_scaling.sh
```

- [ ] **Step 2: Run the test — it MUST fail (script doesn't exist yet)**

```bash
./tests/test_run_PXD071075_scaling.sh 2>&1 | tail -5
```

Expected: failure with "No such file or directory" or "command not found" for `./scripts/run_PXD071075_scaling.sh`.

- [ ] **Step 3: Implement `scripts/run_PXD071075_scaling.sh`**

Create `scripts/run_PXD071075_scaling.sh`:

```bash
#!/usr/bin/env bash
#SBATCH --job-name=pxd071075_scaling_submit
#SBATCH --output=/hps/nobackup/juan/pride/reanalysis/logs/PXD071075/submit_%j.out
#SBATCH --error=/hps/nobackup/juan/pride/reanalysis/logs/PXD071075/submit_%j.err
#SBATCH --partition=standard
#SBATCH --time=00:30:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G
#
# Submit the PXD071075 cluster-scaling sweep:
#   - 2 baseline points (DIA-NN direct via run_diann.sh) @ 48 cpu / 300 GB
#   - 5 sweep points (Nextflow via run_local.sh) @ queueSize ∈ {2,3,7,13,25}
# Chained sequentially with --dependency=afterok so wall-times are measured
# against a quiescent cluster.
#
# Reads sweep matrix from:
#   benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv
#
# Usage (from the cluster head, after cloning the repo):
#   ./scripts/run_PXD071075_scaling.sh              # submit
#   DRY_RUN=1 ./scripts/run_PXD071075_scaling.sh    # preview
#   sbatch     ./scripts/run_PXD071075_scaling.sh   # also fine — this script
#                                                   # is small enough to run
#                                                   # under sbatch itself
#
# Knobs (env vars):
#   REPO_ROOT, RAW_DIR, BASE_RESULTS, BASE_WORK, LOGS_DIR,
#   NXF_SINGULARITY_CACHEDIR — see defaults below.

set -euo pipefail

if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
    echo "ERROR: this script needs bash 4+ (current: ${BASH_VERSION:-unknown})." >&2
    echo "       On macOS, install one via: brew install bash" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"

# --- Paths (cluster defaults) -------------------------------------------
RAW_DIR="${RAW_DIR:-/hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075}"
BASE_RESULTS="${BASE_RESULTS:-/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075}"
BASE_WORK="${BASE_WORK:-/hps/nobackup/juan/pride/reanalysis/quantmsdiann_work/PXD071075}"
LOGS_DIR="${LOGS_DIR:-/hps/nobackup/juan/pride/reanalysis/logs/PXD071075}"
NXF_SINGULARITY_CACHEDIR="${NXF_SINGULARITY_CACHEDIR:-/hps/nobackup/juan/pride/reanalysis/singularity}"

SDRF="$REPO_ROOT/benchmarks/dia/OrbitrapEclipse/PXD071075/PXD071075.sdrf.tsv"
FASTA="$REPO_ROOT/benchmarks/dia/OrbitrapEclipse/PXD071075/UP000005640_9606.fasta"
MATRIX="$REPO_ROOT/benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv"

DRY_RUN="${DRY_RUN:-0}"

# --- Validate ------------------------------------------------------------
[ -f "$SDRF" ]   || { echo "ERROR: SDRF not found: $SDRF" >&2; exit 1; }
[ -f "$FASTA" ]  || { echo "ERROR: FASTA not found: $FASTA" >&2; exit 1; }
[ -f "$MATRIX" ] || { echo "ERROR: sweep matrix not found: $MATRIX" >&2; exit 1; }
[ -d "$RAW_DIR" ]|| { echo "ERROR: raw dir not found: $RAW_DIR" >&2; exit 1; }
[ -x "$SCRIPT_DIR/run_local.sh" ] || chmod +x "$SCRIPT_DIR/run_local.sh"
[ -x "$SCRIPT_DIR/run_diann.sh" ] || chmod +x "$SCRIPT_DIR/run_diann.sh"

if [ "$DRY_RUN" != "1" ]; then
    command -v sbatch >/dev/null 2>&1 || { echo "ERROR: sbatch not in PATH (use DRY_RUN=1 off-cluster)" >&2; exit 1; }
fi

mkdir -p "$BASE_RESULTS" "$BASE_WORK" "$LOGS_DIR" "$NXF_SINGULARITY_CACHEDIR"

# --- Read sweep matrix ---------------------------------------------------
# Columns: point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task
ROWS=()
while IFS=$'\t' read -r point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task; do
    # Skip header
    [ "$point_id" = "point_id" ] && continue
    [ -z "$point_id" ] && continue
    ROWS+=("$point_id|$version|$run_kind|$cluster_cores|$queue_size|$per_job_mem_gb|$head_mem_gb|$cpus_per_task")
done < "$MATRIX"

if [ "${#ROWS[@]}" -eq 0 ]; then
    echo "ERROR: sweep matrix has no data rows: $MATRIX" >&2; exit 1
fi

echo "Repo root      : $REPO_ROOT"
echo "Raw dir        : $RAW_DIR"
echo "SDRF           : $SDRF"
echo "FASTA          : $FASTA"
echo "Base results   : $BASE_RESULTS"
echo "Base work      : $BASE_WORK"
echo "Logs dir       : $LOGS_DIR"
echo "Sweep matrix   : $MATRIX (${#ROWS[@]} points)"
echo "Dry-run        : $DRY_RUN"
echo

# --- Plan ----------------------------------------------------------------
echo "Planning ${#ROWS[@]} sbatch submissions:"
for row in "${ROWS[@]}"; do
    IFS='|' read -r point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task <<<"$row"
    printf "  - %-30s v%-6s kind=%-8s cores=%-3s queue=%-3s mem=%sGB cpus=%s\n" \
        "$point_id" "$version" "$run_kind" "$cluster_cores" "$queue_size" \
        "$([ "$per_job_mem_gb" = "0" ] && echo "$head_mem_gb" || echo "$per_job_mem_gb")" \
        "$cpus_per_task"
done
echo

# --- Per-row sbatch builder ---------------------------------------------
write_baseline_metadata() {
    # Submitter writes run_metadata.json for baseline points so the aggregator
    # has a uniform input shape (run_local.sh writes its own for sweep points).
    local results_dir="$1" point_id="$2" version="$3" cluster_cores="$4"
    mkdir -p "$results_dir"
    cat >"$results_dir/run_metadata.json" <<EOF
{
  "dataset": "PXD071075",
  "diann_version": "$version",
  "sweep_cores": null,
  "queue_size": null,
  "cluster_cores_requested": $cluster_cores,
  "run_kind": "baseline",
  "point_id": "$point_id",
  "submitted_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Build sbatch invocation for one row. Echoes the full command on stdout.
# In dry-run mode the caller just prints it; otherwise it's executed.
build_cmd() {
    local row="$1" idx="$2" prev_jid="$3"
    IFS='|' read -r point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task <<<"$row"

    local results_dir="$BASE_RESULTS/$point_id"
    local work_dir="$BASE_WORK/$point_id"
    local log_dir="$LOGS_DIR/$point_id"
    mkdir -p "$results_dir" "$log_dir"

    local out_file="$log_dir/slurm_%j.out"
    local err_file="$log_dir/slurm_%j.err"

    local sbatch_args=( --parsable
        --job-name="pxd071075_${point_id}"
        --output="$out_file"
        --error="$err_file"
    )
    [ -n "$prev_jid" ] && sbatch_args+=( "--dependency=afterok:$prev_jid" )

    if [ "$run_kind" = "baseline" ]; then
        write_baseline_metadata "$results_dir" "$point_id" "$version" "$cluster_cores"
        sbatch_args+=(
            --mem="${per_job_mem_gb}G"
            --cpus-per-task="$cpus_per_task"
            --time=72:00:00
        )
        echo "sbatch ${sbatch_args[*]} $SCRIPT_DIR/run_diann.sh $RAW_DIR $FASTA $results_dir $version"
    else
        # Sweep: pass QUEUE_SIZE + SWEEP_CORES via --export so run_local.sh
        # picks them up (it writes run_metadata.json + queue_size.config).
        sbatch_args+=(
            --mem="${head_mem_gb}G"
            --cpus-per-task="$cpus_per_task"
            --time=168:00:00
            --export="ALL,QUEUE_SIZE=$queue_size,SWEEP_CORES=$cluster_cores"
        )
        echo "sbatch ${sbatch_args[*]} $SCRIPT_DIR/run_local.sh $SDRF $RAW_DIR $FASTA $work_dir $results_dir $version"
    fi
}

# --- Submit (or dry-run) ------------------------------------------------
SUBMITTED_IDS=()
idx=0
prev_jid=""
for row in "${ROWS[@]}"; do
    cmd=$(build_cmd "$row" "$idx" "$prev_jid")
    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry-run idx=%d%s] %s\n' "$idx" "${prev_jid:+ depends-on=$prev_jid}" "$cmd"
        prev_jid="DRY$idx"
    else
        jid=$(eval "$cmd")
        SUBMITTED_IDS+=("$jid")
        IFS='|' read -r point_id _ <<<"$row"
        printf '  submitted %-30s job %s%s\n' "$point_id" "$jid" "${prev_jid:+ (after $prev_jid)}"
        prev_jid="$jid"
    fi
    idx=$((idx + 1))
done

echo
if [ "$DRY_RUN" = "1" ]; then
    echo "Dry-run complete (no jobs submitted)."
else
    echo "Submitted ${#SUBMITTED_IDS[@]} jobs. Watch with: squeue -u \"\$USER\""
    echo "Per-point logs:     $LOGS_DIR/<point_id>/slurm_<jobid>.{out,err}"
    echo "Per-point results:  $BASE_RESULTS/<point_id>/"
    echo "Aggregate after:    $SCRIPT_DIR/collect_PXD071075_scaling.py"
fi
```

Make it executable:
```bash
chmod +x scripts/run_PXD071075_scaling.sh
```

- [ ] **Step 4: Run the smoke test — must pass**

```bash
bash -n scripts/run_PXD071075_scaling.sh && echo "syntax OK"
./tests/test_run_PXD071075_scaling.sh
```

Expected last line: `OK: DRY_RUN produces 7 expected sbatch invocations`

- [ ] **Step 5: Verify the DRY_RUN output by eye**

```bash
DRY_RUN=1 RAW_DIR=/tmp/fake_raw BASE_RESULTS=/tmp/fake_results \
    BASE_WORK=/tmp/fake_work LOGS_DIR=/tmp/fake_logs \
    NXF_SINGULARITY_CACHEDIR=/tmp/fake_singularity \
    bash -c 'mkdir -p /tmp/fake_raw && touch /tmp/fake_raw/x.raw && ./scripts/run_PXD071075_scaling.sh' 2>&1 | head -30
```

Sanity-check:
- Two `run_diann.sh` lines come first (1_8_1, then 2_5_0)
- Five `run_local.sh` lines follow with `QUEUE_SIZE=2,3,7,13,25`
- Lines 2-7 have `--dependency=afterok:DRY<n>`

- [ ] **Step 6: Commit**

```bash
git add scripts/run_PXD071075_scaling.sh tests/test_run_PXD071075_scaling.sh
git commit -m "feat(scripts): add PXD071075 scaling sweep submitter

Reads sweep_matrix.tsv and chains 2 baseline (run_diann.sh) +
5 Nextflow sweep (run_local.sh) points via sbatch --dependency=afterok.
Writes run_metadata.json for baseline points before submission so the
aggregator has uniform input shape across baseline + sweep results.
DRY_RUN=1 prints planned sbatch lines without submitting."
```

---

## Task 6: Aggregator scaffolding + metadata reader (TDD)

**Files:**
- Create: `scripts/collect_PXD071075_scaling.py`
- Create: `tests/test_collect_PXD071075_scaling.py`
- Create: `tests/fixtures/PXD071075/v2_5_0_sweep_050cores/run_metadata.json`
- Create: `tests/fixtures/PXD071075/v1_8_1_baseline_48cpu/run_metadata.json`

**Goal:** Aggregator can read a `$BASE_RESULTS/PXD071075/` directory tree and identify each point with its metadata. No trace/sacct parsing yet — just discovery.

- [ ] **Step 1: Write fixture metadata files**

Create `tests/fixtures/PXD071075/v2_5_0_sweep_050cores/run_metadata.json`:

```json
{
  "dataset": "PXD071075",
  "diann_version": "2_5_0",
  "sweep_cores": 50,
  "queue_size": 7,
  "slurm_job_id": "12345",
  "slurm_submit_dir": "/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075/v2_5_0_sweep_050cores",
  "started_at_utc": "2026-05-19T10:00:00Z"
}
```

Create `tests/fixtures/PXD071075/v1_8_1_baseline_48cpu/run_metadata.json`:

```json
{
  "dataset": "PXD071075",
  "diann_version": "1_8_1",
  "sweep_cores": null,
  "queue_size": null,
  "cluster_cores_requested": 48,
  "run_kind": "baseline",
  "point_id": "v1_8_1_baseline_48cpu",
  "submitted_at_utc": "2026-05-19T09:00:00Z"
}
```

- [ ] **Step 2: Write the failing test for `discover_points()`**

Create `tests/test_collect_PXD071075_scaling.py`:

```python
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
```

- [ ] **Step 3: Run the test — it must fail (script doesn't exist)**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -10
```

Expected: `ModuleNotFoundError: No module named 'collect_PXD071075_scaling'`.

- [ ] **Step 4: Implement the minimal aggregator scaffold**

Create `scripts/collect_PXD071075_scaling.py`:

```python
#!/usr/bin/env python3
"""Collect and plot timings for the PXD071075 cluster-scaling sweep.

Walks per-point result directories under $BASE_RESULTS/PXD071075/, reads each
point's run_metadata.json + Nextflow trace.txt (or DIA-NN log for baselines)
+ sacct output, and emits:

  timings.csv           — one row per point
  plots/cores_vs_walltime.png
  plots/cores_vs_speedup.png

Usage:
  ./scripts/collect_PXD071075_scaling.py [--base-results <dir>] [--no-plot]

Idempotent — rerun anytime to refresh from whatever points have completed.
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
```

Make it executable:
```bash
chmod +x scripts/collect_PXD071075_scaling.py
```

- [ ] **Step 5: Run the test — must pass**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -10
```

Expected: all 3 tests pass.

- [ ] **Step 6: Run the CLI against fixtures for a sanity check**

```bash
./scripts/collect_PXD071075_scaling.py --base-results tests/fixtures/PXD071075 --no-plot
```

Expected:
```
Discovered 2 point(s) under tests/fixtures/PXD071075
  - v1_8_1_baseline_48cpu          kind=baseline  v1_8_1
  - v2_5_0_sweep_050cores          kind=sweep     v2_5_0
```

- [ ] **Step 7: Commit**

```bash
git add scripts/collect_PXD071075_scaling.py tests/test_collect_PXD071075_scaling.py tests/fixtures/
git commit -m "feat(scripts): scaffold PXD071075 scaling aggregator + tests

Adds collect_PXD071075_scaling.py with discover_points() that walks the
per-point results tree and loads each run_metadata.json. Pytest suite
with baseline + sweep metadata fixtures."
```

---

## Task 7: Aggregator — parse Nextflow trace.txt (TDD)

**Files:**
- Modify: `scripts/collect_PXD071075_scaling.py`
- Modify: `tests/test_collect_PXD071075_scaling.py`
- Create: `tests/fixtures/PXD071075/v2_5_0_sweep_050cores/nextflow_trace.txt`

**Goal:** Extract `tasks_submitted`, `tasks_succeeded`, `nextflow_walltime_s`, `peak_mem_gb`, `total_cpu_s` from a Nextflow trace. (For baselines, trace.txt is absent — we'll handle that in a later task.)

Nextflow trace.txt format reference:
```
task_id	hash	native_id	name	status	exit	submit	duration	realtime	%cpu	peak_rss	peak_vmem	rchar	wchar
1	a1/abc	1234	DIA:INSILICO	COMPLETED	0	2026-05-19 10:00:00.000	5min	4min 50s	120%	8.5 GB	-	-	-
```

- [ ] **Step 1: Write the trace fixture**

Create `tests/fixtures/PXD071075/v2_5_0_sweep_050cores/nextflow_trace.txt`:

```
task_id	hash	native_id	name	status	exit	submit	duration	realtime	%cpu	peak_rss	peak_vmem	rchar	wchar
1	aa/aaaaaa	1001	NFCORE_QUANTMSDIANN:DIA:INSILICO_LIBRARY_GENERATION	COMPLETED	0	2026-05-19 10:00:00.000	10min	9min 30s	380%	24.2 GB	-	-	-
2	bb/bbbbbb	1002	NFCORE_QUANTMSDIANN:DIA:INDIVIDUAL_ANALYSIS (sample_001)	COMPLETED	0	2026-05-19 10:10:00.000	3min	2min 50s	160%	4.1 GB	-	-	-
3	cc/cccccc	1003	NFCORE_QUANTMSDIANN:DIA:INDIVIDUAL_ANALYSIS (sample_002)	COMPLETED	0	2026-05-19 10:13:00.000	3min 30s	3min 20s	180%	4.3 GB	-	-	-
4	dd/dddddd	1004	NFCORE_QUANTMSDIANN:DIA:ASSEMBLE_EMPIRICAL_LIBRARY	COMPLETED	0	2026-05-19 10:16:30.000	15min	14min 40s	220%	18.7 GB	-	-	-
5	ee/eeeeee	1005	NFCORE_QUANTMSDIANN:DIA:FINAL_QUANTIFICATION	FAILED	1	2026-05-19 10:31:30.000	2min	1min 50s	100%	2.0 GB	-	-	-
```

Note: 4 COMPLETED + 1 FAILED, peak across all rows = 24.2 GB, sum of realtime durations = 9:30 + 2:50 + 3:20 + 14:40 + 1:50 = 32:30.

- [ ] **Step 2: Add failing tests for `parse_nextflow_trace()`**

Append to `tests/test_collect_PXD071075_scaling.py`:

```python


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
```

- [ ] **Step 3: Run tests — they must fail**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -15
```

Expected: `AttributeError: module 'collect_PXD071075_scaling' has no attribute 'parse_nextflow_trace'`.

- [ ] **Step 4: Implement `parse_nextflow_trace()`**

Add to `scripts/collect_PXD071075_scaling.py` (above `main()`):

```python
import re

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
    """Parse '24.2 GB' / '512 MB' / '-' → GB float."""
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
    Missing file → zero counters (lets us run mid-sweep).
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
```

- [ ] **Step 5: Run tests — all must pass**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -10
```

Expected: 7 tests pass (3 discover + 4 trace).

- [ ] **Step 6: Commit**

```bash
git add scripts/collect_PXD071075_scaling.py tests/test_collect_PXD071075_scaling.py tests/fixtures/PXD071075/v2_5_0_sweep_050cores/nextflow_trace.txt
git commit -m "feat(scripts): aggregator parses nextflow trace.txt

Adds parse_nextflow_trace() — extracts tasks_submitted/succeeded/failed,
peak_mem_gb (max peak_rss across rows), total_cpu_s (sum of realtime).
Handles Nextflow duration strings (Xd Xh Xmin Xs) and memory units
(KB/MB/GB/TB). Missing trace → zero counters so the aggregator works
mid-sweep."
```

---

## Task 8: Aggregator — parse `sacct` output (TDD)

**Files:**
- Modify: `scripts/collect_PXD071075_scaling.py`
- Modify: `tests/test_collect_PXD071075_scaling.py`

**Goal:** Given a SLURM job id, run `sacct -j <jid> --format=Elapsed,CPUTime,MaxRSS --parsable2` and parse the output. Mock `subprocess.run` in tests.

`sacct --parsable2` sample output (pipe-separated, head row + per-step rows; the parent row has the rollup):
```
Elapsed|CPUTime|MaxRSS
01:23:45|01:23:45|
01:23:45|01:23:45|8388608K
```

- [ ] **Step 1: Add a sacct fixture string + failing tests**

Append to `tests/test_collect_PXD071075_scaling.py`:

```python
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
    # MaxRSS 8388608K = 8 GiB ≈ 8.0 GB
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
```

- [ ] **Step 2: Run tests — must fail (no `parse_sacct_output` / `run_sacct`)**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -15
```

Expected: `AttributeError` for both `parse_sacct_output` and `run_sacct`.

- [ ] **Step 3: Implement both functions**

Add to `scripts/collect_PXD071075_scaling.py` (above `main()`):

```python
import subprocess


_HMS_RE = re.compile(r"^(?:(\d+)-)?(\d+):(\d+):(\d+)(?:\.\d+)?$")


def _hms_to_seconds(text: str) -> int:
    """SLURM HH:MM:SS or D-HH:MM:SS → seconds."""
    text = (text or "").strip()
    if not text:
        return 0
    match = _HMS_RE.match(text)
    if not match:
        return 0
    days, h, m, s = match.groups(default="0")
    return int(days or 0) * 86400 + int(h) * 3600 + int(m) * 60 + int(s)


def _rss_to_gb(text: str) -> float:
    """SLURM MaxRSS like '8388608K' / '8G' / '' → GB."""
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
```

- [ ] **Step 4: Run tests — all must pass**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -10
```

Expected: 12 tests pass (3 discover + 4 trace + 5 sacct).

- [ ] **Step 5: Commit**

```bash
git add scripts/collect_PXD071075_scaling.py tests/test_collect_PXD071075_scaling.py
git commit -m "feat(scripts): aggregator parses sacct output for SLURM metrics

run_sacct() invokes 'sacct -j <jid> --format=Elapsed,CPUTime,MaxRSS
--parsable2' and parses the rows; parse_sacct_output() is the pure
parser. Handles SLURM time formats (HH:MM:SS / D-HH:MM:SS) and RSS
units (K/M/G/T). Returns zeros when sacct is missing so the aggregator
runs off-cluster against fixtures."
```

---

## Task 9: Aggregator — assemble timings DataFrame + write CSV (TDD)

**Files:**
- Modify: `scripts/collect_PXD071075_scaling.py`
- Modify: `tests/test_collect_PXD071075_scaling.py`

**Goal:** Walk discovered points, parse each one's trace + sacct output, emit a `pandas.DataFrame` with the schema from the spec, write it to `<base_results>/timings.csv`.

- [ ] **Step 1: Add failing tests for `assemble_timings()`**

Append to `tests/test_collect_PXD071075_scaling.py`:

```python


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
    # Fixture trace has 4 succeeded + 1 failed → PARTIAL
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
```

- [ ] **Step 2: Run tests — must fail (no `assemble_timings` / `write_timings_csv` / `SDRF_SAMPLES`)**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -15
```

- [ ] **Step 3: Implement `assemble_timings()` + `write_timings_csv()` + `SDRF_SAMPLES`**

Add to `scripts/collect_PXD071075_scaling.py` (above `main()`; add `import pandas as pd` at the top):

```python
import pandas as pd

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

        trace_summary = parse_nextflow_trace(path / "nextflow_trace.txt")
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
                "nextflow_walltime_s": total_cpu if run_kind == "sweep" else None,
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
```

Update `main()` to actually call these:

```python
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
    return 0
```

- [ ] **Step 4: Run tests — all must pass**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -15
```

Expected: 16 tests pass.

- [ ] **Step 5: Run aggregator end-to-end against the fixtures**

```bash
./scripts/collect_PXD071075_scaling.py --base-results tests/fixtures/PXD071075 --no-plot
cat tests/fixtures/PXD071075/timings.csv
```

Expected: a 2-row CSV with the expected schema. The baseline row's `exit_status` will be `FAIL` because `slurm_walltime_s=0` (no sacct available without real SLURM); that's expected for fixture data. Delete the fixture CSV after to keep tests clean:

```bash
rm tests/fixtures/PXD071075/timings.csv
```

- [ ] **Step 6: Commit**

```bash
git add scripts/collect_PXD071075_scaling.py tests/test_collect_PXD071075_scaling.py
git commit -m "feat(scripts): aggregator emits timings.csv

assemble_timings() composes per-point metadata + trace summary + sacct
metrics into a DataFrame with the schema from the design spec.
write_timings_csv() persists to <base>/timings.csv. main() wires it
end-to-end and prints the DataFrame to stdout."
```

---

## Task 10: Aggregator — scaling plots (TDD)

**Files:**
- Modify: `scripts/collect_PXD071075_scaling.py`
- Modify: `tests/test_collect_PXD071075_scaling.py`

**Goal:** Two PNGs — `cores_vs_walltime.png` (log-log: x=cluster_cores, y=walltime, with both baselines as separate markers at x=48) and `cores_vs_speedup.png` (linear: x=cluster_cores, y=t_200/t, with an ideal-scaling reference line). Sweep-only for speedup.

- [ ] **Step 1: Add failing tests for `plot_scaling()`**

Append to `tests/test_collect_PXD071075_scaling.py`:

```python


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
    # Only baselines → walltime plot still drawn, speedup plot is a stub.
    df = _fake_timings_df().head(2)
    plots_dir = tmp_path / "plots"
    agg.plot_scaling(df, plots_dir)
    assert (plots_dir / "cores_vs_walltime.png").is_file()
    assert (plots_dir / "cores_vs_speedup.png").is_file()
```

- [ ] **Step 2: Run tests — must fail (no `plot_scaling`)**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -10
```

- [ ] **Step 3: Implement `plot_scaling()`**

Add to `scripts/collect_PXD071075_scaling.py` (above `main()`; add `import matplotlib` setup at the top, before importing `pyplot`, so it works headless):

```python
import matplotlib
matplotlib.use("Agg")  # headless — no display required on the cluster
import matplotlib.pyplot as plt


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
        # Ideal linear scaling: speedup ∝ cores / ref_cores
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
```

Update `main()` to call `plot_scaling()` when `--no-plot` is not set:

```python
    if not args.no_plot:
        plots_dir = args.base_results / "plots"
        plot_scaling(df, plots_dir)
        print(f"Wrote plots to {plots_dir}/")
    return 0
```

- [ ] **Step 4: Run tests — all must pass**

```bash
pytest tests/test_collect_PXD071075_scaling.py -v 2>&1 | tail -15
```

Expected: 18 tests pass.

- [ ] **Step 5: Smoke-test the plot generation end-to-end against fixtures**

```bash
./scripts/collect_PXD071075_scaling.py --base-results tests/fixtures/PXD071075
ls tests/fixtures/PXD071075/plots/ 2>&1
rm -rf tests/fixtures/PXD071075/plots/ tests/fixtures/PXD071075/timings.csv
```

Expected: `cores_vs_walltime.png` and `cores_vs_speedup.png` produced. (Then clean up so fixtures stay clean.)

- [ ] **Step 6: Commit**

```bash
git add scripts/collect_PXD071075_scaling.py tests/test_collect_PXD071075_scaling.py
git commit -m "feat(scripts): aggregator renders scaling plots

plot_scaling() writes two headless PNGs:
- cores_vs_walltime.png — log-log scatter, both baselines marked separately
  from the v2.5.0 sweep curve
- cores_vs_speedup.png  — speedup relative to the largest-core sweep point,
  with an ideal-linear-scaling reference line

Handles edge cases: fewer than 2 sweep points → speedup plot is a stub."
```

---

## Task 11: End-to-end DRY_RUN integration check + final touches

**Files:**
- (no new files; verification only)

**Goal:** Run every test, then a full DRY_RUN of the submitter, to confirm the wired-up system is self-consistent before handing off.

- [ ] **Step 1: Run the full test suite**

```bash
pytest tests/ -v 2>&1 | tail -25
./tests/test_run_local_queue_size.sh
./tests/test_run_PXD071075_scaling.sh
```

All three commands must end with success / OK / passed.

- [ ] **Step 2: Run a manual DRY_RUN and eyeball the planned commands**

```bash
mkdir -p /tmp/sb_test/raw && touch /tmp/sb_test/raw/x.raw
DRY_RUN=1 \
    RAW_DIR=/tmp/sb_test/raw \
    BASE_RESULTS=/tmp/sb_test/results \
    BASE_WORK=/tmp/sb_test/work \
    LOGS_DIR=/tmp/sb_test/logs \
    NXF_SINGULARITY_CACHEDIR=/tmp/sb_test/singularity \
    ./scripts/run_PXD071075_scaling.sh 2>&1 | tee /tmp/sb_test/dry_run.txt
rm -rf /tmp/sb_test
```

Verify by eye:
- Line 1-2: `run_diann.sh` for `1_8_1` then `2_5_0`, both with `--mem=300G --cpus-per-task=48`
- Line 2 has `--dependency=afterok:DRY0`
- Lines 3-7: `run_local.sh` with `QUEUE_SIZE=2,3,7,13,25` in order
- Each subsequent line includes `--dependency=afterok:DRY<prev>`

- [ ] **Step 3: Verify the design spec coverage**

Re-read [docs/superpowers/specs/2026-05-19-pxd071075-scaling-benchmark-design.md](../specs/2026-05-19-pxd071075-scaling-benchmark-design.md) and check each section is implemented:

| Spec section | Status |
|---|---|
| §File layout (in-repo) | ✓ sweep_matrix.tsv, DESCRIPTION.md, both scripts, tests |
| §File layout (on-cluster) | ✓ submitter mkdir -p's BASE_RESULTS / BASE_WORK / LOGS_DIR |
| §Sweep matrix | ✓ data file in benchmark folder |
| §Dependency chain (afterok) | ✓ build_cmd() adds --dependency=afterok |
| §run_local.sh extension | ✓ QUEUE_SIZE → queue_size.config; run_metadata.json always |
| §run_diann.sh — no source changes | ✓ untouched |
| §Submitter writes baseline run_metadata.json | ✓ write_baseline_metadata() before sbatch |
| §Aggregator schema | ✓ test_assemble_timings_columns asserts column set |
| §Plots | ✓ plot_scaling() |
| §Failure modes | ✓ aggregator handles missing trace / no sacct |

If anything is missing, add a remediation task before continuing.

- [ ] **Step 4: Final commit (if any uncommitted polish)**

```bash
git status --short
# If anything is dirty:
git add -p
git commit -m "chore(PXD071075): final polish for scaling benchmark"
```

- [ ] **Step 5: Push the branch and open PR**

```bash
git push -u origin feat/add-PXD071075-benchmark
gh pr create --title "feat(PXD071075): scaling benchmark harness" --body "$(cat <<'EOF'
## Summary
- Adds a 7-point scaling benchmark for PXD071075 (single-cell DIA, 2,310 samples): 2 single-node DIA-NN baselines (v1.8.1 + v2.5.0 @ 48 cpu / 300 GB) + 5 Nextflow sweep points at 10/20/50/100/200 in-flight cluster cores (v2.5.0 only).
- New `scripts/run_PXD071075_scaling.sh` submitter chains 7 sbatch jobs via `--dependency=afterok`; reads from `benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv`.
- New `scripts/collect_PXD071075_scaling.py` aggregator walks the on-cluster results tree → `timings.csv` + cores-vs-walltime / cores-vs-speedup plots.
- `scripts/run_local.sh` gains a small `QUEUE_SIZE` env-var extension (emits `queue_size.config` capping `executor.queueSize`) and always writes `run_metadata.json` for the aggregator.
- Removes the now-redundant `benchmarks/dia/OrbitrapEclipse/PXD071075/run_diann_v2_5_0_PXD071075.sh` (duplicates `scripts/run_diann.sh`).

## Test plan
- [ ] `pytest tests/` — aggregator unit tests pass
- [ ] `./tests/test_run_local_queue_size.sh` — run_local.sh snippet smoke test passes
- [ ] `./tests/test_run_PXD071075_scaling.sh` — submitter DRY_RUN smoke test passes
- [ ] On cluster: `DRY_RUN=1 ./scripts/run_PXD071075_scaling.sh` previews 7 sbatch lines with correct memory / cpu / QUEUE_SIZE / afterok chain
- [ ] On cluster: submit the chain, monitor with `squeue -u $USER`, then run aggregator after first sweep point completes — verify CSV + plots are reasonable mid-sweep
EOF
)"
```

Note: don't push or open a PR until the user explicitly approves. This step is documented for completeness; pause for the user before executing.

---

## Self-review notes

**Spec coverage:** Every section of the design spec maps to a task. The submitter's `write_baseline_metadata()` (task 5) covers the post-self-review fix to keep `run_diann.sh` untouched.

**Placeholder scan:** No "TBD" / "TODO" / "implement later" / "similar to" / "appropriate error handling" anywhere in the plan. All code is fully specified.

**Type consistency:** `discover_points()` returns `list[dict]` with keys `point_id` / `path` / `metadata` / `run_kind`; every downstream function uses those exact keys. `parse_nextflow_trace()` returns the same 5-key dict in every code path (including the empty case). `parse_sacct_output()` and `run_sacct()` return the same 3-key dict. `assemble_timings()` produces a DataFrame whose columns match the schema asserted in `test_assemble_timings_columns`.

**Scope:** 11 tasks, each independently committable. Tests are written before implementation in every task that produces logic (tasks 4, 5, 6, 7, 8, 9, 10). Tasks 1-3 are pure data/cleanup and have validation steps but no formal tests.
