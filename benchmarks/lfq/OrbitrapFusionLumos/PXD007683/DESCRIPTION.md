# PXD007683 - Proteome-Wide LFQ vs TMT Comparison (LFQ subset)

## PRIDE Accession
PXD007683

## Title
Proteome-wide evaluation of two common protein quantification methods

## Sample Processing Protocol
Samples were de-salted via C-18 StageTips. Eleven 3-hour gradients were collected using an Orbitrap Fusion Lumos coupled to a Proxeon EASY-nLC 1200. Peptides separated on a 100um ID microcapillary column packed with ~35cm Accucore 150 resin (2.6um, 150A). 1ug per sample loaded. Gradient: 6-26% ACN in 0.125% formic acid over 3hr at ~400 nL/min. Top10 DDA method with FTMS1 (120K resolution), FTMS2 (15K resolution), HCD (35%), dynamic exclusion (90s).

## Data Processing Protocol
Searched with MaxQuant (v1.5.8.3) against combined yeast and human database. Precursor tolerance: 20ppm, product ion: 0.5 m/z. Static: carbamidomethyl (C). Variable: oxidation (M). Match-between-runs enabled. LFQ quantification via MaxQuant's LFQ algorithm.

## Benchmark Description

### Variables Compared
- **11 samples** with varying ratios of Human and Yeast peptides
- **3 fold-change levels**: 3-fold, 2-fold, and 1.5-fold differences
- Human proteins held constant, Yeast proteins spiked at different levels
- Comparison of LFQ (this subset) vs TMT (separate subset) quantification precision

### Evaluation Criteria
- Accuracy: Measured fold changes vs expected (3x, 2x, 1.5x)
- Precision: Coefficient of variation across measurements
- Sensitivity: Proportion of proteins with statistically significant differential abundance
- Missing values: Completeness of quantification matrix
- Comparison with TMT approach (see tmt/OrbitrapFusionLumos/PXD007683/)

### Reference
O'Connell JD, Paulo JA, O'Brien JJ, Gygi SP. Proteome-Wide Evaluation of Two Common Protein Quantification Methods. J Proteome Res. 2018;17(5):1934-1942. doi:10.1021/acs.jproteome.8b00016
