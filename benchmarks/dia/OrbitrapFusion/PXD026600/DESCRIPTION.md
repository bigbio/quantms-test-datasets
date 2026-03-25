# PXD026600 - DIA UPS1 Spike-in Benchmark

## PRIDE Accession
PXD026600 (hosted on MassIVE: MSV000087597)

## Title
DIA benchmark dataset with UPS1 spike-in at varying concentrations in E. coli background

## Sample Processing Protocol
E. coli K-12 cell lysate (1ug) spiked with UPS1 standard mixture (Sigma) at varying concentrations. Samples analyzed by nanoLC-MS/MS using an Orbitrap Fusion with Data-Independent Acquisition (DIA) using narrow isolation windows.

## Data Processing Protocol
DIA data can be analyzed with DIA-NN, Spectronaut, OpenSWATH, or other DIA analysis tools. No pre-processed results provided to enable unbiased benchmarking.

## Benchmark Description

### Variables Compared
- **UPS1 spike-in concentrations**: Multiple levels of UPS1 human protein standard spiked into constant E. coli background
- **Acquisition strategy**: Narrow-window DIA on Orbitrap Fusion

### Evaluation Criteria
- Sensitivity: Detection of UPS1 proteins at low spike-in concentrations
- Quantification accuracy: Measured vs expected UPS1 protein ratios
- False discovery rate: E. coli background proteins incorrectly called differential
- DIA workflow comparison: Performance across different DIA analysis tools (DIA-NN, Spectronaut, etc.)
- Dynamic range assessment across spike-in levels

### Search Database
- **File**: `databases/PXD026600_REF_EColi_K12_UPS1_combined.fasta` (in main databases directory)
- **Contents**: E.coli K12 (UP000000625) + Human UPS1 standard
- **Species**: Escherichia coli + Homo sapiens (UPS1 spike-in)
