# PXD062685 - ProteoBench Module 5: LFQ Ion-Level DIA-PASEF

## ProteoBench Module
https://github.com/Proteobench/ProteoBench/blob/main/docs/available-modules/active-modules/5-quant-lfq-ion-dia-diapasef.md

## PRIDE Accession
PXD062685

## Title
LFQ benchmark dataset for DIA-PASEF on timsTOF SCP

## Sample Processing Protocol
Commercial peptide digest standards from three species mixed at defined ratios. Samples prepared following the protocol described in Van Puyvelde et al., 2022. 25 ng injected per run.

## Data Processing Protocol
No pre-processed results provided. Raw data intended for analysis with DIA-NN, Spectronaut, or other DIA-PASEF-compatible tools.

## Benchmark Description

### Variables Compared
- **Condition A vs Condition B**: Two mixed-species samples with different abundance ratios
- **Expected log2 fold changes**:
  - Homo sapiens: log2FC = 0 (unchanged)
  - Saccharomyces cerevisiae (Yeast): log2FC = -1
  - Escherichia coli: log2FC = +2
- **3 technical replicates** per condition (6 raw files total)

### Instrument & Acquisition
- **Instrument**: timsTOF SCP (Bruker)
- **LC System**: UltiMate 3000 RS nanoLC (Thermo)
- **Column**: C18 Aurora 25cm x 75um (IonOpticks)
- **Gradient**: 35 min, 150 nL/min
- **Acquisition**: diaPASEF, 8 TIMS ramps x 3 windows of 25 Th
- **Precursor range**: m/z 400-1000
- **Ion mobility**: 1/K0 0.64-1.37
- **Collision energy**: Ramped linearly 59 eV (1/K0=1.6) to 20 eV (1/K0=0.6)
- **Cycle time**: 0.96 s

### Raw Files
| File | Condition |
|------|-----------|
| ttSCP_diaPASEF_Condition_A_Sample_Alpha_01_11494.d | A |
| ttSCP_diaPASEF_Condition_A_Sample_Alpha_02_11500.d | A |
| ttSCP_diaPASEF_Condition_A_Sample_Alpha_03_11506.d | A |
| ttSCP_diaPASEF_Condition_B_Sample_Alpha_01_11496.d | B |
| ttSCP_diaPASEF_Condition_B_Sample_Alpha_02_11502.d | B |
| ttSCP_diaPASEF_Condition_B_Sample_Alpha_03_11508.d | B |

### Evaluation Criteria
- Sensitivity: Number of true positives (E.coli and Yeast proteins detected as differential)
- Specificity: Number of false positives (Human proteins incorrectly called differential)
- Accuracy: Measured fold changes vs expected fold changes
- Precision: Coefficient of variation across replicates
- Ion mobility utilization: Impact of TIMS separation on identification depth

### Search Database
- **File**: `databases/ProteoBenchFASTA_MixedSpecies_HYE.fasta` (in main databases directory)
- **Source**: [ProteoBenchFASTA_MixedSpecies_HYE.zip](https://proteobench.cubimed.rub.de/fasta/ProteoBenchFASTA_MixedSpecies_HYE.zip)
- **Contents**: Human (20,537) + Yeast (6,722) + E.coli (4,401) + Contaminants (381) = 31,889 proteins
- **Contaminant prefix**: `Cont_` in accession (e.g., `sp|Cont_P00761|TRYP_PIG`)
- **Note**: If using MaxQuant, disable built-in contaminants — this FASTA already includes them.

### Reference
Van Puyvelde B, Daled S, Willems S, et al. A comprehensive LFQ benchmark dataset on modern day acquisition strategies in proteomics. Sci Data. 2022;9(1):126. doi:10.1038/s41597-022-01216-6
