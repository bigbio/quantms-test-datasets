# relink CI Test Data

Test data for the [relink](https://github.com/bigbio/relink) crosslinking mass spectrometry pipeline.

## Dataset: PXD042173

DSSO-crosslinked recombinant protein standards (Clasen et al., 2023, Nature Methods).

- **SDRF**: `PXD042173_2files.sdrf.tsv` (2 RAW files from the full 177-file dataset)
- **FASTA**: 320 proteins, hosted on PRIDE FTP
- **Crosslinker**: DSSO (MS-cleavable)
- **Instrument**: Orbitrap Fusion Lumos

## RAW Files (downloaded by Nextflow from PRIDE FTP)

- `L1_20210727_MxR_FDR_firstbatch_DSSOplate2_B12.raw`
- `L1_20210727_MxR_FDR_firstbatch_DSSOplate2_E12.raw`

## Engine Configs

- `xi_linear.conf` - xiSEARCH linear search configuration
- `xi_crosslinking.conf` - xiSEARCH crosslink search configuration

## Test Profiles

- `test_xisearch` - xiSEARCH + xiFDR path
- `test_scout` - Scout + Scout FDR path
