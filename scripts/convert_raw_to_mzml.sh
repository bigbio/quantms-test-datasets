#!/usr/bin/env bash
#
# Convert every .raw file in a folder to .mzML on the cluster using a
# SLURM array job: ONE SLURM task per .raw file. Submit by running the
# script directly; it re-invokes itself via sbatch --array, and the
# per-task branch does the ThermoRawFileParser singularity exec.
#
# Usage:
#   convert_raw_to_mzml.sh <RAW_DIR> [<MZML_DIR>]
#
#   RAW_DIR    folder containing *.raw files (required)
#   MZML_DIR   target folder for the *.mzML output
#              (default: <RAW_DIR>-mzml — e.g. /path/PXD071075 -> /path/PXD071075-mzml)
#
# Examples:
#   convert_raw_to_mzml.sh /hps/.../raw-data/benchmarks/PXD071075
#   convert_raw_to_mzml.sh /tmp/run17/raw /tmp/run17/mzml
#   DRY_RUN=1 convert_raw_to_mzml.sh /tmp/run17/raw     # preview, no submit
#   THROTTLE=20 convert_raw_to_mzml.sh /tmp/run17/raw   # cap concurrent tasks
#
# Knobs (env vars):
#   TRFP_SIF      ThermoRawFileParser SIF
#                 (default: $NXF_SINGULARITY_CACHEDIR/depot.galaxyproject.org-singularity-thermorawfileparser-2.0.0.dev--h9ee0642_0.img)
#   NXF_SINGULARITY_CACHEDIR  used to resolve TRFP_SIF if TRFP_SIF unset
#                             (default /hps/nobackup/juan/pride/reanalysis/singularity)
#   LOGS_DIR      per-task slurm logs (default <MZML_DIR>/.convert_logs)
#   MANIFEST      manifest file path  (default <MZML_DIR>/.raw_manifest.txt)
#   JOB_NAME      sbatch --job-name   (default raw2mzml_<basename of RAW_DIR>)
#   THROTTLE      cap concurrent tasks via --array=...%N  (default 50)
#   TIME_LIMIT    per-task --time     (default 02:00:00)
#   CPUS_PER_TASK per-task --cpus-per-task (default 2)
#   MEM_PER_TASK  per-task --mem      (default 8G)
#   DRY_RUN=1     print sbatch line + manifest preview; don't submit
#
# Prerequisite: ./pull_singularity_images.sh (run once to populate cache).

set -euo pipefail

# --- Worker mode -------------------------------------------------------
# SLURM has set SLURM_ARRAY_TASK_ID -> convert one file from MANIFEST.
# (RAW_DIR / MZML_DIR / TRFP_SIF / MANIFEST are passed in via --export=ALL,...)
if [ -n "${SLURM_ARRAY_TASK_ID:-}" ]; then
    : "${MANIFEST:?MANIFEST not exported by submitter}"
    : "${TRFP_SIF:?TRFP_SIF not exported by submitter}"
    : "${MZML_DIR:?MZML_DIR not exported by submitter}"
    [ -f "$MANIFEST" ] || { echo "ERROR: manifest missing: $MANIFEST" >&2; exit 1; }
    [ -f "$TRFP_SIF" ] || { echo "ERROR: TRFP_SIF not found: $TRFP_SIF" >&2; exit 1; }
    mkdir -p "$MZML_DIR"

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
        thermorawfileparser -i="/in/$(basename "$raw")" -o=/out -f=2

    [ -f "$out" ] && [ -s "$out" ] || { echo "ERROR: $out missing or empty after conversion" >&2; exit 1; }
    echo "OK: $out ($(stat -c%s "$out") bytes)"
    exit 0
fi

# --- Submitter mode ----------------------------------------------------
# Arguments: <RAW_DIR> [<MZML_DIR>]
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    sed -n '2,/^#$/p' "$0" | sed 's/^# \{0,1\}//'  # print the leading comment as help
    exit 1
