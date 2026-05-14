import re

import pandas as pd
from Bio import SeqIO
import matplotlib.pyplot as plt
from collections import Counter


def analyze_protein_database(fasta_file):
    # Initialize counters and variables
    target_count = 0
    decoy_count = 0
    entrap_count = 0
    sequence_lengths = []

    # Patterns for identifying tags
    decoy_pattern = re.compile(r"DECOY_")
    entrap_pattern = re.compile(r"ENTRAP_")

    # Parse the FASTA file
    for record in SeqIO.parse(fasta_file, "fasta"):
        header = record.description
        sequence_lengths.append(len(record.seq))

        # Count categories based on header tags
        if decoy_pattern.search(header):
            decoy_count += 1
        elif entrap_pattern.search(header):
            entrap_count += 1
        else:
            target_count += 1

    # Calculate metrics
    total_sequences = target_count + decoy_count + entrap_count
    target_decoy_ratio = (target_count + entrap_count )/ max(decoy_count, 1)  # Avoid division by zero
    sequence_length_distribution = Counter(sequence_lengths)

    print(f"Total sequences: {total_sequences}")
    print(f"Target proteins: {target_count}")
    print(f"Decoy proteins: {decoy_count}")
    print(f"Entrapment proteins: {entrap_count}")
    print(f"Target-to-Decoy Ratio: {target_decoy_ratio:.2f}")

    # Plot sequence length distribution

    labels = ["Target", "Decoy", "Entrapment"]
    counts = [target_count, decoy_count, entrap_count]
    colors = ['blue', 'green', 'red']

    # 2. Pie chart for proportions of each category, independent plot
    plt.figure(figsize=(6, 6))
    plt.pie(counts, labels=labels, autopct='%1.1f%%', colors=colors, startangle=140)
    plt.title("Proportion of Protein Types")
    plt.show()

    # 4. Target-to-Decoy Ratio

    plt.figure(figsize=(4, 6))
    plt.bar(["Target-to-Decoy Ratio"], [target_decoy_ratio], color='cyan')
    plt.ylim(0, max(target_decoy_ratio + 1, 5))
    plt.title("Target-to-Decoy Ratio")
    plt.tight_layout()
    plt.show()


def analyze_decoy_quality(fasta_file):
    # Initialize variables for length and amino acid composition
    target_lengths = []
    decoy_lengths = []
    target_aa_counts = Counter()
    decoy_aa_counts = Counter()

    # Patterns for identifying target and decoy
    decoy_pattern = re.compile(r"DECOY_")

    # Parse the FASTA file
    for record in SeqIO.parse(fasta_file, "fasta"):
        sequence = str(record.seq)
        length = len(sequence)

        if decoy_pattern.search(record.description):
            decoy_lengths.append(length)
            decoy_aa_counts.update(sequence)
        else:
            target_lengths.append(length)
            target_aa_counts.update(sequence)

    # Calculate amino acid composition as percentage
    total_target_aa = sum(target_aa_counts.values())
    total_decoy_aa = sum(decoy_aa_counts.values())

    target_aa_composition = {aa: count / total_target_aa * 100 for aa, count in target_aa_counts.items()}
    decoy_aa_composition = {aa: count / total_decoy_aa * 100 for aa, count in decoy_aa_counts.items()}

    # Prepare data for amino acid comparison plot
    aa_df = pd.DataFrame({
        'Amino Acid': list(target_aa_composition.keys()),
        'Target Composition (%)': list(target_aa_composition.values()),
        'Decoy Composition (%)': [decoy_aa_composition.get(aa, 0) for aa in target_aa_composition.keys()]
    })

    plt.figure(figsize=(8, 6))
    plt.hist(target_lengths, bins=200, alpha=0.5, label='Target', color='blue')
    plt.hist(decoy_lengths, bins=200, alpha=0.5, label='Decoy', color='orange')
    plt.title("Sequence Length Distribution")
    plt.xlabel("Sequence Length")
    plt.ylabel("Frequency")
    plt.legend()
    plt.show()

    # 2. Amino Acid Composition Comparison
    plt.figure(figsize=(10, 6))
    aa_df.plot(
        x='Amino Acid',
        y=['Target Composition (%)', 'Decoy Composition (%)'],
        kind='bar',
        color=['blue', 'orange']
    )
    plt.title("Amino Acid Composition: Target vs. Decoy")
    plt.xlabel("Amino Acid")
    plt.ylabel("Composition (%)")
    plt.legend(["Target", "Decoy"])
    plt.tight_layout()
    plt.show()

# Example usage
fasta_file = 'Homo-sapiens-uniprot-reviewed-contam-entrap-decoy-20241105.fasta'
analyze_protein_database(fasta_file)
analyze_decoy_quality(fasta_file)