#!/usr/bin/env bash
#SBATCH --job-name=pxd071075_raw2mzml
#SBATCH --output=/hps/nobackup/juan/pride/reanalysis/logs/PXD071075/convert_%j.out
#SBATCH --error=/hps/nobackup/juan/pride/reanalysis/logs/PXD071075/convert_%j.err
#SBATCH --partition=standard
#SBATCH --time=48:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=12
#SBATCH --mem=96G
#
# One-time .raw -> .mzML conversion for PXD071075 (2,310 files) using
# ThermoRawFileParser. Produces an mzML directory that DIA-NN 1.8.1 can
# read (its bundled Thermo reader rejects the 2024 Eclipse .raw files).
#
# Usage:
#   sbatch /hps/nobackup/juan/pride/reanalysis/scripts/convert_PXD071075_raw_to_mzml.sh
#
# Knobs (env vars):
#   RAW_DIR       source dir   (default: /hps/.../raw-data/benchmarks/PXD071075)
#   MZML_DIR      target dir   (default: /hps/.../raw-data/benchmarks/PXD071075-mzml)
#   TRFP_SIF      ThermoRawFileParser SIF
#                 (default: /hps/.../singularity/depot.galaxyproject.org-singularity-thermorawfileparser-2.0.0.dev--h9ee0642_0.img)
#   PARALLEL_N    parallel conversions (default: 12 = SBATCH cap)
#
# Idempotent: files whose mzML output already exists are skipped.

set -euo pipefail

RAW_DIR="${RAW_DIR:-/hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075}"
MZML_DIR="${MZML_DIR:-/hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075-mzml}"
TRFP_SIF="${TRFP_SIF:-/hps/nobackup/juan/pride/reanalysis/singularity/depot.galaxyproject.org-singularity-thermorawfileparser-2.0.0.dev--h9ee0642_0.img}"
PARALLEL_N="${PARALLEL_N:-${SLURM_CPUS_PER_TASK:-12}}"

[ -d "$RAW_DIR" ]  || { echo "ERROR: RAW_DIR not found: $RAW_DIR" >&2; exit 1; }
[ -f "$TRFP_SIF" ] || { echo "ERROR: TRFP_SIF not found: $TRFP_SIF" >&2; exit 1; }
mkdir -p "$MZML_DIR"

echo "===================================================================="
echo "SLURM job   : ${SLURM_JOB_ID:-(interactive)}  node=${SLURMD_NODENAME:-N/A}"
echo "RAW dir     : $RAW_DIR"
echo "mzML dir    : $MZML_DIR"
echo "TRFP image  : $TRFP_SIF"
echo "Parallel    : $PARALLEL_N"
echo "===================================================================="

convert_one() {
    local raw="$1"
    local base
    base=$(basename "$raw" .raw)
    local out="$MZML_DIR/${base}.mzML"
    if [ -f "$out" ] && [ -s "$out" ]; then
        echo "SKIP    : $base.mzML already present"
        return 0
    fi
    echo "CONVERT : $base.raw -> $base.mzML"
    singularity exec \
        --env LC_ALL=C.UTF-8 --env LANG=C.UTF-8 \
        --bind "$RAW_DIR":/in:ro \
        --bind "$MZML_DIR":/out \
        "$TRFP_SIF" \
        ThermoRawFileParser.sh -i="/in/${base}.raw" -o=/out -f=2 \
        >>"$MZML_DIR/${base}.convert.log" 2>&1 \
    || { echo "FAILED  : $base (see ${base}.convert.log)" >&2; return 1; }
}

export -f convert_one
export RAW_DIR MZML_DIR TRFP_SIF

mapfile -t raws < <(find "$RAW_DIR" -maxdepth 1 -name '*.raw' -type f | sort)
echo "Found ${#raws[@]} .raw files to (re)check."

# xargs -P for safe parallelism. -I to keep one-arg-per-call semantics.
printf '%s\n' "${raws[@]}" \
  | xargs -P "$PARALLEL_N" -I {} bash -c 'convert_one "$@"' _ {}

converted=$(find "$MZML_DIR" -maxdepth 1 -name '*.mzML' -type f | wc -l)
echo
echo "Done. ${converted} mzML files present in $MZML_DIR (expected ${#raws[@]})."
