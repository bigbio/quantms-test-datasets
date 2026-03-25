#!/usr/bin/env bash
#
# download_raw.sh - Download RAW files listed in an SDRF file using pridepy
#
# Usage:
#   bash download_raw.sh <sdrf_file> <output_dir> [--convert] [--cleanup]
#
# Options:
#   --convert   Convert Thermo RAW -> mzML after download (requires ThermoRawFileParser)
#   --cleanup   Delete RAW files after successful mzML conversion
#
# Examples:
#   bash download_raw.sh PXD001819.sdrf.tsv /data/raw_files
#   bash download_raw.sh PXD001819.sdrf.tsv /data/raw_files --convert --cleanup
#

set -euo pipefail

# ═══════════════════════════════════════════════════════════════════════════════
# Parse arguments
# ═══════════════════════════════════════════════════════════════════════════════
SDRF_FILE=""
OUTPUT_DIR=""
DO_CONVERT=0
DO_CLEANUP=0

for arg in "$@"; do
    case "${arg}" in
        --convert)  DO_CONVERT=1 ;;
        --cleanup)  DO_CLEANUP=1 ;;
        *)
            if [[ -z "${SDRF_FILE}" ]]; then
                SDRF_FILE="${arg}"
            elif [[ -z "${OUTPUT_DIR}" ]]; then
                OUTPUT_DIR="${arg}"
            fi
            ;;
    esac
done

if [[ -z "${SDRF_FILE}" || -z "${OUTPUT_DIR}" ]]; then
    echo "Usage: $0 <sdrf_file> <output_dir> [--convert] [--cleanup]"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 1: Conda environment setup
# ═══════════════════════════════════════════════════════════════════════════════
ENV_NAME="benchmarks_download"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " PHASE 1: Setting up conda environment"
echo "═══════════════════════════════════════════════════════════"

if conda env list 2>/dev/null | grep -qw "${ENV_NAME}"; then
    echo "Environment '${ENV_NAME}' already exists, activating..."
else
    echo "Creating environment '${ENV_NAME}'..."
    mamba create -y -n "${ENV_NAME}" -c conda-forge python=3.11
fi

eval "$(conda shell.bash hook)"
conda activate "${ENV_NAME}"

# Install pridepy if not already installed
if ! command -v pridepy &>/dev/null; then
    pip install --quiet pridepy
fi

# Install ThermoRawFileParser if conversion is requested
THERMO_CMD=""
if [[ ${DO_CONVERT} -eq 1 ]]; then
    if command -v ThermoRawFileParser &>/dev/null; then
        THERMO_CMD="ThermoRawFileParser"
    elif command -v thermorawfileparser &>/dev/null; then
        THERMO_CMD="thermorawfileparser"
    else
        echo "Installing ThermoRawFileParser..."
        mamba install -y -c bioconda -c conda-forge --override-channels thermorawfileparser
        if command -v ThermoRawFileParser &>/dev/null; then
            THERMO_CMD="ThermoRawFileParser"
        elif command -v thermorawfileparser &>/dev/null; then
            THERMO_CMD="thermorawfileparser"
        else
            echo "ERROR: ThermoRawFileParser not found after installation"
            exit 1
        fi
    fi
    echo "Using: $(which ${THERMO_CMD})"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 2: Download RAW files from SDRF
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════════"
echo " PHASE 2: Downloading files"
echo "═══════════════════════════════════════════════════════════"

mkdir -p "${OUTPUT_DIR}"

# Extract PXD accession from SDRF filename or directory path
pxd_accession=$(echo "${SDRF_FILE}" | grep -oE 'PXD[0-9]+' | tail -1 || true)

echo "SDRF: ${SDRF_FILE}"
echo "PXD:  ${pxd_accession:-unknown}"
echo "Output: ${OUTPUT_DIR}"
echo ""

python3 -c "
import csv, os, subprocess, sys

sdrf_path = '${SDRF_FILE}'
out_dir = '${OUTPUT_DIR}'
pxd = '${pxd_accession}'

with open(sdrf_path, 'r') as f:
    reader = csv.DictReader(f, delimiter='\t')
    headers_lower = {h.lower().strip(): h for h in reader.fieldnames}
    uri_key = headers_lower.get('comment[file uri]')
    if not uri_key:
        print('ERROR: No comment[file uri] column found in SDRF')
        sys.exit(1)

    seen = set()
    files = []
    for row in reader:
        uri = row.get(uri_key, '').strip()
        if not uri or uri in seen:
            continue
        seen.add(uri)
        files.append(uri)

print(f'Found {len(files)} unique files to download')
print()

downloaded = 0
skipped = 0
failed = 0

