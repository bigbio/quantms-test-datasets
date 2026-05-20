#!/usr/bin/env bash
# Smoke test for the one-shot sweep submitter.
# Tests: valid args yield the expected sbatch line; invalid args exit non-zero.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/submit_PXD071075_sweep.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fake scripts dir with a run_local.sh stub
mkdir -p "$TMP/scripts" "$TMP/raw" "$TMP/results" "$TMP/work" "$TMP/logs" "$TMP/singularity"
touch "$TMP/scripts/run_local.sh"
chmod +x "$TMP/scripts/run_local.sh"
touch "$TMP/raw/sample.raw"

# The script needs SDRF + FASTA inside the repo. They already exist on disk
# (this is the working repo). REPO_ROOT default points there.
export DRY_RUN=1
export RAW_DIR="$TMP/raw"
export BASE_RESULTS="$TMP/results"
export BASE_WORK="$TMP/work"
export LOGS_DIR_ROOT="$TMP/logs"
export NXF_SINGULARITY_CACHEDIR="$TMP/singularity"
export SCRIPTS_DIR="$TMP/scripts"
export REPO_ROOT="$REPO_ROOT"

# Case A: QUEUE_SIZE=30, default TIME_HOURS=72
A_OUT=$("$SCRIPT" 30 2>&1)
echo "$A_OUT" | grep -q "Point         : v2_5_0_sweep_030cores" || { echo "FAIL A: missing point_id"; echo "$A_OUT"; exit 1; }
echo "$A_OUT" | grep -q "QUEUE_SIZE    : 30"                    || { echo "FAIL A: missing QUEUE_SIZE banner"; exit 1; }
echo "$A_OUT" | grep -q "Time limit    : 72:00:00"              || { echo "FAIL A: wrong default TIME_HOURS"; exit 1; }
echo "$A_OUT" | grep -qE -- "--time=72:00:00"                   || { echo "FAIL A: sbatch missing --time=72:00:00"; exit 1; }
echo "$A_OUT" | grep -qE "QUEUE_SIZE=30,SWEEP_CORES=30"         || { echo "FAIL A: export missing QUEUE_SIZE=30"; exit 1; }

# Case B: QUEUE_SIZE=100, TIME_HOURS=12
B_OUT=$("$SCRIPT" 100 12 2>&1)
echo "$B_OUT" | grep -q "Point         : v2_5_0_sweep_100cores" || { echo "FAIL B: missing point_id"; exit 1; }
echo "$B_OUT" | grep -qE -- "--time=12:00:00"                   || { echo "FAIL B: wrong --time"; exit 1; }
echo "$B_OUT" | grep -qE "QUEUE_SIZE=100,SWEEP_CORES=100"       || { echo "FAIL B: export missing QUEUE_SIZE=100"; exit 1; }

# Case C: invalid arg (non-integer)
if "$SCRIPT" foo 2>/dev/null; then
    echo "FAIL C: non-integer QUEUE_SIZE should have failed"
    exit 1
fi

# Case D: invalid arg (zero)
if "$SCRIPT" 0 2>/dev/null; then
    echo "FAIL D: QUEUE_SIZE=0 should have failed"
    exit 1
fi

# Case E: no args -> usage / non-zero
if "$SCRIPT" 2>/dev/null; then
    echo "FAIL E: no-args should print usage and exit non-zero"
    exit 1
fi

echo "OK: submit_PXD071075_sweep.sh handles valid + invalid inputs as expected"
