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
SLURM_SUBMIT_DIR="/some/dir"
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
  "slurm_submit_dir": "${SLURM_SUBMIT_DIR:-$PWD}",
  "started_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

grep -q "queueSize = 7" "$RESULTS_DIR/queue_size.config" || { echo "FAIL: queue_size.config missing 'queueSize = 7'"; exit 1; }
grep -q '"sweep_cores": 50' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing sweep_cores"; exit 1; }
grep -q '"queue_size": 7' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing queue_size"; exit 1; }
grep -q '"dataset": "PXD071075"' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing dataset"; exit 1; }
grep -q '"diann_version": "2_5_0"' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing diann_version"; exit 1; }
grep -q '"slurm_job_id": "999"' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing slurm_job_id"; exit 1; }
grep -q '"slurm_submit_dir": "/some/dir"' "$RESULTS_DIR/run_metadata.json" || { echo "FAIL: metadata missing slurm_submit_dir"; exit 1; }

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
