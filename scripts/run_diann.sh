#!/bin/bash
#SBATCH --job-name=diann_only
#SBATCH --output=diann_only_%x_%j.out
#SBATCH --error=diann_only_%x_%j.err
#SBATCH --partition=standard
#SBATCH --time=48:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=48
#SBATCH --mem=200G
#SBATCH --mail-user=yperez@ebi.ac.uk
#SBATCH --mail-type=END,FAIL
#
# Run DIA-NN directly (no Nextflow) under SLURM on ONE fat node for a single
# dataset + single DIA-NN version. Generalises
# benchmarks/dia/OrbitrapEclipse/PXD071075/run_diann_v2_5_0_PXD071075.sh
# so the same parameter set can be applied to any (RAW_DIR, FASTA, VERSION)
# triple — useful for benchmarking different DIA-NN releases on the same data.
#
# Submit:
#   sbatch run_diann.sh <RAW_DIR> <FASTA> <OUTPUT_DIR> <VERSION>
#
# VERSION accepts either "2.5.0" or "2_5_0" (both map to the same image tag).
#
# Tunables (env vars):
#   THREADS              cores for DIA-NN                          (default 48 = SBATCH cap)
#   CONTAINER_RUNTIME    docker | singularity | local              (default singularity)
#   DIANN_IMAGE_REPO     image repo, used as ${repo}:${version}    (default diann)
#   DIANN_IMAGE          full image override
#   DIANN_SIF            path to a .sif file (singularity only)
#   DIANN_BIN            path to local diann binary (local only)   (default: diann on PATH)
#   EXTRA_DIANN_ARGS     extra args appended verbatim to the diann CLI

set -euo pipefail

# --- Args ----------------------------------------------------------------
if [ "$#" -ne 4 ]; then
    cat <<USAGE
Usage: sbatch $0 <RAW_DIR> <FASTA> <OUTPUT_DIR> <VERSION>

  RAW_DIR      Folder containing .raw / .d / .mzML inputs
  FASTA        Protein database (no decoys)
  OUTPUT_DIR   Folder for DIA-NN output (diann_report.tsv, matrices, logs)
  VERSION      DIA-NN version, e.g. 2.5.0 or 2_5_0

Env vars (optional):
  THREADS              (default 48)
  CONTAINER_RUNTIME    docker | singularity | local  (default singularity)
  DIANN_IMAGE_REPO     image repo                  (default 'diann')
  DIANN_IMAGE          full image override
  DIANN_SIF            singularity .sif path override
  DIANN_BIN            local diann binary (CONTAINER_RUNTIME=local)
  EXTRA_DIANN_ARGS     extra args appended to diann CLI
USAGE
    exit 1
fi

RAW_DIR="$1"
FASTA_FILE="$2"
OUTPUT_DIR="$3"
RAW_VERSION="$4"

# --- Normalise inputs ----------------------------------------------------
VERSION="${RAW_VERSION//_/.}"     # 2_5_0 -> 2.5.0
case "$VERSION" in
    1.8.1|2.1.0|2.2.0|2.3.2|2.5.0) ;;
    *) echo "WARN: unrecognised DIA-NN version '$VERSION' — continuing anyway" >&2 ;;
esac

THREADS="${THREADS:-${SLURM_CPUS_PER_TASK:-48}}"
CONTAINER_RUNTIME="${CONTAINER_RUNTIME:-singularity}"
DIANN_IMAGE_REPO="${DIANN_IMAGE_REPO:-diann}"
DIANN_IMAGE="${DIANN_IMAGE:-${DIANN_IMAGE_REPO}:${VERSION}}"
EXTRA_DIANN_ARGS="${EXTRA_DIANN_ARGS:-}"

# Absolute paths so bind mounts work regardless of CWD
RAW_DIR="$(cd "$RAW_DIR" && pwd)"
FASTA_FILE="$(cd "$(dirname "$FASTA_FILE")" && pwd)/$(basename "$FASTA_FILE")"
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"

[ -d "$RAW_DIR" ]    || { echo "ERROR: RAW_DIR not found: $RAW_DIR";    exit 1; }
[ -f "$FASTA_FILE" ] || { echo "ERROR: FASTA not found: $FASTA_FILE"; exit 1; }

FASTA_NAME="$(basename "$FASTA_FILE")"
FASTA_HOST_DIR="$(dirname "$FASTA_FILE")"
REPORT_TSV="$OUTPUT_DIR/diann_report.tsv"
LOG_FILE="$OUTPUT_DIR/diann.log"

echo "===================================================================="
echo "SLURM job      : ${SLURM_JOB_ID:-(interactive)}  node=${SLURMD_NODENAME:-N/A}"
echo "RAW dir        : $RAW_DIR"
echo "FASTA          : $FASTA_FILE"
echo "Output dir     : $OUTPUT_DIR"
echo "DIA-NN version : $VERSION (image: $DIANN_IMAGE)"
echo "Runtime        : $CONTAINER_RUNTIME"
echo "Threads        : $THREADS"
echo "Report         : $REPORT_TSV"
echo "Log            : $LOG_FILE"
echo "===================================================================="