for uri in files:
    filename = os.path.basename(uri)
    dl_path = os.path.join(out_dir, filename)

    if os.path.exists(dl_path):
        print(f'  SKIP (exists): {filename}')
        skipped += 1
        continue

    # Skip if already converted to mzML
    mzml_path = os.path.join(out_dir, os.path.splitext(filename)[0] + '.mzML')
    if os.path.exists(mzml_path) and os.path.getsize(mzml_path) > 0:
        print(f'  SKIP (mzML exists): {filename}')
        skipped += 1
        continue

    is_url = uri.startswith('http://') or uri.startswith('https://') or uri.startswith('ftp://')

    print(f'  Downloading: {filename}')
    ok = False

    is_pride = 'ftp.pride.ebi.ac.uk' in uri
    is_ftp = uri.startswith('ftp://')

    # Strategy 1: pridepy for PRIDE datasets
    if pxd and is_pride:
        try:
            subprocess.run(['pridepy', 'download-file-by-name', '-a', pxd, '-f', filename, '-o', out_dir],
                         check=True, capture_output=True)
            ok = True
        except subprocess.CalledProcessError:
            pass

    # Strategy 2: wget for FTP (non-PRIDE FTP like MassIVE, or pridepy fallback)
    if not ok and is_ftp:
        try:
            subprocess.run(['wget', '-q', '--no-check-certificate', '-O', dl_path, uri], check=True)
            ok = True
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass

    # Strategy 3: curl for HTTP/HTTPS (ProteoBench server, PRIDE HTTPS, etc.)
    if not ok and is_url:
        try:
            subprocess.run(['curl', '-sL', '-o', dl_path, uri], check=True)
            ok = True
        except subprocess.CalledProcessError:
            pass

    # Strategy 4: wget fallback for anything else
    if not ok and is_url:
        try:
            subprocess.run(['wget', '-q', '--no-check-certificate', '-O', dl_path, uri], check=True)
            ok = True
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass

    if ok and os.path.exists(dl_path):
        downloaded += 1
    else:
        print(f'  FAILED: {filename}')
        failed += 1

print()
print(f'Summary: {downloaded} downloaded, {skipped} skipped, {failed} failed')
"

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 3: Convert RAW -> mzML (optional)
# ═══════════════════════════════════════════════════════════════════════════════
if [[ ${DO_CONVERT} -eq 1 ]]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo " PHASE 3: Converting RAW files to mzML"
    echo "═══════════════════════════════════════════════════════════"

    converted=0
    skipped_conv=0
    failed_conv=0

    for raw_path in "${OUTPUT_DIR}"/*.raw "${OUTPUT_DIR}"/*.RAW; do
        [[ ! -f "${raw_path}" ]] && continue

        filename="$(basename "${raw_path}")"
        mzml_filename="${filename%.*}.mzML"
        mzml_path="${OUTPUT_DIR}/${mzml_filename}"

        if [[ -f "${mzml_path}" && -s "${mzml_path}" ]]; then
            echo "  SKIP (already converted): ${mzml_filename}"
            skipped_conv=$((skipped_conv + 1))
            continue
        fi

        echo "  Converting: ${filename} -> ${mzml_filename}"
        if ${THERMO_CMD} -i "${raw_path}" -o "${OUTPUT_DIR}" -f 2 2>&1; then
            converted=$((converted + 1))
        else
            echo "  FAILED: ${filename}"
            failed_conv=$((failed_conv + 1))
        fi
    done

    echo ""
    echo "Conversion summary: ${converted} converted, ${skipped_conv} skipped, ${failed_conv} failed"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# PHASE 4: Cleanup RAW files (optional)
# ═══════════════════════════════════════════════════════════════════════════════
if [[ ${DO_CLEANUP} -eq 1 && ${DO_CONVERT} -eq 1 ]]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo " PHASE 4: Cleaning up converted RAW files"
    echo "═══════════════════════════════════════════════════════════"

    cleaned=0
    for raw_path in "${OUTPUT_DIR}"/*.raw "${OUTPUT_DIR}"/*.RAW; do
        [[ ! -f "${raw_path}" ]] && continue

        filename="$(basename "${raw_path}")"
        mzml_path="${OUTPUT_DIR}/${filename%.*}.mzML"

        if [[ -f "${mzml_path}" && -s "${mzml_path}" ]]; then
            rm "${raw_path}"
            echo "  Deleted: ${filename}"
            cleaned=$((cleaned + 1))
        fi
    done

    echo "Cleaned up ${cleaned} RAW files"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo " DONE"
echo "═══════════════════════════════════════════════════════════"
echo "Output: ${OUTPUT_DIR}"