fi

RAW_DIR="$(cd "$1" && pwd)"   # absolutise so the manifest contains absolute paths
MZML_DIR="${2:-${RAW_DIR%/}-mzml}"

# Defaults that depend on the input folder:
DEFAULT_JOB_NAME="raw2mzml_$(basename "$RAW_DIR")"
JOB_NAME="${JOB_NAME:-$DEFAULT_JOB_NAME}"
LOGS_DIR="${LOGS_DIR:-$MZML_DIR/.convert_logs}"
MANIFEST="${MANIFEST:-$MZML_DIR/.raw_manifest.txt}"

# Singularity image resolution: prefer explicit TRFP_SIF, else fall back to
# the canonical cache file inside NXF_SINGULARITY_CACHEDIR.
NXF_SINGULARITY_CACHEDIR="${NXF_SINGULARITY_CACHEDIR:-/hps/nobackup/juan/pride/reanalysis/singularity}"
TRFP_SIF="${TRFP_SIF:-$NXF_SINGULARITY_CACHEDIR/depot.galaxyproject.org-singularity-thermorawfileparser-2.0.0.dev--h9ee0642_0.img}"

# Per-task SLURM defaults (overridable):
THROTTLE="${THROTTLE:-50}"
TIME_LIMIT="${TIME_LIMIT:-02:00:00}"
CPUS_PER_TASK="${CPUS_PER_TASK:-2}"
MEM_PER_TASK="${MEM_PER_TASK:-8G}"
DRY_RUN="${DRY_RUN:-0}"

[ -d "$RAW_DIR" ]  || { echo "ERROR: RAW_DIR not found: $RAW_DIR" >&2; exit 1; }
[ -f "$TRFP_SIF" ] || { echo "ERROR: TRFP_SIF not found: $TRFP_SIF" >&2; \
    echo "       Run ./pull_singularity_images.sh first (or set TRFP_SIF=...)." >&2; exit 1; }

mkdir -p "$MZML_DIR" "$LOGS_DIR"

# Build a fresh manifest of every .raw file.
find "$RAW_DIR" -maxdepth 1 -name '*.raw' -type f | sort >"$MANIFEST"
N=$(wc -l <"$MANIFEST" | tr -d ' ')

if [ "$N" -eq 0 ]; then
    echo "ERROR: no .raw files found under $RAW_DIR" >&2; exit 1
fi

# Informational: count of already-converted files.
already=0
while read -r raw; do
    base="$(basename "$raw" .raw)"
    if [ -f "$MZML_DIR/${base}.mzML" ] && [ -s "$MZML_DIR/${base}.mzML" ]; then
        already=$((already + 1))
    fi
done <"$MANIFEST"

echo "Raw dir       : $RAW_DIR"
echo "mzML dir      : $MZML_DIR"
echo "Job name      : $JOB_NAME"
echo "TRFP image    : $TRFP_SIF"
echo "Manifest      : $MANIFEST  ($N files)"
echo "Already done  : $already / $N"
echo "Logs dir      : $LOGS_DIR"
echo "Throttle      : %${THROTTLE} concurrent"
echo "Time / task   : $TIME_LIMIT  (${CPUS_PER_TASK} cpu, ${MEM_PER_TASK})"
echo "Dry-run       : $DRY_RUN"
echo

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

cmd=( sbatch
    --job-name="$JOB_NAME"
    --partition=standard
    --array="1-${N}%${THROTTLE}"
    --output="${LOGS_DIR}/task_%A_%a.out"
    --error="${LOGS_DIR}/task_%A_%a.err"
    --time="$TIME_LIMIT"
    --ntasks=1
    --cpus-per-task="$CPUS_PER_TASK"
    --mem="$MEM_PER_TASK"
    --export="ALL,RAW_DIR=$RAW_DIR,MZML_DIR=$MZML_DIR,TRFP_SIF=$TRFP_SIF,MANIFEST=$MANIFEST"
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
