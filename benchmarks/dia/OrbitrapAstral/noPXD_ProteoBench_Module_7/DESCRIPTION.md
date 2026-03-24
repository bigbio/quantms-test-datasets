# ProteoBench Module 7: LFQ Ion-Level DIA Astral 2Th

## ProteoBench Module
https://github.com/Proteobench/ProteoBench/blob/main/docs/available-modules/active-modules/7-quant-lfq-ion-dia-Astral_2Th.md

## PRIDE Accession
Not yet available. Raw files currently hosted on ProteoBench server only.

## Title
LFQ benchmark dataset for narrow-window DIA (2 Th) on Orbitrap Astral

## Sample Processing Protocol
Commercial peptide digest standards from three species (E.coli Waters P/N 186003196, Yeast Promega P/N V7461, Human Promega P/N V6951) mixed at defined ratios. 50 ng peptides injected per run.

## Data Processing Protocol
No pre-processed results provided. Raw data intended for analysis with DIA-NN, Spectronaut, or other DIA tools.

## Benchmark Description

### Variables Compared
- **Condition A vs Condition B**: Two mixed-species samples with different abundance ratios
- **Expected log2 fold changes**:
  - Homo sapiens: log2FC = 0 (unchanged)
  - Saccharomyces cerevisiae (Yeast): log2FC = -1
  - Escherichia coli: log2FC = +2
- **3 technical replicates** per condition (6 raw files total)

### Instrument & Acquisition
- **Instrument**: Orbitrap Astral (Thermo Fisher Scientific)
- **Column**: 50 cm uPAC pillar array, 180 um width
- **Gradient**: 15 min, 250 nL/min, 4-40% B
- **Full MS**: m/z 380-980, 240,000 resolution (Orbitrap)
- **DIA**: 300 windows of 2 Th isolation width
- **Fragmentation**: HCD at 25% NCE
- **MS2**: m/z 150-2000, Astral detection, 3 ms max injection time

### Raw Files
| File | Condition |
|------|-----------|
| LFQ_Astral_DIA_15min_50ng_Condition_A_REP1.raw | A |
| LFQ_Astral_DIA_15min_50ng_Condition_A_REP2.raw | A |
| LFQ_Astral_DIA_15min_50ng_Condition_A_REP3.raw | A |
| LFQ_Astral_DIA_15min_50ng_Condition_B_REP1.raw | B |
| LFQ_Astral_DIA_15min_50ng_Condition_B_REP2.raw | B |
| LFQ_Astral_DIA_15min_50ng_Condition_B_REP3.raw | B |

### Evaluation Criteria
- Sensitivity: Number of true positives (E.coli and Yeast proteins detected as differential)
- Specificity: Number of false positives (Human proteins incorrectly called differential)
- Accuracy: Measured fold changes vs expected fold changes
- Precision: Coefficient of variation across replicates
- Narrow-window DIA performance: Benefit of 2 Th windows on Astral detector

### Reference
Van Puyvelde B, Daled S, Willems S, et al. A comprehensive LFQ benchmark dataset on modern day acquisition strategies in proteomics. Sci Data. 2022;9(1):126. doi:10.1038/s41597-022-01216-6
