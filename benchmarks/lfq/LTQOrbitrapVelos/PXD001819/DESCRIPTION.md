# PXD001819 - Yeast-UPS1 Standard LFQ Dataset

## PRIDE Accession
PXD001819

## Title
Yeast-UPS1 standard LC-MS/MS dataset

## Sample Processing Protocol
A yeast cell lysate was prepared in 8M urea / 0.1M ammonium bicarbonate buffer and used to resuspend and serially dilute the UPS1 standard mixture (Sigma). Samples correspond to 9 different spiked levels of UPS1 (0.05, 0.125, 0.250, 0.5, 2.5, 5, 12.5, 25, 50 fmol UPS1/ug yeast lysate). Samples were reduced with DTT, alkylated with iodoacetamide, diluted to 1M urea, and digested with trypsin overnight. 2ug yeast lysate + varying UPS1 spike levels analyzed in triplicate by nanoLC-MS/MS using a nanoRS UHPLC (Dionex) coupled to an LTQ-Orbitrap Velos (Thermo) with a 105min gradient on a 15cm C18 column, top20 DDA method.

## Data Processing Protocol
MS/MS data were searched with Mascot (v2.4.2) against a yeast UniProtKB database (7798 sequences) concatenated with UPS1 human sequences (48 sequences). Precursor tolerance: 5ppm, fragment tolerance: 0.8 Da. Fixed: carbamidomethyl (C). Variable: acetyl (Protein N-term), oxidation (M). Enzyme: trypsin/P, 2 missed cleavages.

## Benchmark Description

### Variables Compared
- **9 UPS1 spike-in concentrations**: 0.05 to 50 fmol/ug yeast lysate
- **Constant background**: Yeast cell lysate (Saccharomyces cerevisiae)
- **Spike-in proteins**: 48 human proteins (Sigma UPS1 standard)
- Each concentration measured in **triplicate** (27 total raw files)

### Evaluation Criteria
- Sensitivity: Detection of UPS1 proteins at different spike-in levels
- False discovery rate: Yeast background proteins incorrectly called differential
- Linearity: Measured abundance vs true spiked amount across concentrations
- Lower limit of quantification (LLOQ) assessment

### Search Database
- **File**: `databases/PXD001819_uniprot_yeast_ups.fasta` (in main databases directory)
- **Contents**: Yeast (S. cerevisiae) + Human UPS1 standard (48 proteins)
- **Species**: Saccharomyces cerevisiae + Homo sapiens (UPS1 spike-in)

### Reference
Ramus C, Hovasse A, Marcellin M, et al. Spiked proteomic standard dataset for testing label-free quantitative software and statistical methods. Data Brief. 2015;6:286-294. doi:10.1016/j.dib.2015.11.063
