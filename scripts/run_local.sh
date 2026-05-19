#!/bin/bash
#SBATCH --job-name=quantmsdiann
#SBATCH --output=quantmsdiann_%x_%j.out
#SBATCH --error=quantmsdiann_%x_%j.err
#SBATCH --partition=standard
#SBATCH --time=72:00:00
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=8G
#SBATCH --mail-user=yperez@ebi.ac.uk
#SBATCH --mail-type=END,FAIL
#
# Nextflow head process for quantmsdiann under SLURM. The pipeline uses the
# `pride_slurm` profile so each pipeline TASK is its own SLURM job — this
# wrapper only orchestrates, hence the tiny 2-cpu / 8 GB budget.
#
# Submit:
#   sbatch run_local.sh <SDRF> <RAW_DIR> <FASTA> <WORK_DIR> <RESULTS_DIR> <DIANN_VERSION>
#
# DIANN_VERSION is one of: 1_8_1 | 2_1_0 | 2_2_0 | 2_3_2 | 2_5_0
# (matches the diann_v<ver> profiles inside the pipeline)
#
# If you really do want to run everything inside ONE fat node (no per-task
# SLURM dispatch), drop the pride_slurm profile by exporting BASE_PROFILES=""
# and bump --cpus-per-task / --mem on the sbatch line.

set -euo pipefail

# --- Edit these for your environment ------------------------------------
PIPELINE_DIR="${PIPELINE_DIR:-/hps/nobackup/juan/pride/reanalysis/quantmsdiann}"
CONDA_SH="${CONDA_SH:-/hps/software/users/juan/pride/anaconda3/etc/profile.d/conda.sh}"
CONDA_ENV="${CONDA_ENV:-nextflow}"

# Profiles composed onto `singularity,...,diann_v<ver>`. pride_slurm is the
# whole point of running on the cluster — leave it on unless you know better.
BASE_PROFILES="${BASE_PROFILES:-pride_slurm}"

# Nextflow head JVM heap. 6g fits comfortably under --mem=8G alongside OS.
NXF_HEAD_HEAP="${NXF_HEAD_HEAP:-6g}"

# Singularity image cache shared across versions/datasets.
NXF_SINGULARITY_CACHEDIR="${NXF_SINGULARITY_CACHEDIR:-/hps/nobackup/juan/pride/reanalysis/singularity}"
export NXF_SINGULARITY_CACHEDIR
export NXF_OPTS="-Xms2g -Xmx${NXF_HEAD_HEAP}"
export NXF_ANSI_LOG=false

EMAIL="${EMAIL:-yperez@ebi.ac.uk}"
# ------------------------------------------------------------------------

if [ "$#" -ne 6 ]; then
    cat <<USAGE
Usage: sbatch $0 <SDRF> <RAW_DIR> <FASTA> <WORK_DIR> <RESULTS_DIR> <DIANN_VERSION>

  SDRF           Path to the SDRF file (*.sdrf.tsv)
  RAW_DIR        Folder containing the raw mass-spec data
  FASTA          Protein database (no decoys)
  WORK_DIR       Nextflow work directory (scratch)
  RESULTS_DIR    Where final results + reports are written
  DIANN_VERSION  One of: 1_8_1 | 2_1_0 | 2_2_0 | 2_3_2 | 2_5_0

Tunables (env vars):
  PIPELINE_DIR, CONDA_SH, CONDA_ENV,
  LOCAL_CPUS, LOCAL_MEMORY, NXF_HEAD_HEAP,
  NXF_SINGULARITY_CACHEDIR, EMAIL
USAGE
    exit 1
fi

SDRF_FILE="$1"
RAW_DIR="$2"
FASTA_FILE="$3"
WORK_DIR="$4"
RESULTS_DIR="$5"
DIANN_VERSION="$6"

