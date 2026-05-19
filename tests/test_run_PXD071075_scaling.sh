#!/usr/bin/env bash
# Smoke test: DRY_RUN of the PXD071075 scaling submitter must print exactly
# 7 sbatch lines, with the first two using run_diann.sh, the next five
# using run_local.sh, and a dependency chain wiring them sequentially.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Stage fake raw + fasta + sdrf so the submitter's validation passes.
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
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
