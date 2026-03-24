# PXD019643 - HLA Ligand Atlas (HLA-II subset)

## PRIDE Accession
PXD019643

## Title
The HLA-Ligand-Atlas: A resource of natural HLA ligands presented on benign tissues

## Sample Processing Protocol
HLA class I and class II molecules were isolated from snap-frozen tissue using standard immunoaffinity chromatography. Antibodies used: pan-HLA class I (W6/32), HLA-DR-specific (L243), and pan-HLA class II (Tu39). Antibodies cross-linked to CNBr-activated sepharose. HLA-peptide complexes eluted, peptides separated by ultrafiltration, desalted, and analyzed by nanoLC-MS/MS.

## Data Processing Protocol
MS data analyzed using the nf-core containerized pipeline MHCquant (revision 1.5.1) with default settings. Identification and post-scoring performed using OpenMS adapters to Comet 2016.01 rev.3 and Percolator 3.1.1 at 1% local peptide-level FDR among replicate sample groups.

## Benchmark Description

### Subset Used
- **HLA class II** immunopeptidomics data only

### Variables Compared
- **Tissue types**: HLA-II ligands across multiple benign human tissues (30 tissue types)
- **HLA alleles**: 86 HLA-II alleles represented
- **Tissue-specific vs shared ligands**: Identification of tissue-restricted vs ubiquitous HLA-presented peptides

### Evaluation Criteria
- Peptide identification depth across tissues
- Reproducibility of HLA ligand identification
- HLA binding motif recovery
- Tissue-specific ligand enrichment
- Coverage of the immunopeptidome

### Note
This is an immunopeptidomics dataset with no enzyme specificity (unspecific cleavage). Standard tryptic search parameters are not applicable. Use MHCquant or equivalent immunopeptidomics pipeline.

### Reference
Marcu A, Bichmann L, Kuchenbecker L, et al. HLA Ligand Atlas: a benign reference of HLA-presented peptides to improve T-cell-based cancer immunotherapy. J Immunother Cancer. 2021;9(4). doi:10.1136/jitc-2020-002071
