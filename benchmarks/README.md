# Benchmark datasets

Curated benchmark datasets for quantms, grouped by acquisition type (`lfq`, `dia`,
`tmt`, `denovo`) and instrument. Each folder is self-contained: SDRF, FASTA,
and (where applicable) DIA-NN config/design live next to one another.

## ProteoBench modules

Datasets that back a [ProteoBench](https://proteobench.readthedocs.io/) module
are named `ProteoBench_Module_{N}/`. The PRIDE accession is listed below rather
than embedded in the folder name (one accession — PXD028735 — backs two
modules, and some modules combine multiple accessions).

| Module | PRIDE accession | Instrument | Acquisition | Folder |
|--------|-----------------|------------|-------------|--------|
| [2 — quant LFQ DDA Ion](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/2-quant-lfq-ion-dda/) | PXD028735 | Q Exactive HF | LFQ DDA | [lfq/QExactiveHF/ProteoBench_Module_2/](lfq/QExactiveHF/ProteoBench_Module_2/) |
| [3 — quant LFQ DDA Peptidoform](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/3-quant-lfq-peptidoform-dda/) | PXD028735 | Q Exactive HF | LFQ DDA | [lfq/QExactiveHF/ProteoBench_Module_3/](lfq/QExactiveHF/ProteoBench_Module_3/) |
| [5 — quant LFQ DIA Ion timsTOF](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/5-quant-lfq-ion-dia-tims/) | PXD062685 | timsTOF SCP | LFQ DIA | [dia/timsTOFSCP/ProteoBench_Module_5/](dia/timsTOFSCP/ProteoBench_Module_5/) |
| [7 — quant LFQ DIA Ion Astral](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/7-quant-lfq-ion-dia-astral/) | (no PXD; ProteoBench-curated) | Orbitrap Astral | LFQ DIA | [dia/OrbitrapAstral/ProteoBench_Module_7/](dia/OrbitrapAstral/ProteoBench_Module_7/) |
| [8 — quant LFQ DDA Ion Astral](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/8-quant-lfq-ion-dda-astral/) | (no PXD; ProteoBench-curated) | Orbitrap Astral | LFQ DDA | [lfq/OrbitrapAstral/ProteoBench_Module_8/](lfq/OrbitrapAstral/ProteoBench_Module_8/) |
| [9 — quant LFQ DIA Ion single-cell](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/9-quant-lfq-ion-dia-singlecell/) | PXD049412 | Orbitrap Astral | LFQ DIA (single-cell) | [dia/OrbitrapAstral/ProteoBench_Module_9/](dia/OrbitrapAstral/ProteoBench_Module_9/) |
| [10 — quant LFQ DIA Ion ZenoTOF](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/10-quant-lfq-ion-dia-zenotof/) | PXD070049 | ZenoTOF 8600 | LFQ DIA | [dia/ZenoTOF8600/ProteoBench_Module_10/](dia/ZenoTOF8600/ProteoBench_Module_10/) |
| [11 — denovo DDA HCD](https://proteobench.readthedocs.io/en/stable/available-modules/active-modules/11-denovo-dda-hcd/) | Multiple (9 species; see DESCRIPTION.md) | Multiple (QE / QE+ / Velos) | De novo DDA HCD | [denovo/MultiInstrument/ProteoBench_Module_11/](denovo/MultiInstrument/ProteoBench_Module_11/) |

Each module folder contains its `DESCRIPTION.md` with the full sample/data
processing protocol and exact raw-file inventory.

## Non-ProteoBench benchmarks

Datasets included for additional coverage (instrument breadth, PTM, spike-in,
single-organism reference) not yet aligned to a ProteoBench module.

| PRIDE accession | Instrument | Acquisition | Folder |
|-----------------|------------|-------------|--------|
| PXD001819 | LTQ Orbitrap Velos | LFQ DDA (yeast + UPS1 spike-in) | [lfq/LTQOrbitrapVelos/PXD001819/](lfq/LTQOrbitrapVelos/PXD001819/) |
| PXD007683 | Orbitrap Fusion Lumos | LFQ DDA (human + yeast) | [lfq/OrbitrapFusionLumos/PXD007683/](lfq/OrbitrapFusionLumos/PXD007683/) |
| PXD007683 | Orbitrap Fusion Lumos | TMT (same study) | [tmt/OrbitrapFusionLumos/PXD007683/](tmt/OrbitrapFusionLumos/PXD007683/) |
| PXD009449 | Orbitrap Fusion Lumos | LFQ DDA (phospho/PTM characterization) | [lfq/OrbitrapFusionLumos/PXD009449/](lfq/OrbitrapFusionLumos/PXD009449/) |
| PXD026600 | Orbitrap Fusion | DIA (E.coli + UPS1) | [dia/OrbitrapFusion/PXD026600/](dia/OrbitrapFusion/PXD026600/) |
| PXD046453 | Orbitrap Astral | LFQ DDA (HeLa, Astral DDA vs DIA comparison) | [lfq/OrbitrapAstral/PXD046453/](lfq/OrbitrapAstral/PXD046453/) |
| PXD054559 | Orbitrap Eclipse | TMT (human + contaminants) | [tmt/OrbitrapEclipse/PXD054559/](tmt/OrbitrapEclipse/PXD054559/) |
| PXD063291 | Orbitrap Fusion Lumos | DIA (HEK293 E3 activity profiling) | [dia/OrbitrapFusionLumos/PXD063291/](dia/OrbitrapFusionLumos/PXD063291/) |

## Folder layout

```
benchmarks/
├── denovo/MultiInstrument/ProteoBench_Module_11/
├── dia/
│   ├── OrbitrapAstral/{ProteoBench_Module_7, ProteoBench_Module_9}/
│   ├── OrbitrapFusion/PXD026600/
│   ├── OrbitrapFusionLumos/PXD063291/
│   ├── ZenoTOF8600/ProteoBench_Module_10/
│   └── timsTOFSCP/ProteoBench_Module_5/
├── lfq/
│   ├── LTQOrbitrapVelos/PXD001819/
│   ├── OrbitrapAstral/{PXD046453, ProteoBench_Module_8}/
│   ├── OrbitrapFusionLumos/{PXD007683, PXD009449}/
│   └── QExactiveHF/{ProteoBench_Module_2, ProteoBench_Module_3}/
├── tmt/
│   ├── OrbitrapEclipse/PXD054559/
│   └── OrbitrapFusionLumos/PXD007683/
└── download_raw.sh
```

Each folder typically contains:

- `*.sdrf.tsv` — sample annotation in SDRF-Proteomics format
- `DESCRIPTION.md` — benchmark description, raw-file inventory, reference
- `*.fasta` — search database for that benchmark (see `databases/README.md` for
  the canonical source of shared FASTAs)
- `diann_config.cfg` + `diann_design.tsv` — DIA-NN runner inputs (DIA only)
- `experimental_design.tsv` + `openms.tsv` — OpenMS/quantms runner inputs
  (LFQ/TMT DDA)
