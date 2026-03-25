# PXD054559 - TMTpro 35-plex Deuterium

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
- **HCT116 vs HEK293T**: Protein expression differences between two human cell lines
- **8 replicates per cell line** in each sub-plex (16 samples + bridge per sub-plex)
- **DISAT strategy**: "Design Independent Sub-plexes but Acquire Together" — non-deuterated and deuterated channels normalized independently via bridge channels
- **8,595 proteins** quantified across the complete dataset

### TMT35 Channel Layout

**Non-deuterated sub-plex (18 channels):**
- 4x HCT116 + 4x HEK293T + 4x HCT116 + 4x HEK293T + 2x Bridge
- Labels: TMT126, TMT127N, TMT127C, TMT128N, TMT128C, TMT129N, TMT129C, TMT130N, TMT130C, TMT131N, TMT131C, TMT132N, TMT132C, TMT133N, TMT133C, TMT134N, TMT134C, TMT135N

**Deuterated sub-plex (17 channels):**
- 4x HCT116 + 4x HEK293T + 4x HCT116 + 4x HEK293T + 1x Bridge
- Labels: TMT127D, TMT128ND, TMT128CD, TMT129ND, TMT129CD, TMT130ND, TMT130CD, TMT131ND, TMT131CD, TMT132ND, TMT132CD, TMT133ND, TMT133CD, TMT134ND, TMT134CD, TMT135ND, TMT135CD

**Total: 35 channels** (PRIDE:0000860 TMT35PLEX)

### Subset Used
- **Two-cell proteome experiment**: 12 fractions (xb10855-xb10866) on Orbitrap Eclipse
- All 35 channels represented in SDRF
- Total: 420 SDRF rows (12 fractions x 35 channels)

### Experimental Design (all files in PXD054559)
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
- DISAT normalization: bridge channel consistency between sub-plexes

### Search Database
- **File**: `databases/PXD054559_UP000005640_contaminants.fasta` (in main databases directory)
- **Source**: UniProt Swiss-Prot Human (UP000005640) + contaminants-202105-uniprot.fasta
- **Contents**: Human (20,416) + Contaminants (285) = 20,701 proteins

### Note
- The SDRF uses all 35 TMT channels from the PRIDE ontology (PRIDE:0000861-0000877 for deuterated channels).
- **Channel-to-sample mapping from Supplementary Table S1** (NIHMS2124175-supplement-Table_S1.csv).
- `parse_sdrf convert-openms` does not yet support deuterated TMT labels — OpenMS config cannot be auto-generated for TMT35. The non-deuterated sub-plex (18 channels) can be processed independently as TMTpro18.

### Reference
Paulo JA, Gygi SP. Achieving a 35plex Tandem Mass Tag Reagent Set Through Deuterium Incorporation. J Am Chem Soc. 2025. PMC12706455. doi:10.1021/jacs.5c03844
