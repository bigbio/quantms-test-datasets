# PXD063291 - E3 Activity-Based Proteomic Profiling (DIA)

## PRIDE Accession
PXD063291

## Title
E3 activity-based proteomic profiling of HEK293 cells treated with ATPgammaS

## Sample Processing Protocol
RNF213 is a novel transthiolating E3 ligase activated by ATP. An E3 activity-based probe was electroporated into HEK293 cells stably expressing RNF213 in a knockout background. Cells were co-electroporated with the poorly hydrolysable ATP analog ATPgS or buffer control.

## Data Processing Protocol
DIA analysis performed. Refer to the manuscript for detailed data processing description.

## Benchmark Description

### Variables Compared
- **ATPgS treatment vs buffer control**: Effect of ATP analog on E3 ligase activity
- **Condition A** (6 replicates): ATPgS-treated HEK293 cells
- **Condition B** (6 replicates): Buffer control HEK293 cells
- Total: 12 raw files

### Evaluation Criteria
- Differential protein abundance between treatment and control
- E3 ligase substrate identification
- DIA quantification reproducibility across replicates
- Statistical power for detecting treatment effects

### Note
This dataset was submitted as a zip file (PXD063291.zip). Extract before use. Raw files follow naming convention: 20221028_FL_Lu_SV_Set12_{A/B}{1-6}.raw

### Search Database
- **File**: `databases/UP000005640_9606.fasta` (in main databases directory)
- **Contents**: Human (UP000005640) Swiss-Prot reviewed
- **Species**: Homo sapiens

### Reference
Lamoliatte F, Virdee S. MRC Protein Phosphorylation and Ubiquitylation Unit, University of Dundee. No publication yet (submitted 2025-04-24).
