#!/usr/bin/env bash
#
# Submit ONE PXD071075 sweep point with the given QUEUE_SIZE.
# Unlike run_PXD071075_scaling.sh (which chains all 7 points via afterok),
# this script does a single, standalone sbatch. Use it when you want to
# run sweep points one-at-a-time and have failures stay isolated.
#
# Usage:
#   submit_PXD071075_sweep.sh <QUEUE_SIZE> [<TIME_HOURS>]
#
#   QUEUE_SIZE   max concurrent Nextflow tasks (any positive integer)
#   TIME_HOURS   SLURM --time limit, in whole hours (default 72)
#
# Examples:
#   submit_PXD071075_sweep.sh 20             # QUEUE_SIZE=20, --time=72:00:00
#   submit_PXD071075_sweep.sh 100 12         # QUEUE_SIZE=100, --time=12:00:00
#   submit_PXD071075_sweep.sh 30 48          # QUEUE_SIZE=30, --time=48:00:00
#   DRY_RUN=1 submit_PXD071075_sweep.sh 50   # preview the sbatch line
#
# Knobs (env vars):
#   VERSION              DIA-NN version           (default 2_5_0)
#   REPO_ROOT            quantms-test-datasets checkout
#                        (default /hps/.../quantms-test-datasets)
#   RAW_DIR              source spectra dir       (default .../PXD071075-mzml)
#   BASE_RESULTS         per-point results parent (default .../quantmsdiann_results/PXD071075)
#   BASE_WORK            per-point work parent    (default .../quantmsdiann_work/PXD071075)
#   LOGS_DIR_ROOT        per-point logs parent    (default .../logs/PXD071075)
#   SCRIPTS_DIR          where run_local.sh lives (default .../scripts)
#   NXF_SINGULARITY_CACHEDIR  singularity cache  (default .../singularity)
#   DRY_RUN=1            print the sbatch line; don't submit

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    sed -n '2,/^#$/p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
fi

QUEUE_SIZE="$1"
TIME_HOURS="${2:-${TIME_HOURS:-72}}"

[[ "$QUEUE_SIZE" =~ ^[0-9]+$ ]] || { echo "ERROR: QUEUE_SIZE must be a positive integer (got: $QUEUE_SIZE)" >&2; exit 1; }
[ "$QUEUE_SIZE" -gt 0 ]         || { echo "ERROR: QUEUE_SIZE must be > 0"                            >&2; exit 1; }
[[ "$TIME_HOURS" =~ ^[0-9]+$ ]] || { echo "ERROR: TIME_HOURS must be a positive integer (got: $TIME_HOURS)" >&2; exit 1; }
[ "$TIME_HOURS" -gt 0 ]         || { echo "ERROR: TIME_HOURS must be > 0"                            >&2; exit 1; }

# Defaults (cluster paths)
VERSION="${VERSION:-2_5_0}"
REPO_ROOT="${REPO_ROOT:-/hps/nobackup/juan/pride/reanalysis/quantms-test-datasets}"
RAW_DIR="${RAW_DIR:-/hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075-mzml}"
BASE_RESULTS="${BASE_RESULTS:-/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075}"
BASE_WORK="${BASE_WORK:-/hps/nobackup/juan/pride/reanalysis/quantmsdiann_work/PXD071075}"
LOGS_DIR_ROOT="${LOGS_DIR_ROOT:-/hps/nobackup/juan/pride/reanalysis/logs/PXD071075}"
NXF_SINGULARITY_CACHEDIR="${NXF_SINGULARITY_CACHEDIR:-/hps/nobackup/juan/pride/reanalysis/singularity}"
SCRIPTS_DIR="${SCRIPTS_DIR:-/hps/nobackup/juan/pride/reanalysis/scripts}"
DRY_RUN="${DRY_RUN:-0}"

SDRF="$REPO_ROOT/benchmarks/dia/OrbitrapEclipse/PXD071075/PXD071075.sdrf.tsv"
FASTA="$REPO_ROOT/benchmarks/dia/OrbitrapEclipse/PXD071075/UP000005640_9606.fasta"

# Validate referenced paths exist (everything except DRY_RUN must be real on submit)
[ -f "$SDRF" ]   || { echo "ERROR: SDRF not found:  $SDRF"  >&2; exit 1; }
[ -f "$FASTA" ]  || { echo "ERROR: FASTA not found: $FASTA" >&2; exit 1; }
[ -d "$RAW_DIR" ] || { echo "ERROR: RAW_DIR not found: $RAW_DIR" >&2; exit 1; }
[ -f "$SCRIPTS_DIR/run_local.sh" ] || {
    echo "ERROR: run_local.sh not found at $SCRIPTS_DIR/run_local.sh" >&2
    echo "       Set SCRIPTS_DIR to the folder containing it." >&2
    exit 1
}

# Derived per-point names
PADDED=$(printf "%03d" "$QUEUE_SIZE")
POINT_ID="v${VERSION}_sweep_${PADDED}cores"
RESULTS_DIR="$BASE_RESULTS/$POINT_ID"
WORK_DIR="$BASE_WORK/$POINT_ID"
LOGS_DIR="$LOGS_DIR_ROOT/$POINT_ID"

mkdir -p "$RESULTS_DIR" "$WORK_DIR" "$LOGS_DIR" "$NXF_SINGULARITY_CACHEDIR"

echo "Point         : $POINT_ID"
echo "Version       : $VERSION"
echo "QUEUE_SIZE    : $QUEUE_SIZE  (max concurrent Nextflow tasks)"
echo "Time limit    : ${TIME_HOURS}:00:00"
echo "SDRF          : $SDRF"
echo "FASTA         : $FASTA"
echo "Raw dir       : $RAW_DIR"
echo "Work dir      : $WORK_DIR"
echo "Results dir   : $RESULTS_DIR"
echo "Logs dir      : $LOGS_DIR"
echo "Scripts dir   : $SCRIPTS_DIR"
echo "Dry-run       : $DRY_RUN"
echo

cmd=( sbatch
    --job-name="pxd071075_${POINT_ID}"
    --output="$LOGS_DIR/slurm_%j.out"
    --error="$LOGS_DIR/slurm_%j.err"
    --mem=8G
    --cpus-per-task=2
    --time="${TIME_HOURS}:00:00"
    --export="ALL,QUEUE_SIZE=$QUEUE_SIZE,SWEEP_CORES=$QUEUE_SIZE,NXF_SINGULARITY_CACHEDIR=$NXF_SINGULARITY_CACHEDIR"
    "$SCRIPTS_DIR/run_local.sh"
    "$SDRF" "$RAW_DIR" "$FASTA" "$WORK_DIR" "$RESULTS_DIR" "$VERSION"
)

if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] ${cmd[*]}"
    exit 0
fi

command -v sbatch >/dev/null 2>&1 || { echo "ERROR: sbatch not in PATH" >&2; exit 1; }
"${cmd[@]}"