# --- Validate -----------------------------------------------------------
[ -d "$PIPELINE_DIR" ]      || { echo "ERROR: PIPELINE_DIR not found: $PIPELINE_DIR"; exit 1; }
[ -f "$PIPELINE_DIR/main.nf" ] || { echo "ERROR: $PIPELINE_DIR does not look like a Nextflow pipeline"; exit 1; }
[ -f "$SDRF_FILE" ]         || { echo "ERROR: SDRF not found: $SDRF_FILE"; exit 1; }
[ -d "$RAW_DIR" ]           || { echo "ERROR: RAW_DIR not found: $RAW_DIR"; exit 1; }
[ -f "$FASTA_FILE" ]        || { echo "ERROR: FASTA not found: $FASTA_FILE"; exit 1; }

case "$DIANN_VERSION" in
    1_8_1|2_1_0|2_2_0|2_3_2|2_5_0) ;;
    *) echo "ERROR: unsupported DIA-NN version: $DIANN_VERSION"; exit 1 ;;
esac

PROFILES="singularity"
[ -n "$BASE_PROFILES" ] && PROFILES="${PROFILES},${BASE_PROFILES}"
PROFILES="${PROFILES},diann_v${DIANN_VERSION}"

# Infer --local_input_type from what's actually staged in $RAW_DIR. The SDRF
# only knows the original file names (e.g. `.d` for Bruker), but on disk the
# raws may be the compressed variants quantmsdiann supports natively
# (d, d.tar, d.tar.gz, d.zip — see the pipeline's nextflow_schema.json).
# Override via LOCAL_INPUT_TYPE=... if you've pre-converted (e.g. mzML).
#
# Order matters: longest/most-specific extension first so e.g. a folder named
# foo.d.tar.gz doesn't get mis-matched as foo.d.
if [ -z "${LOCAL_INPUT_TYPE:-}" ]; then
    shopt -s nullglob
    if   compgen -G "$RAW_DIR/*.d.tar.gz" >/dev/null; then LOCAL_INPUT_TYPE=d.tar.gz
    elif compgen -G "$RAW_DIR/*.d.tar"    >/dev/null; then LOCAL_INPUT_TYPE=d.tar
    elif compgen -G "$RAW_DIR/*.d.zip"    >/dev/null; then LOCAL_INPUT_TYPE=d.zip
    elif compgen -G "$RAW_DIR/*.d"        >/dev/null; then LOCAL_INPUT_TYPE=d
    elif compgen -G "$RAW_DIR/*.mzML"     >/dev/null || \
         compgen -G "$RAW_DIR/*.mzml"     >/dev/null; then LOCAL_INPUT_TYPE=mzML
    elif compgen -G "$RAW_DIR/*.wiff"     >/dev/null; then LOCAL_INPUT_TYPE=wiff
    elif compgen -G "$RAW_DIR/*.raw"      >/dev/null || \
         compgen -G "$RAW_DIR/*.RAW"      >/dev/null; then LOCAL_INPUT_TYPE=raw
    else
        echo "ERROR: no supported raw files found in $RAW_DIR" >&2
        echo "       (looked for *.raw *.mzML *.d *.d.tar *.d.tar.gz *.d.zip *.wiff)" >&2
        echo "       Set LOCAL_INPUT_TYPE explicitly to bypass auto-detection." >&2
        exit 1
    fi
fi

mkdir -p "$WORK_DIR" "$RESULTS_DIR" "$NXF_SINGULARITY_CACHEDIR"

echo "===================================================================="
echo "SLURM job      : ${SLURM_JOB_ID:-(interactive)}  node=${SLURMD_NODENAME:-N/A}"
echo "Pipeline dir   : $PIPELINE_DIR"
echo "SDRF           : $SDRF_FILE"
echo "FASTA          : $FASTA_FILE"
echo "RAW            : $RAW_DIR"
echo "Work dir       : $WORK_DIR"
echo "Results dir    : $RESULTS_DIR"
echo "DIA-NN version : $DIANN_VERSION"
echo "Profiles       : $PROFILES"
echo "Input type     : $LOCAL_INPUT_TYPE"
echo "Head heap      : -Xmx${NXF_HEAD_HEAP}  (this SBATCH only orchestrates)"
echo "Singularity \$ : $NXF_SINGULARITY_CACHEDIR"
echo "===================================================================="

