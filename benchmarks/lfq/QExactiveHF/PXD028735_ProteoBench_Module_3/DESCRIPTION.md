# PXD028735 - ProteoBench Module 3: LFQ Peptidoform-Level DDA

## ProteoBench Module
https://github.com/Proteobench/ProteoBench/blob/main/docs/available-modules/active-modules/3-quant-lfq-peptidoform-dda.md

## PRIDE Accession
PXD028735

## Title
A comprehensive LFQ benchmark dataset to validate data analysis pipelines on modern day acquisition strategies in proteomics

## Sample Processing Protocol
Same as Module 2. Two hybrid proteome samples A and B containing known quantities of Human, Yeast and E.coli tryptic peptides prepared in three consecutive times. Commercial lysates measured in triplicate using DDA on Q Exactive HF.

## Data Processing Protocol
Same as Module 2. No pre-processed results provided.

## Benchmark Description

### Relationship to Module 2
This module uses **the same raw data files** as Module 2 (PXD028735_ProteoBench_Module_2). The difference is in the analysis level:
- **Module 2**: Ion-level quantification (precursor ions)
- **Module 3**: Peptidoform-level quantification (peptidoform quantities summarized from precursor ion quantities)

### Variables Compared
- **Condition A vs Condition B**: Two mixed-species samples with different abundance ratios
- **Expected log2 fold changes**:
  - Homo sapiens: log2FC = 0 (unchanged)
  - Saccharomyces cerevisiae (Yeast): log2FC = -1
  - Escherichia coli: log2FC = +2

### Subset Used
Q Exactive HF, Alpha sample series, DDA acquisition:
- 3 replicates of Condition A + 3 replicates of Condition B (6 raw files)

### Evaluation Criteria
- Same as Module 2 but evaluated at peptidoform level
- Peptidoform summarization accuracy
- Impact of peptidoform aggregation on fold-change estimation
- Modified vs unmodified peptidoform quantification consistency

### Search Database
- **File**: `databases/ProteoBenchFASTA_MixedSpecies_HYE.fasta` (in main databases directory)
- **Source**: [ProteoBenchFASTA_MixedSpecies_HYE.zip](https://proteobench.cubimed.rub.de/fasta/ProteoBenchFASTA_MixedSpecies_HYE.zip)
- **Contents**: Human (20,537) + Yeast (6,722) + E.coli (4,401) + Contaminants (381) = 31,889 proteins
- **Contaminant prefix**: `Cont_` in accession (e.g., `sp|Cont_P00761|TRYP_PIG`)
- **Note**: If using MaxQuant, disable built-in contaminants — this FASTA already includes them.

### Reference
Van Puyvelde B, Daled S, Willems S, et al. A comprehensive LFQ benchmark dataset on modern day acquisition strategies in proteomics. Sci Data. 2022;9(1):126. doi:10.1038/s41597-022-01216-6
