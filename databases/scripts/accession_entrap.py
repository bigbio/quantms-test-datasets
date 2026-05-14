import re
import argparse
from typing import Tuple


HEADER_REGEX = re.compile(r"^>([^|]+)\|([^|]+)\|([^\s|]+)(.*)$")


def convert_uniprot_accession(header_line: str) -> str:
    """Convert a UniProt FASTA header for entrapment entries.

    - Removes any occurrence of '_p_target'
    - Adds 'ENTRAP_' prefix to the database token (sp/tr/etc.), accession, and entry name
    - Preserves the rest of the description untouched

    Example:
      >sp|A0A087X1C5_p_target|CP2D7_HUMAN_p_target OS=... ->
      >ENTRAP_sp|ENTRAP_A0A087X1C5|ENTRAP_CP2D7_HUMAN OS=...
    """
    m = HEADER_REGEX.match(header_line)
    if not m:
        return header_line

    db, acc, name, rest = m.group(1), m.group(2), m.group(3), m.group(4)

    # Only transform if this looks like an entrapment target marker
    if "_p_target" not in header_line:
        return header_line

    # Avoid double-prefixing if already ENTRAP_
    new_db = db if db.startswith("ENTRAP_") else f"ENTRAP_{db}"
    new_acc = acc.replace("_p_target", "")
    if not new_acc.startswith("ENTRAP_"):
        new_acc = f"ENTRAP_{new_acc}"
    new_name = name.replace("_p_target", "")
    if not new_name.startswith("ENTRAP_"):
        new_name = f"ENTRAP_{new_name}"

    return f">{new_db}|{new_acc}|{new_name}{rest}"


def process_file(input_file: str, output_file: str) -> Tuple[int, int]:
    transformed = 0
    total_headers = 0
    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for raw in infile:
            line = raw.rstrip('\n')
            if not line.startswith('>'):
                outfile.write(line + '\n')
                continue
            total_headers += 1
            new_line = convert_uniprot_accession(line)
            if new_line != line:
                transformed += 1
            outfile.write(new_line + '\n')
    return transformed, total_headers


def main():
    parser = argparse.ArgumentParser(description="Convert UniProt FASTA entrapment headers by prefixing ENTRAP_.")
    parser.add_argument('input_file', help="Path to the input FASTA file.")
    parser.add_argument('output_file', help="Path to the output FASTA file.")
    args = parser.parse_args()

    transformed, total = process_file(args.input_file, args.output_file)
    print(f"Transformed headers: {transformed}/{total}")


if __name__ == "__main__":
    main()