# PXD049412 - ProteoBench Module 9: LFQ Ion-Level DIA Single-Cell

## ProteoBench Module
https://github.com/Proteobench/ProteoBench/blob/main/docs/available-modules/active-modules/9-quant-lfq-ion-dia-singlecell.md

## PRIDE Accession
PXD049412

## Title
Single-cell-level DIA benchmark dataset on Orbitrap Astral

## Sample Processing Protocol
Commercial peptide digest standards from two species mixed at defined ratios to simulate single-cell proteomics conditions:
- HeLa (Thermo Scientific Pierce HeLa Protein Digest Standard, 88328)
- Yeast (Promega MS Compatible Yeast Protein Extract Digest, V7461)
Suspended in 0.1% TFA.

## Data Processing Protocol
DIA data intended for analysis with DIA-NN, Spectronaut, or other DIA tools. Search database: mixed-species FASTA (ProteoBenchFASTA_MixedSpecies_HY.zip) including contaminant proteins.

## Benchmark Description

### Variables Compared
- **Condition A (240:10 ratio)**: 240 pg HeLa + 10 pg Yeast (3 replicates)
- **Condition B (200:50 ratio)**: 200 pg HeLa + 50 pg Yeast (3 replicates)
- Total load: 250 pg per injection (single-cell-equivalent amounts)
- **2 species only** (HeLa and Yeast, no E.coli)

### Instrument & Acquisition
- **Instrument**: Orbitrap Astral (Thermo Fisher Scientific)
- **Acquisition**: DIA, 240k resolution, 20 Th windows, 40 ms accumulation
- **FAIMS**: CV = -48, gas flow 3.8
- **Fragmentation**: HCD

### Raw Files
| File | Condition | HeLa (pg) | Yeast (pg) |
|------|-----------|-----------|------------|
| 20231123_DIA_240k_20Th_40ms_FAIMSCV-48_gas3p8_240pg_10pg_H_Y_r1.raw | A | 240 | 10 |
| 20231123_DIA_240k_20Th_40ms_FAIMSCV-48_gas3p8_240pg_10pg_H_Y_r2.raw | A | 240 | 10 |
| 20231123_DIA_240k_20Th_40ms_FAIMSCV-48_gas3p8_240pg_10pg_H_Y_r3.raw | A | 240 | 10 |
| 20231123_DIA_240k_20Th_40ms_FAIMSCV-48_gas3p8_200pg_50pg_H_Y_r1.raw | B | 200 | 50 |
| 20231123_DIA_240k_20Th_40ms_FAIMSCV-48_gas3p8_200pg_50pg_H_Y_r2.raw | B | 200 | 50 |
| 20231123_DIA_240k_20Th_40ms_FAIMSCV-48_gas3p8_200pg_50pg_H_Y_r3.raw | B | 200 | 50 |

### Evaluation Criteria
- Sensitivity at single-cell-equivalent input levels (250 pg total)
- Quantification accuracy: HeLa ratio 240/200 = 1.2x, Yeast ratio 10/50 = 0.2x
- Precision at ultra-low input amounts
- Missing value rates at single-cell loading
- FAIMS impact on sensitivity and specificity

### Note
This dataset uses only 2 species (Human HeLa + Yeast), unlike the standard 3-species ProteoBench benchmarks. The ratios are expressed as absolute amounts (pg) rather than fold changes.

### Reference
Bubis JA, et al., 2024. Available via ProteomeXchange PXD049412.
