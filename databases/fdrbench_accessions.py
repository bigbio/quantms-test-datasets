"""
Normalize FASTA headers after FDRBench by propagating DECOY_/ENTRAP_ labels
from the prefix token to the accession and entry name tokens, preserving the
rest of the description.

Transforms (examples):
  >sp|A0A087X1C5|CP2D7_HUMAN ...                 -> unchanged
  >ENTRAP_sp|A0A087X1C5|CP2D7_HUMAN ...          -> ENTRAP_sp|ENTRAP_A0A087X1C5|ENTRAP_CP2D7_HUMAN ...
  >DECOY_sp|A0A087X1C5|CP2D7_HUMAN ...           -> DECOY_sp|DECOY_A0A087X1C5|DECOY_CP2D7_HUMAN ...
  >DECOY_ENTRAP_sp|A0A087X1C5|CP2D7_HUMAN ...    -> DECOY_ENTRAP_sp|DECOY_ENTRAP_A0A087X1C5|DECOY_ENTRAP_CP2D7_HUMAN ...
"""

import argparse
import re
from typing import Optional, Tuple


HEADER_REGEX = re.compile(r"^>([^|]+)\|([^|]+)\|([^\s|]+)(.*)$")


def _strip_existing_label_prefix(value: str) -> str:
    for p in ("DECOY_ENTRAP_", "ENTRAP_", "DECOY_"):
        if value.startswith(p):
            return value[len(p):]
    return value


def _combined_label_from_prefix(prefix_token: str) -> Optional[str]:
    has_decoy = "DECOY_" in prefix_token
    has_entrap = "ENTRAP_" in prefix_token
    if has_decoy and has_entrap:
        return "DECOY_ENTRAP_"
    if has_decoy:
        return "DECOY_"
    if has_entrap:
        return "ENTRAP_"
    return None


def normalize_header_line(header_line: str) -> str:
    m = HEADER_REGEX.match(header_line)
    if not m:
        return header_line

    prefix_token, accession, entry_name, rest = m.group(1), m.group(2), m.group(3), m.group(4)
    label = _combined_label_from_prefix(prefix_token)
    if not label:
        return header_line

    # Remove any existing labels to avoid double-prefixing, then add the combined label
    new_accession = label + _strip_existing_label_prefix(accession)
    new_entry_name = label + _strip_existing_label_prefix(entry_name)

    return f">{prefix_token}|{new_accession}|{new_entry_name}{rest}"


def process_file(input_path: str, output_path: str) -> Tuple[int, int]:
    transformed = 0
    total_headers = 0
    with open(input_path, "r") as in_fh, open(output_path, "w") as out_fh:
        for raw in in_fh:
            line = raw.rstrip("\n")
            if not line.startswith(">"):
                out_fh.write(line + "\n")
                continue
            total_headers += 1
            new_line = normalize_header_line(line)
            if new_line != line:
                transformed += 1
            out_fh.write(new_line + "\n")
    return transformed, total_headers


def main() -> None:
    parser = argparse.ArgumentParser(description="Propagate DECOY_/ENTRAP_ labels to accession and name tokens in FASTA headers")
    parser.add_argument("--input", required=True, help="Input FASTA file produced by FDRBench")
    parser.add_argument("--output", required=True, help="Output FASTA with normalized headers")
    args = parser.parse_args()

    transformed, total = process_file(args.input, args.output)
    print(f"Normalized headers: {transformed}/{total}")


if __name__ == "__main__":
    main()