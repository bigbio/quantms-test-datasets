# PXD070049 - ProteoBench Module 10: LFQ Ion-Level DIA ZenoTOF

## ProteoBench Module
https://github.com/Proteobench/ProteoBench/blob/main/docs/available-modules/active-modules/10-quant-lfq-ion-dia-ZenoTOF.md

## PRIDE Accession
PXD070049

## Title
LFQ benchmark dataset for Zeno SWATH DIA on ZenoTOF 8600

## Sample Processing Protocol
Commercial peptide digest standards from three species (E.coli Waters P/N 186003196, Yeast Promega P/N V7461, Human Promega P/N V6951) mixed at defined ratios. 50 ng peptides injected per run.

## Data Processing Protocol
No pre-processed results provided. Raw data intended for DIA analysis tools (DIA-NN, Spectronaut, etc.).

## Benchmark Description

### Variables Compared
- **Condition A vs Condition B**: Two mixed-species samples with different abundance ratios
- **Expected log2 fold changes**:
  - Homo sapiens: log2FC = 0 (unchanged)
  - Saccharomyces cerevisiae (Yeast): log2FC = -1
  - Escherichia coli: log2FC = +2
- **3 technical replicates** per condition (6 raw files total)

### Instrument & Acquisition
- **Instrument**: SCIEX ZenoTOF 8600
- **Acquisition**: Zeno SWATH DIA, 85 variable windows
- **Column**: IonOpticks Aurora XS Ultimate (25 cm x 75 um, 1.7 um)
- **Flow rate**: 0.250 uL/min, 40C
- **Gradient**: 15 min, 3-35% B
- **Ion source**: OptiFlow Pro Nano with NanoCal probe, 2500 V
- **MS1**: 400-1500 Da, 50 ms survey scan
- **MS/MS**: 400-900 Da precursor, 140-1750 Da fragments, 16 ms accumulation
- **Zeno trap pulsing**: Enabled

### Raw Files
| File | Condition |
|------|-----------|
| LFQ_ZenoTOF8600_ZenoSWATH_85VW_15min_Nano_50ng_Condition_A_REP1.wiff | A |
| LFQ_ZenoTOF8600_ZenoSWATH_85VW_15min_Nano_50ng_Condition_A_REP2.wiff | A |
| LFQ_ZenoTOF8600_ZenoSWATH_85VW_15min_Nano_50ng_Condition_A_REP3.wiff | A |
| LFQ_ZenoTOF8600_ZenoSWATH_85VW_15min_Nano_50ng_Condition_B_REP1.wiff | B |
| LFQ_ZenoTOF8600_ZenoSWATH_85VW_15min_Nano_50ng_Condition_B_REP2.wiff | B |
| LFQ_ZenoTOF8600_ZenoSWATH_85VW_15min_Nano_50ng_Condition_B_REP3.wiff | B |

### Evaluation Criteria
- Sensitivity: Number of true positives (E.coli and Yeast proteins detected as differential)
- Specificity: Number of false positives (Human proteins incorrectly called differential)
- Accuracy: Measured fold changes vs expected fold changes
- Zeno SWATH performance: Benefit of Zeno trap pulsing on sensitivity
- Variable window DIA: Impact of 85 variable windows on coverage

### Search Database
- **File**: `databases/ProteoBenchFASTA_MixedSpecies_HYE.fasta` (in main databases directory)
- **Source**: [ProteoBenchFASTA_MixedSpecies_HYE.zip](https://proteobench.cubimed.rub.de/fasta/ProteoBenchFASTA_MixedSpecies_HYE.zip)
- **Contents**: Human (20,537) + Yeast (6,722) + E.coli (4,401) + Contaminants (381) = 31,889 proteins
- **Contaminant prefix**: `Cont_` in accession (e.g., `sp|Cont_P00761|TRYP_PIG`)
- **Note**: If using MaxQuant, disable built-in contaminants — this FASTA already includes them.

### Reference
Van Puyvelde B, Daled S, Willems S, et al. A comprehensive LFQ benchmark dataset on modern day acquisition strategies in proteomics. Sci Data. 2022;9(1):126. doi:10.1038/s41597-022-01216-6
