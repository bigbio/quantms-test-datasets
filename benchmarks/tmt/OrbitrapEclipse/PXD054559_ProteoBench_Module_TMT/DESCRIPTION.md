# PXD054559 - ProteoBench Module TMT: TMTpro 35-plex Deuterium

## PRIDE Accession
PXD054559

## Title
Achieving a 35plex Tandem Mass Tag Reagent Set Through Deuterium Incorporation

## Sample Processing Protocol
Cells were washed with PBS and harvested by scraping into lysis buffer (8M urea, 200mM EPPS, pH 8.5) containing protease and phosphatase inhibitors. Proteins were reduced with 5mM TCEP, alkylated with 10mM iodoacetamide, then incubated with 10mM DTT. Proteins were chloroform-methanol precipitated and resuspended in 200mM EPPS (pH 8.5). Samples were digested overnight with Lys-C and trypsin at 37C (1:100 protease-to-protein ratio). 100ug peptides from each sample were labeled with non-deuterated TMTpro or TMTproD reagents in ~30% ACN for 60 min at room temperature.

## Data Processing Protocol
Database searching used a Comet-based pipeline. Searches were performed using a 50ppm precursor ion tolerance and 0.03 Da product ion tolerance. TMTpro labels on lysine residues and peptide N-termini (+304.207 Da) and carbamidomethylation of cysteine (+57.021 Da) were set as static modifications; oxidation of methionine (+15.995 Da) as variable. PSMs adjusted to 1% FDR using linear discriminant analysis. Protein-level FDR of 1%. Proteins quantified by summing reporter ion counts across all matching PSMs.

## Benchmark Description

### Variables Compared
- **Cell Line A vs Cell Line B**: Protein expression differences between two human cell lines
- **Subplexing strategy**: Non-deuterium and deuterium-containing channels segregated into distinct sub-plexes during normalization, reassembled through a common bridge channel

### Subset Used
- **Two-cell proteome experiment**: 12 fractions (xb10855-xb10866) on Orbitrap Eclipse
- TMTpro16 non-deuterated channels used (16 channels per fraction)
- Total: 192 SDRF rows (12 fractions x 16 channels)

### Experimental Design
| Files | Experiment | Instrument |
|-------|-----------|------------|
| az03671-az03674 | Dose response curve (Z0, Z2, Z9, Z13) | Eclipse |
| ea18163-ea18164 | 35-plex single shots | Eclipse |
| xb10855-xb10866 | Two-cell proteome (12 fractions) | Eclipse |

### Evaluation Criteria
- Quantification accuracy across TMTpro channels
- Reproducibility across fractions
- Dynamic range of protein quantification
- Impact of deuterium incorporation on chromatographic co-elution

### Note
The SDRF uses standard TMTpro16 labels only. The 19 deuterated (TMTproD) channels are not included as they require specialized analysis not yet supported in standard quantms pipelines. Cell line assignments are placeholders pending detailed channel-to-sample mapping.

### Reference
Gygi Lab, Harvard Medical School. No publication yet (submitted 2024-08-04, public 2024-10-17).