# --- Conda --------------------------------------------------------------
# shellcheck disable=SC1090
source "$CONDA_SH"
conda activate "$CONDA_ENV"

# Each run gets its OWN CWD so concurrent jobs don't fight over .nextflow.log,
# .nextflow/ state, or the lock file. $RESULTS_DIR is already unique per
# (dataset, version) combo. Keeping the launch dir == results dir also keeps
# the .nextflow/cache/* tree co-located so `-resume` works on re-submission.
cd "$RESULTS_DIR"
export NXF_LOG_FILE="$RESULTS_DIR/nextflow.log"

EMAIL_ARGS=()
[ -n "$EMAIL" ] && EMAIL_ARGS+=( --email "$EMAIL" )

# Caller-supplied extra args (set by the driver per dataset). Word-split on
# whitespace so multi-flag strings like `--tims_sum true --normalize false`
# survive cleanly. Values must not contain spaces — they don't in practice.
read -r -a EXTRA_NF_ARGS_ARR <<< "${EXTRA_NF_ARGS:-}"
if [ "${#EXTRA_NF_ARGS_ARR[@]}" -gt 0 ]; then
    echo "Extra NF args  : ${EXTRA_NF_ARGS_ARR[*]}"
fi

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

# Dataset identifier for the metadata file. Defaults to the SDRF basename
# (e.g. "PXD071075", "PXD049412") so each benchmark gets the right label,
# but can be overridden via DATASET env var if the caller knows better.
DATASET_NAME="${DATASET:-$(basename "$SDRF_FILE" .sdrf.tsv)}"

# slurm_job_id is either a quoted string (when set) or the unquoted JSON
# literal null (when unset / interactive). Avoid emitting "" which downstream
# tooling could mistake for a truthy value.
if [ -n "${SLURM_JOB_ID:-}" ]; then
    SLURM_JOB_ID_JSON="\"$SLURM_JOB_ID\""
else
    SLURM_JOB_ID_JSON="null"
fi

cat >"$RESULTS_DIR/run_metadata.json" <<EOF
{
  "dataset": "$DATASET_NAME",
  "diann_version": "$DIANN_VERSION",
  "sweep_cores": ${SWEEP_CORES:-null},
  "queue_size": ${QUEUE_SIZE:-null},
  "slurm_job_id": $SLURM_JOB_ID_JSON,
  "slurm_submit_dir": "${SLURM_SUBMIT_DIR:-$PWD}",
  "started_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# --- Run, capturing exit code so the SLURM job's status is correct ------
# Baseline params below are the ProteoBench-spec search-space tightening
# (max_mods=2, peptide 7..30, fragment 200..1800). The pipeline auto-resolves
# tolerances, enzyme, and modifications from the SDRF — no need to repeat
# them here.
set +e
nextflow run "$PIPELINE_DIR" \
    -profile "$PROFILES" \
    "${EXTRA_CFG_ARGS[@]}" \
    -work-dir "$WORK_DIR" \
    -with-report   "$RESULTS_DIR/nextflow_report.html" \
    -with-timeline "$RESULTS_DIR/nextflow_timeline.html" \
    -with-trace    "$RESULTS_DIR/nextflow_trace.txt" \
    --input "$SDRF_FILE" \
    --database "$FASTA_FILE" \
    --root_folder "$RAW_DIR" \
    --local_input_type "$LOCAL_INPUT_TYPE" \
    --outdir "$RESULTS_DIR" \
    --max_mods 2 \
    --min_peptide_length 7 \
    --max_peptide_length 30 \
    --min_fr_mz 200 \
    --max_fr_mz 1800 \
    "${EXTRA_NF_ARGS_ARR[@]}" \
    "${EMAIL_ARGS[@]}" \
    -resume
NF_EXIT=$?
set -e

conda deactivate
exit "$NF_EXIT"
