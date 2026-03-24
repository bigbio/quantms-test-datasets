# PXD028735 - ProteoBench Module 2: LFQ Ion-Level DDA

## ProteoBench Module
https://github.com/Proteobench/ProteoBench/blob/main/docs/available-modules/active-modules/2-quant-lfq-ion-dda.md

## PRIDE Accession
PXD028735

## Title
A comprehensive LFQ benchmark dataset to validate data analysis pipelines on modern day acquisition strategies in proteomics

## Sample Processing Protocol
Two hybrid proteome samples A and B containing known quantities of Human, Yeast and E.coli tryptic peptides were prepared in three consecutive times to include handling variability. Commercial lysates were measured individually and as triple hybrid proteome mixtures each in triplicate using DDA and DIA acquisition methodologies available on six LC-MS/MS platforms (SCIEX TripleTOF5600 and 6600+, Orbitrap QE-HFX, Waters Synapt GS-Si and Synapt XS, and Bruker timsTOF Pro).

## Data Processing Protocol
The analytical data has not been analyzed with any software to enable future users to analyze with their own software.

## Benchmark Description

### Variables Compared
- **Condition A vs Condition B**: Two mixed-species samples with different abundance ratios
- **Expected log2 fold changes**:
  - Homo sapiens: log2FC = 0 (unchanged)
  - Saccharomyces cerevisiae (Yeast): log2FC = -1
  - Escherichia coli: log2FC = +2

### Subset Used
Only the **Q Exactive HF** instrument files, **Alpha sample series** (first batch), DDA acquisition:
- 3 replicates of Condition A
- 3 replicates of Condition B
- Total: 6 raw files

### Evaluation Criteria
- Sensitivity: Number of true positives (E.coli and Yeast proteins detected as differential)
- Specificity: Number of false positives (Human proteins incorrectly called differential)
- Accuracy: Measured fold changes vs expected fold changes
- Precision: Coefficient of variation across replicates

### Reference
Van Puyvelde B, Daled S, Willems S, et al. A comprehensive LFQ benchmark dataset on modern day acquisition strategies in proteomics. Sci Data. 2022;9(1):126. doi:10.1038/s41597-022-01216-6