# --- DIA-NN parameter set ------------------------------------------------
# Mirrors benchmarks/dia/OrbitrapEclipse/PXD071075/run_diann_v2_5_0_PXD071075.sh.
# Tweak in place or pass overrides via EXTRA_DIANN_ARGS.
diann_args=(
    --dir          "{RAW}"
    --fasta        "{FASTA}"
    --temp         "{OUT}"
    --threads      "$THREADS"
    --fasta-search
    --cut          "K*,R*,!*P"
    --fixed-mod    "Carbamidomethyl,57.021464,C"
    --var-mod      "Oxidation,15.994915,M"
    --mass-acc-ms1 5.0
    --mass-acc     10.0
    --min-pr-mz    400
    --max-pr-mz    800
    --min-fr-mz    200
    --max-fr-mz    1800
    --missed-cleavages 2
    --min-pep-len  7
    --max-pep-len  30
    --min-pr-charge 2
    --max-pr-charge 4
    --var-mods     2
    --predictor
    --verbose      3
    --met-excision
    --quick-mass-acc
    --min-corr     2
    --corr-diff    1
    --time-corr-only
    --no-prot-inf
    --rt-profiling
    --use-quant
    --individual-mass-acc
    --individual-windows
    --window       6
    --pg-level     2
    --no-norm
    --matrices
    --out          "{OUT}/diann_report.tsv"
    --qvalue       0.01
    --matrix-qvalue 0.01
    --matrix-spec-q 0.05
    --direct-quant
)

substitute() {
    local raw="$1" fasta="$2" out="$3"
    local a
    for a in "${diann_args[@]}"; do
        a="${a//\{RAW\}/$raw}"
        a="${a//\{FASTA\}/$fasta}"
        a="${a//\{OUT\}/$out}"
        printf '%s\n' "$a"
    done
}

run_docker() {
    local raw=/data/raw fasta=/data/fasta out=/data/output
    mapfile -t args < <(substitute "$raw" "$fasta/$FASTA_NAME" "$out")
    docker run --rm \
        -v "$RAW_DIR":"$raw":ro \
        -v "$FASTA_HOST_DIR":"$fasta":ro \
        -v "$OUTPUT_DIR":"$out" \
        "$DIANN_IMAGE" \
        diann "${args[@]}" $EXTRA_DIANN_ARGS \
        2>&1 | tee "$LOG_FILE"
}

run_singularity() {
    local raw=/data/raw fasta=/data/fasta out=/data/output
    local image_arg
    if [ -n "${DIANN_SIF:-}" ]; then
        # Explicit override — use the SIF the caller pointed us at.
        [ -f "$DIANN_SIF" ] || { echo "ERROR: DIANN_SIF not found: $DIANN_SIF"; exit 1; }
        image_arg="$DIANN_SIF"
    elif [ -n "${NXF_SINGULARITY_CACHEDIR:-}" ] && \
         [ -f "$NXF_SINGULARITY_CACHEDIR/ghcr.io-bigbio-diann-${VERSION}.img" ]; then
        # Cluster default: pick up the pre-cached SIF if it's there.
        # Naming convention matches what `nextflow` writes when pulling
        # ghcr.io/bigbio/diann:<VERSION>.
        image_arg="$NXF_SINGULARITY_CACHEDIR/ghcr.io-bigbio-diann-${VERSION}.img"
        echo "Using cached SIF : $image_arg"
    else
        # Last resort: pull from the docker registry. Requires network on
        # the compute node and writable cache.
        image_arg="docker://$DIANN_IMAGE"
    fi
    mapfile -t args < <(substitute "$raw" "$fasta/$FASTA_NAME" "$out")
    singularity exec \
        --bind "$RAW_DIR":"$raw":ro \
        --bind "$FASTA_HOST_DIR":"$fasta":ro \
        --bind "$OUTPUT_DIR":"$out" \
        "$image_arg" \
        diann "${args[@]}" $EXTRA_DIANN_ARGS \
        2>&1 | tee "$LOG_FILE"
}

run_local() {
    local bin="${DIANN_BIN:-diann}"
    command -v "$bin" >/dev/null 2>&1 || { echo "ERROR: local diann binary not found: $bin"; exit 1; }
    mapfile -t args < <(substitute "$RAW_DIR" "$FASTA_FILE" "$OUTPUT_DIR")
    "$bin" "${args[@]}" $EXTRA_DIANN_ARGS 2>&1 | tee "$LOG_FILE"
}

cd "${SLURM_SUBMIT_DIR:-$PWD}"

case "$CONTAINER_RUNTIME" in
    docker)      run_docker ;;
    singularity) run_singularity ;;
    local)       run_local ;;
    *) echo "ERROR: unknown CONTAINER_RUNTIME=$CONTAINER_RUNTIME (expected docker|singularity|local)"; exit 1 ;;
esac

DIANN_EXIT="${PIPESTATUS[0]}"

if [ "$DIANN_EXIT" -eq 0 ]; then
    echo
    echo "DIA-NN finished OK."
    echo "Report : $REPORT_TSV"
    echo "Log    : $LOG_FILE"
else
    echo "DIA-NN failed (exit=$DIANN_EXIT). See $LOG_FILE"
fi
exit "$DIANN_EXIT"
