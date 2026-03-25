# ProteoBench Module 11: De Novo Peptide Sequencing DDA HCD

## ProteoBench Module
https://github.com/Proteobench/ProteoBench/blob/main/docs/available-modules/active-modules/11-denovo-dda-hcd.md

## PRIDE Accessions
Multiple datasets from 9 species (Noble et al., 2024 balanced dataset):

| Species | PXD | Instrument | PSMs |
|---------|-----|------------|------|
| Vigna mungo | PXD005025 | Q Exactive | 102,255 |
| Mus musculus | PXD004948 | LTQ Orbitrap Velos | 25,522 |
| Methanosarcina mazei | PXD004325 | Q Exactive Plus | 100,485 |
| Bacillus subtilis | PXD004565 | Q Exactive | 113,234 |
| Candidatus Thiodiazotropha endoloripes | PXD004536 | Q Exactive Plus | 82,514 |
| Solanum lycopersicum | PXD004947 | Q Exactive | 100,056 |
| Saccharomyces cerevisiae | PXD003868 | Q Exactive Plus | 108,973 |
| Apis mellifera | PXD004467 | Q Exactive | 102,285 |
| Homo sapiens | PXD004424 | Q Exactive | 44,555 |

**Total**: 779,879 PSMs at 1% PSM-level FDR

## Title
De novo peptide sequencing benchmark across 9 species

## Sample Processing Protocol
Tryptic digests from 9 different organisms analyzed by DDA with HCD fragmentation on various Q Exactive family instruments. Each species dataset was independently acquired and deposited in PRIDE.

## Data Processing Protocol
PSMs filtered at 1% FDR. Balanced dataset assembled by Noble et al., 2024, selecting representative PSMs across species to avoid taxonomic bias. Precursor mass tolerance: 10 ppm. Fragment mass tolerance: 0.02 Da. Minimum peptide length: 7 residues.

## Benchmark Description

### What Is Being Benchmarked
**De novo peptide sequencing accuracy** — the ability of algorithms to correctly predict peptide sequences directly from MS/MS spectra without a reference database.

### Variables Compared
- **9 species**: Evaluating de novo accuracy across diverse proteomes (prokaryotes, eukaryotes, plants, animals)
- **Multiple instruments**: Q Exactive, Q Exactive Plus, LTQ Orbitrap Velos
- **PTM handling**: Carbamidomethyl (C, fixed), Oxidation (M, variable), Acetyl (N-term, variable)

### Evaluation Criteria
- Amino acid-level accuracy (per-residue prediction correctness)
- Full-sequence accuracy (complete peptide match rate)
- PTM prediction accuracy
- Performance across peptide lengths
- Species-specific biases in de novo prediction
- Handling of missing fragments and noise
- Comparison across de novo tools (Casanovo, Novor, pNovo, etc.)

### Search Database
- **No single database**: Each species uses its own reference proteome from UniProt.
- De novo sequencing does not require a FASTA database — sequences are predicted directly from spectra.
- For validation/benchmarking, species-specific databases from each PXD project should be used.

### Note
This is a **de novo sequencing** benchmark, fundamentally different from the quantification modules. The SDRF uses placeholder raw file names since the benchmark operates on pre-filtered PSM lists rather than raw files directly. The actual raw files should be downloaded from the individual PXD accessions listed above.

### Reference
Noble C, et al., 2024. Nine-species balanced benchmark dataset for de novo peptide sequencing.
