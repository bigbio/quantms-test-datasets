"""
Reads a contaminants FASTA and ensures each header has a UniProt description
appended (protein name, OS, OX, GN, PE, SV). Fetches from UniProt's REST API
with retries and adds sensible fallbacks if the API is unavailable.

Usage:
  python contaminants_uniprot_description.py \
    --input contaminants-202105-uniprot.fasta \
    --output contaminants-202105-uniprot-description.fasta
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from typing import Dict, Optional, Tuple

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


UNIPROT_REST_FASTA = "https://rest.uniprot.org/uniprotkb/{accession}.fasta"
UNIPROT_LEGACY_FASTA = "https://www.uniprot.org/uniprot/{accession}.fasta"


def build_requests_session() -> requests.Session:
    session = requests.Session()
    retries = Retry(
        total=5,
        backoff_factor=1.0,
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=("GET",),
        raise_on_status=False,
    )
    adapter = HTTPAdapter(max_retries=retries, pool_connections=10, pool_maxsize=10)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    session.headers.update({
        "User-Agent": "multiomics-configs/contaminants_uniprot_description (+https://github.com)"
    })
    return session


def load_cache(cache_path: str) -> Dict[str, str]:
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r") as fh:
                return json.load(fh)
        except Exception:
            return {}
    return {}


def save_cache(cache_path: str, cache: Dict[str, str]) -> None:
    tmp_path = cache_path + ".tmp"
    with open(tmp_path, "w") as fh:
        json.dump(cache, fh, indent=2, sort_keys=True)
    os.replace(tmp_path, cache_path)


def fetch_uniprot_header_line(session: requests.Session, accession: str, timeout_sec: float = 10.0) -> Optional[str]:
    for template in (UNIPROT_REST_FASTA, UNIPROT_LEGACY_FASTA):
        url = template.format(accession=accession)
        try:
            response = session.get(url, timeout=timeout_sec)
        except requests.RequestException:
            continue
        if response.status_code == 200 and response.text:
            first_line = response.text.splitlines()[0].strip()
            if first_line.startswith(">"):
                return first_line
    return None


def extract_description_suffix(uniprot_header_line: str) -> str:
    """Return the part after the first space from a UniProt FASTA header line.

    Example: ">sp|P00761|TRY1_PIG Trypsin OS=Sus scrofa OX=9823 PE=1 SV=1" ->
             "Trypsin OS=Sus scrofa OX=9823 PE=1 SV=1"
    """
    parts = uniprot_header_line.split(" ", 1)
    return parts[1].strip() if len(parts) == 2 else ""


SPECIES_SUFFIX_TO_OS_OX: Dict[str, Tuple[str, int]] = {
    "HUMAN": ("Homo sapiens", 9606),
    "MOUSE": ("Mus musculus", 10090),
    "RAT": ("Rattus norvegicus", 10116),
    "BOVIN": ("Bos taurus", 9913),
    "PIG": ("Sus scrofa", 9823),
    "CHICK": ("Gallus gallus", 9031),
    "YEAST": ("Saccharomyces cerevisiae", 559292),
    "ECOLI": ("Escherichia coli (strain K12)", 83333),
}


def infer_os_ox_from_id(contam_identifier: str) -> Optional[str]:
    """Build a minimal OS/OX string using the species suffix in the identifier.

    Example: "CONTAM_Q2TBQ1_BOVIN" -> "OS=Bos taurus OX=9913"
    """
    m = re.search(r"_([A-Z0-9]+)$", contam_identifier)
    if not m:
        return None
    suffix = m.group(1)
    mapping = SPECIES_SUFFIX_TO_OS_OX.get(suffix)
    if not mapping:
        return None
    organism_name, tax_id = mapping
    return f"OS={organism_name} OX={tax_id}"


def ensure_gn_present(description_suffix: str) -> str:
    if " GN=" in description_suffix or description_suffix.endswith("GN="):
        return description_suffix
    # Append GN=unknown at the end
    return description_suffix + " GN=unknown"


def process_fasta(input_path: str, output_path: str, cache_path: str) -> None:
    session = build_requests_session()
    cache = load_cache(cache_path)

    with open(input_path, "r") as in_fh, open(output_path, "w") as out_fh:
        for raw_line in in_fh:
            line = raw_line.rstrip("\n")
            if not line.startswith(">"):
                out_fh.write(line + "\n")
                continue

            # Example line: ">tr|CONTAM_Q1RMK2|CONTAM_Q1RMK2_BOVIN"
            tokens = line.split("|")
            if len(tokens) < 2:
                out_fh.write(line + "\n")
                continue

            contam_identifier = tokens[1]  # e.g., CONTAM_Q1RMK2
            accession = contam_identifier.replace("CONTAM_", "")

            # Fetch description (with cache)
            description_suffix: Optional[str] = cache.get(accession)
            if not description_suffix:
                header_line = fetch_uniprot_header_line(session, accession)
                if header_line:
                    description_suffix = extract_description_suffix(header_line)
                    # Normalize double spaces
                    description_suffix = re.sub(r"\s+", " ", description_suffix).strip()
                    cache[accession] = description_suffix
                    save_cache(cache_path, cache)

            # Fallback: if still missing, infer minimal OS/OX from suffix
            if not description_suffix:
                minimal_os_ox = infer_os_ox_from_id(tokens[2]) if len(tokens) > 2 else None
                if minimal_os_ox:
                    description_suffix = minimal_os_ox
                else:
                    description_suffix = ""  # last resort

            description_suffix = ensure_gn_present(description_suffix)

            # Compose final header line: keep original prefix, append description suffix
            composed_header = line
            if description_suffix:
                composed_header = f"{line} {description_suffix}"
            out_fh.write(composed_header + "\n")


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Append UniProt descriptions to contaminants FASTA headers")
    parser.add_argument(
        "--input",
        default="contaminants-202105-uniprot.fasta",
        help="Input FASTA with contaminant accessions (default: contaminants-202105-uniprot.fasta)",
    )
    parser.add_argument(
        "--output",
        default="contaminants-202105-uniprot-description.fasta",
        help="Output FASTA with appended descriptions (default: contaminants-202105-uniprot-description.fasta)",
    )
    parser.add_argument(
        "--cache",
        default=".uniprot_header_cache.json",
        help="Path to JSON cache file for fetched UniProt header suffixes",
    )
    return parser.parse_args(argv)


def main() -> None:
    args = parse_args()
    process_fasta(args.input, args.output, args.cache)


if __name__ == "__main__":
    main()