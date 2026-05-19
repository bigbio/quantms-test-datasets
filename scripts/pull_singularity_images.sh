#!/usr/bin/env bash
#
# One-time pull of the singularity images this benchmark depends on.
# Idempotent: existing images are skipped.
#
# Usage:
#   ./pull_singularity_images.sh        # pull every image listed below
#   FORCE=1 ./pull_singularity_images.sh # re-pull even if present
#
# Output goes to $NXF_SINGULARITY_CACHEDIR (default: /hps/.../singularity).

set -euo pipefail

CACHE_DIR="${NXF_SINGULARITY_CACHEDIR:-/hps/nobackup/juan/pride/reanalysis/singularity}"
FORCE="${FORCE:-0}"

mkdir -p "$CACHE_DIR"

# Each entry: "<output filename>|<docker:// source URI>"
IMAGES=(
    "depot.galaxyproject.org-singularity-thermorawfileparser-2.0.0.dev--h9ee0642_0.img|docker://quay.io/biocontainers/thermorawfileparser:2.0.0--h9ee0642_0"
    "ghcr.io-bigbio-diann-1.8.1.img|docker://ghcr.io/bigbio/diann:1.8.1"
    "ghcr.io-bigbio-diann-2.5.0.img|docker://ghcr.io/bigbio/diann:2.5.0"
)

echo "Cache dir : $CACHE_DIR"
echo "Force     : $FORCE"
echo

command -v singularity >/dev/null 2>&1 || { echo "ERROR: singularity not in PATH" >&2; exit 1; }

for entry in "${IMAGES[@]}"; do
    name="${entry%%|*}"
    uri="${entry#*|}"
    target="$CACHE_DIR/$name"

    if [ "$FORCE" != "1" ] && [ -f "$target" ] && [ -s "$target" ]; then
        echo "SKIP    : $name (already present, $(stat -c%s "$target") bytes)"
        continue
    fi

    echo "PULL    : $name <- $uri"
    # --force overwrites if FORCE=1; --dir places the output in cache directly.
    singularity pull --force --dir "$CACHE_DIR" --name "$name" "$uri"
    echo "DONE    : $name ($(stat -c%s "$target") bytes)"
done

echo
echo "All images present in $CACHE_DIR."
ls -lh "$CACHE_DIR" | grep -E 'thermorawfileparser|diann' || true
