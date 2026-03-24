# PXD007683 - Proteome-Wide LFQ vs TMT Comparison (TMT subset)

## PRIDE Accession
PXD007683

## Title
Proteome-wide evaluation of two common protein quantification methods

## Sample Processing Protocol
Eleven TMT-labeled samples were mixed and separated by basic pH RP HPLC (Agilent 1100 pump, Agilent 300Extend C18 column). 50min linear gradient 5-35% ACN in 10mM ammonium bicarbonate pH 8. 96 fractions consolidated to 24, then to 11 fractions for LC-MS/MS. SPS-MS3 method on Orbitrap Fusion Lumos: FTMS1 (120K), ITMS2 (CID 35%), SPS-MS3 (50K resolution, up to 10 SPS ions).

## Data Processing Protocol
Searched with Sequest (v28) against combined yeast and human database. Precursor tolerance: 50ppm, product ion: 0.9 m/z. Static: TMT tags (+229.163 Da) on K and N-term, carbamidomethyl (C). Variable: oxidation (M). 1% FDR at peptide and protein levels. MS3 reporter ion quantification with isolation specificity >0.7 filter, minimum summed S/N of 200.

## Benchmark Description

### Variables Compared
- **11 TMT channels** with varying ratios of Human and Yeast peptides
- **3 fold-change levels**: 3-fold, 2-fold, and 1.5-fold differences
- Human proteins held constant, Yeast proteins spiked at different levels
- Comparison of TMT (this subset) vs LFQ (separate subset) quantification precision

### Key Finding
TMT detected statistically significant changes **three times more often** than LFQ due to higher precision and fewer missing values.

### Evaluation Criteria
- Accuracy: Measured fold changes vs expected (3x, 2x, 1.5x)
- Precision: Coefficient of variation across TMT channels
- Sensitivity: Proportion of proteins reaching statistical significance
- Missing values: Completeness compared to LFQ approach
- Comparison with LFQ approach (see lfq/OrbitrapFusionLumos/PXD007683/)

### Reference
O'Connell JD, Paulo JA, O'Brien JJ, Gygi SP. Proteome-Wide Evaluation of Two Common Protein Quantification Methods. J Proteome Res. 2018;17(5):1934-1942. doi:10.1021/acs.jproteome.8b00016
