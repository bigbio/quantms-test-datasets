# PXD071075 — single-cell DIA on Orbitrap Eclipse

**PRIDE:** [PXD071075](https://www.ebi.ac.uk/pride/archive/projects/PXD071075)
**Instrument:** Thermo Orbitrap Eclipse
**Acquisition:** Label-free DIA, single-cell (FACS-sorted, ~1 cell per well)
**Samples:** 2,310
**Organism:** *Homo sapiens* (brain — neurons)
**FASTA:** [`UP000005640_9606.fasta`](UP000005640_9606.fasta) (human reference proteome, copy of `databases/shared/UP000005640_9606.fasta`)
**SDRF:** [`PXD071075.sdrf.tsv`](PXD071075.sdrf.tsv)

## Search parameters (canonical)

- Enzyme: Trypsin (`K*,R*,!*P`), missed cleavages: 2
- Modifications: Carbamidomethyl/C (fixed); Oxidation/M (variable); max-mods = 2
- Peptide length: 7–30; precursor charge: 2–4
- Precursor m/z: 400–800; fragment m/z: 200–1800
- Mass tolerances: MS1 5 ppm, MS2 10 ppm
- DIA window: 6 m/z
- q-value: 0.01; protein-group level: 2

These are encoded in `scripts/run_diann.sh` (lines 104–146) for the baseline
runs and resolved from the SDRF by the quantmsdiann pipeline for the sweep.

## Reference configs

The two reference Nextflow configs in this folder are kept for documentation —
they show the parameters used by ProteoBench-style version-comparison runs:

- [`run_PXD071075_v1_8_1.config`](run_PXD071075_v1_8_1.config) — DIA-NN 1.8.1
- [`run_PXD071075_v2_5_0.config`](run_PXD071075_v2_5_0.config) — DIA-NN 2.5.0

The scaling benchmark does **not** use these configs directly — it drives the
pipeline via `scripts/run_local.sh` (Nextflow head) and `scripts/run_diann.sh`
(direct DIA-NN) so it can vary cluster-side knobs without forking these files.

## Scaling benchmark

This benchmark also drives a 7-point scaling sweep documented in
[scaling/sweep_matrix.tsv](scaling/sweep_matrix.tsv):

> **Note on input format:** DIA-NN 1.8.1's bundled Thermo reader rejects the
> 2024 Orbitrap Eclipse `.raw` files ("Thermo RAW file format not supported").
> To work around this and to keep I/O timings comparable across versions, all
> points (baselines + sweep) read pre-converted `.mzML` files from
> `.../PXD071075-mzml/`. Conversion is done once using
> [scripts/convert_raw_to_mzml.sh](../../../scripts/convert_raw_to_mzml.sh):
>
> ```bash
> # 1) (Once) pull the singularity images we depend on:
> /hps/nobackup/juan/pride/reanalysis/scripts/pull_singularity_images.sh
>
> # 2) Submit a SLURM array job (one task per raw file, 50 concurrent by default):
> /hps/nobackup/juan/pride/reanalysis/scripts/convert_raw_to_mzml.sh \
>     /hps/nobackup/juan/pride/reanalysis/raw-data/benchmarks/PXD071075
> ```

| Point | Version | Kind | Cluster cores | queueSize | Notes |
|---|---|---|---|---|---|
| `v1_8_1_baseline_48cpu` | 1.8.1 | baseline | 48 | n/a | Single fat node, 300 GB, direct DIA-NN, reads mzML |
| `v2_5_0_baseline_48cpu` | 2.5.0 | baseline | 48 | n/a | Single fat node, 300 GB, direct DIA-NN, reads mzML |
| `v2_5_0_sweep_010cores` | 2.5.0 | sweep | 10 | 2 | Nextflow `pride_slurm`, queueSize = ceil(10/8) |
| `v2_5_0_sweep_020cores` | 2.5.0 | sweep | 20 | 3 | Nextflow `pride_slurm`, queueSize = ceil(20/8) |
| `v2_5_0_sweep_050cores` | 2.5.0 | sweep | 50 | 7 | Nextflow `pride_slurm`, queueSize = ceil(50/8) |
| `v2_5_0_sweep_100cores` | 2.5.0 | sweep | 100 | 13 | Nextflow `pride_slurm`, queueSize = ceil(100/8) |
| `v2_5_0_sweep_200cores` | 2.5.0 | sweep | 200 | 25 | Nextflow `pride_slurm`, queueSize = ceil(200/8) |

**queueSize formula** is `ceil(cluster_cores / 8)` where 8 ≈ cpus of the
dominant `process_medium` step in nf-core quantmsdiann. The total in-flight
core count is approximate — other `process_*` labels share the queue with
different sizings.

### How to run

From the cluster head node, after staging this repo:

```bash
# Preview the plan (no sbatch):
DRY_RUN=1 ./scripts/run_PXD071075_scaling.sh

# Submit the chain (7 sbatch calls, sequential via afterok):
./scripts/run_PXD071075_scaling.sh

# After the chain completes, aggregate + plot:
./scripts/collect_PXD071075_scaling.py
```

Result paths:
- Per-point: `/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075/<point_id>/`
  - Nextflow reports: `<point_id>/pipeline_info/` (`nextflow_report.html`, `nextflow_timeline.html`, `nextflow_trace.txt`)
- Aggregate: `/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075/timings.csv`
- Plots: `/hps/nobackup/juan/pride/reanalysis/quantmsdiann_results/PXD071075/plots/`
