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
#   - 5 sweep points (Nextflow via run_local.sh) @ queueSize in {2,3,7,13,25}
# Chained sequentially with --dependency=afterok so wall-times are measured
# against a quiescent cluster.
#
# Reads sweep matrix from:
#   benchmarks/dia/OrbitrapEclipse/PXD071075/scaling/sweep_matrix.tsv
#
# Usage (from the cluster head, after cloning the repo):
#   ./scripts/run_PXD071075_scaling.sh              # submit
#   DRY_RUN=1 ./scripts/run_PXD071075_scaling.sh    # preview
#   sbatch     ./scripts/run_PXD071075_scaling.sh   # also fine - this script
#                                                   # is small enough to run
#                                                   # under sbatch itself
#
# Knobs (env vars):
#   REPO_ROOT, RAW_DIR, BASE_RESULTS, BASE_WORK, LOGS_DIR,
#   NXF_SINGULARITY_CACHEDIR - see defaults below.

set -euo pipefail

# build_cmd_into uses `declare -n` (nameref), which requires bash 4.3+.
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ] || { [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -lt 3 ]; }; then
    echo "ERROR: this script needs bash 4.3+ for nameref support (current: ${BASH_VERSION:-unknown})." >&2
    echo "       On macOS, install one via: brew install bash" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Repo location. If the script lives at <repo>/scripts/, the auto-detected
# value works; otherwise the env override or the explicit fallback kicks in.
if [ -d "$SCRIPT_DIR/../benchmarks" ]; then
    REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
else
    REPO_ROOT="${REPO_ROOT:-/hps/nobackup/juan/pride/reanalysis/quantms-test-datasets}"
fi

# --- Paths (cluster defaults) -------------------------------------------
RAW_DIR="${RAW_DIR:-/hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075}"
BASE_RESULTS="${BASE_RESULTS:-/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075}"
BASE_WORK="${BASE_WORK:-/hps/nobackup/juan/pride/reanalysis/quantmsdiann_work/PXD071075}"
LOGS_DIR="${LOGS_DIR:-/hps/nobackup/juan/pride/reanalysis/logs/PXD071075}"
export NXF_SINGULARITY_CACHEDIR="${NXF_SINGULARITY_CACHEDIR:-/hps/nobackup/juan/pride/reanalysis/singularity}"

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
# Columns: point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task time_limit_hours
ROWS=()
while IFS=$'\t' read -r point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task time_limit_hours; do
    # Skip header
    [ "$point_id" = "point_id" ] && continue
    [ -z "$point_id" ] && continue
    ROWS+=("$point_id|$version|$run_kind|$cluster_cores|$queue_size|$per_job_mem_gb|$head_mem_gb|$cpus_per_task|$time_limit_hours")
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
    IFS='|' read -r point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task time_limit_hours <<<"$row"
    printf "  - %-30s v%-6s kind=%-8s cores=%-3s queue=%-3s mem=%sGB cpus=%s time=%sh\n" \
        "$point_id" "$version" "$run_kind" "$cluster_cores" "$queue_size" \
        "$([ "$per_job_mem_gb" = "0" ] && echo "$head_mem_gb" || echo "$per_job_mem_gb")" \
        "$cpus_per_task" "$time_limit_hours"
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

