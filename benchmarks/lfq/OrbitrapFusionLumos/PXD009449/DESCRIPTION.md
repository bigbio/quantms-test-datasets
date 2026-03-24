# PXD009449 - ProteomeTools PTM Characterization (Phosphorylation subset)

## PRIDE Accession
PXD009449

## Title
Systematic characterization of 21 post-translational modifications using synthetic peptides

## Sample Processing Protocol
~5000 synthetic peptides carrying 21 different post-translational modifications were synthesized using Fmoc-based SPOT synthesis. Modified peptides and their unmodified counterparts were subjected to multimodal LC-MS analysis on an Orbitrap Fusion Lumos ETD mass spectrometer. Multiple fragmentation modes used: HCD, ETD, and combined HCD+ETD.

## Data Processing Protocol
MS/MS data identified using MaxQuant v1.5.3.30 against a database of concatenated peptide sequences. Raw spectra extracted using ThermoRAWFileReader. Chromatographic (retention time) and mass spectrometric properties (charges, scores, fragmentation, diagnostic ions, neutral losses) characterized using custom Python and R scripts.

## Benchmark Description

### Subset Used
- **Tyrosine Phosphorylation (Ymod_Phospho)** subset only
- Synthetic phosphopeptides with known modification sites

### Variables Compared
- **Modified vs unmodified peptides**: Phosphorylated tyrosine peptides vs their unmodified counterparts
- **Fragmentation modes**: HCD, ETD, combined HCD+ETD for phosphosite localization
- **Retention time shifts**: Chromatographic behavior changes upon phosphorylation

### Evaluation Criteria
- Phosphosite localization accuracy
- Fragmentation pattern analysis (neutral losses, diagnostic ions)
- Retention time prediction for phosphopeptides
- Sensitivity across different fragmentation strategies

### Reference
Zolg DP, Wilhelm M, Schmidt T, et al. ProteomeTools: Systematic characterization of 21 post-translational protein modifications by LC-MS/MS using synthetic peptides. Mol Cell Proteomics. 2018. doi:10.1074/mcp.tir118.000783
