#!/usr/bin/env bash
#
# Convert all PXD071075 .raw files to .mzML on the cluster using a SLURM
# array job: ONE SLURM task per .raw file. Submit by running this script
# directly; the script then re-invokes itself via sbatch --array and the
# per-task branch does the actual ThermoRawFileParser singularity exec.
#
# Usage:
#   /hps/nobackup/juan/pride/reanalysis/scripts/convert_PXD071075_raw_to_mzml.sh
#                                                                # submit array
#   DRY_RUN=1 ./convert_PXD071075_raw_to_mzml.sh                 # preview
#   THROTTLE=50 ./convert_PXD071075_raw_to_mzml.sh               # cap concurrency
#
# Knobs (env vars):
#   RAW_DIR       source dir  (default /hps/.../raw-data/benchmarks/PXD071075)
#   MZML_DIR      target dir  (default /hps/.../raw-data/benchmarks/PXD071075-mzml)
#   TRFP_SIF      ThermoRawFileParser SIF
#   LOGS_DIR      per-task slurm logs (default /hps/.../logs/PXD071075/convert)
#   THROTTLE      cap concurrent tasks via --array=...%N  (default 50)
#   DRY_RUN=1     print the sbatch line + manifest preview; don't submit
#
# Prerequisite: ./pull_singularity_images.sh (run once to populate cache).

set -euo pipefail

# --- Defaults (cluster) -------------------------------------------------
RAW_DIR="${RAW_DIR:-/hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075}"
MZML_DIR="${MZML_DIR:-/hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075-mzml}"
TRFP_SIF="${TRFP_SIF:-/hps/nobackup/juan/pride/reanalysis/singularity/depot.galaxyproject.org-singularity-thermorawfileparser-2.0.0.dev--h9ee0642_0.img}"
LOGS_DIR="${LOGS_DIR:-/hps/nobackup/juan/pride/reanalysis/logs/PXD071075/convert}"
MANIFEST="${MANIFEST:-$MZML_DIR/.raw_manifest.txt}"
THROTTLE="${THROTTLE:-50}"
DRY_RUN="${DRY_RUN:-0}"

# ---------------------------------------------------------------------------
# Worker mode: SLURM has set SLURM_ARRAY_TASK_ID -> convert one file.
# ---------------------------------------------------------------------------
if [ -n "${SLURM_ARRAY_TASK_ID:-}" ]; then
    [ -f "$MANIFEST" ] || { echo "ERROR: manifest missing: $MANIFEST" >&2; exit 1; }
    [ -f "$TRFP_SIF" ] || { echo "ERROR: TRFP_SIF not found: $TRFP_SIF" >&2; exit 1; }
    mkdir -p "$MZML_DIR"

    # Manifest is 1-indexed; SLURM_ARRAY_TASK_ID is 1..N (we submit --array=1-N).
    raw="$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$MANIFEST")"
    [ -n "$raw" ] || { echo "ERROR: empty manifest line ${SLURM_ARRAY_TASK_ID}" >&2; exit 1; }

    base="$(basename "$raw" .raw)"
    out="$MZML_DIR/${base}.mzML"

    echo "===================================================================="
    echo "Array task   : ${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
    echo "Node         : ${SLURMD_NODENAME:-N/A}"
    echo "Input        : $raw"
    echo "Output       : $out"
    echo "TRFP image   : $TRFP_SIF"
    echo "===================================================================="

    if [ -f "$out" ] && [ -s "$out" ]; then
        echo "SKIP: $out already exists and is non-empty."
        exit 0
    fi

    singularity exec \
        --env LC_ALL=C.UTF-8 --env LANG=C.UTF-8 \
        --bind "$(dirname "$raw")":/in:ro \
        --bind "$MZML_DIR":/out \
        "$TRFP_SIF" \
        ThermoRawFileParser.sh -i="/in/$(basename "$raw")" -o=/out -f=2

    [ -f "$out" ] && [ -s "$out" ] || { echo "ERROR: $out missing or empty after conversion" >&2; exit 1; }
    echo "OK: $out ($(stat -c%s "$out") bytes)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Submitter mode: validate inputs, build manifest, submit array.
# ---------------------------------------------------------------------------
[ -d "$RAW_DIR" ]  || { echo "ERROR: RAW_DIR not found: $RAW_DIR" >&2; exit 1; }
[ -f "$TRFP_SIF" ] || { echo "ERROR: TRFP_SIF not found: $TRFP_SIF" >&2; \
    echo "       Run ./pull_singularity_images.sh first." >&2; exit 1; }

mkdir -p "$MZML_DIR" "$LOGS_DIR"

# Build a fresh manifest of every .raw file. One path per line, sorted.
find "$RAW_DIR" -maxdepth 1 -name '*.raw' -type f | sort >"$MANIFEST"
N=$(wc -l <"$MANIFEST" | tr -d ' ')

if [ "$N" -eq 0 ]; then
    echo "ERROR: no .raw files found under $RAW_DIR" >&2; exit 1
fi

# Compute how many are already converted (informational).
already=0
if [ -d "$MZML_DIR" ]; then
    while read -r raw; do
        base="$(basename "$raw" .raw)"
        if [ -f "$MZML_DIR/${base}.mzML" ] && [ -s "$MZML_DIR/${base}.mzML" ]; then
            already=$((already + 1))
        fi
    done <"$MANIFEST"
fi

echo "Raw dir       : $RAW_DIR"
echo "mzML dir      : $MZML_DIR"
echo "TRFP image    : $TRFP_SIF"
echo "Manifest      : $MANIFEST  ($N files)"
echo "Already done  : $already / $N"
echo "Logs dir      : $LOGS_DIR"
echo "Throttle      : %${THROTTLE} concurrent"
echo "Dry-run       : $DRY_RUN"
echo

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

cmd=( sbatch
    --job-name=pxd071075_raw2mzml
    --partition=standard
    --array=1-${N}%${THROTTLE}
    --output="${LOGS_DIR}/task_%A_%a.out"
    --error="${LOGS_DIR}/task_%A_%a.err"
    --time=02:00:00
    --ntasks=1
    --cpus-per-task=2
    --mem=8G
    --export=ALL,RAW_DIR="$RAW_DIR",MZML_DIR="$MZML_DIR",TRFP_SIF="$TRFP_SIF",MANIFEST="$MANIFEST"
    "$SCRIPT_PATH"
)

if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] ${cmd[*]}"
    echo "[dry-run] Manifest preview (first 5):"
    head -5 "$MANIFEST" | sed 's/^/  /'
    exit 0
fi

command -v sbatch >/dev/null 2>&1 || { echo "ERROR: sbatch not in PATH" >&2; exit 1; }
"${cmd[@]}"