# Populate a caller-provided array with the sbatch invocation for one row.
# Using a nameref (declare -n) keeps array elements properly quoted and
# avoids the eval-on-string pitfalls of the previous design. Mirrors the
# sibling proteobench_diann_versions.sh pattern.
build_cmd_into() {
    local -n out_arr=$1
    local point_id="$2" version="$3" run_kind="$4" cluster_cores="$5"
    local queue_size="$6" per_job_mem_gb="$7" head_mem_gb="$8" cpus_per_task="$9"
    local results_dir="${10}" log_dir="${11}" prev_jid="${12}" time_limit_hours="${13}"

    local out_file="$log_dir/slurm_%j.out"
    local err_file="$log_dir/slurm_%j.err"

    out_arr=( sbatch --parsable
        --job-name="pxd071075_${point_id}"
        --output="$out_file"
        --error="$err_file"
    )
    [ -n "$prev_jid" ] && out_arr+=( "--dependency=afterok:$prev_jid" )

    if [ "$run_kind" = "baseline" ]; then
        out_arr+=(
            --mem="${per_job_mem_gb}G"
            --cpus-per-task="$cpus_per_task"
            --time="${time_limit_hours}:00:00"
            --export="ALL,NXF_SINGULARITY_CACHEDIR=$NXF_SINGULARITY_CACHEDIR"
            "$SCRIPT_DIR/run_diann.sh"
            "$RAW_DIR" "$FASTA" "$results_dir" "$version"
        )
    else
        local work_dir="$BASE_WORK/$point_id"
        mkdir -p "$work_dir"
        out_arr+=(
            --mem="${head_mem_gb}G"
            --cpus-per-task="$cpus_per_task"
            --time="${time_limit_hours}:00:00"
            --export="ALL,QUEUE_SIZE=$queue_size,SWEEP_CORES=$cluster_cores"
            "$SCRIPT_DIR/run_local.sh"
            "$SDRF" "$RAW_DIR" "$FASTA" "$work_dir" "$results_dir" "$version"
        )
    fi
}

# --- Submit (or dry-run) ------------------------------------------------
SUBMITTED_IDS=()
idx=0
prev_jid=""
for row in "${ROWS[@]}"; do
    IFS='|' read -r point_id version run_kind cluster_cores queue_size per_job_mem_gb head_mem_gb cpus_per_task time_limit_hours <<<"$row"

    results_dir="$BASE_RESULTS/$point_id"
    log_dir="$LOGS_DIR/$point_id"
    mkdir -p "$results_dir" "$log_dir"

    declare -a CMD_ARGS=()
    build_cmd_into CMD_ARGS \
        "$point_id" "$version" "$run_kind" "$cluster_cores" \
        "$queue_size" "$per_job_mem_gb" "$head_mem_gb" "$cpus_per_task" \
        "$results_dir" "$log_dir" "$prev_jid" "$time_limit_hours"

    if [ "$DRY_RUN" = "1" ]; then
        printf '[dry-run idx=%d%s] %s\n' "$idx" "${prev_jid:+ depends-on=$prev_jid}" "${CMD_ARGS[*]}"
        prev_jid="DRY$idx"
    else
        # Real-submit only: write baseline metadata, then dispatch.
        if [ "$run_kind" = "baseline" ]; then
            write_baseline_metadata "$results_dir" "$point_id" "$version" "$cluster_cores"
        fi
        jid=$("${CMD_ARGS[@]}")
        SUBMITTED_IDS+=("$jid")
        # Patch baseline metadata in-place with the job id returned by sbatch,
        # so the aggregator's sacct call finds a non-null slurm_job_id.
        if [ "$run_kind" = "baseline" ]; then
            python3 -c "
import json, pathlib, sys
p = pathlib.Path('$results_dir/run_metadata.json')
d = json.loads(p.read_text())
d['slurm_job_id'] = '$jid'
p.write_text(json.dumps(d, indent=2) + '\n')
"
        fi
        printf '  submitted %-30s job %s%s\n' "$point_id" "$jid" "${prev_jid:+ (after $prev_jid)}"
        prev_jid="$jid"
    fi
    idx=$((idx + 1))
done

echo
if [ "$DRY_RUN" = "1" ]; then
    echo "Dry-run complete (no jobs submitted; no per-point side effects)."
else
    echo "Submitted ${#SUBMITTED_IDS[@]} jobs. Watch with: squeue -u \"\$USER\""
    echo "Per-point logs:     $LOGS_DIR/<point_id>/slurm_<jobid>.{out,err}"
    echo "Per-point results:  $BASE_RESULTS/<point_id>/"
    echo "Aggregate after:    $SCRIPT_DIR/collect_PXD071075_scaling.py"
fi
