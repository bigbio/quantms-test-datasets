## Databases

This directory contains the databases used in the project. The databases are stored in fasta files with extensions fasta or fa.

### Layout

```
databases/
├── shared/         organism reference proteomes and contaminants
├── proteobench/    canonical ProteoBench FASTAs (copies live next to each module SDRF)
├── scripts/        Python utilities (FDRBench post-processing, QC, header rewriting)
├── PXD019643/      per-dataset FASTA (HLA ligand atlas — no benchmark folder yet)
└── PXD065380/      per-dataset FASTA (DIA CI .d test, used by testdata/dia_ci_dotd/)
```

Per-PXD FASTAs that have a matching benchmark folder live next to their SDRF in
`benchmarks/...` rather than under `databases/`. ProteoBench FASTAs are duplicated
into every module folder so each benchmark is self-contained; `databases/proteobench/`
remains the canonical source.

### ProteoBench Benchmark Databases

Official curated FASTA files from the [ProteoBench](https://proteobench.cubimed.rub.de/) project, used for the benchmark datasets in `benchmarks/`. Contaminant proteins use a `Cont_` prefix in the accession (e.g., `sp|Cont_P00761|TRYP_PIG`).

| File | Download | Contents | Proteins | Used By |
|------|----------|----------|----------|---------|
| `proteobench/ProteoBenchFASTA_MixedSpecies_HYE.fasta` | [HYE.zip](https://proteobench.cubimed.rub.de/fasta/ProteoBenchFASTA_MixedSpecies_HYE.zip) | Human (20,537) + Yeast (6,722) + E.coli (4,401) + Contaminants (381) | 31,889 | Modules 2, 3, 5, 7, 8, 10 |
| `proteobench/ProteoBenchFASTA_DDAQuantification_noecoli.fasta` | [HY.zip](https://proteobench.cubimed.rub.de/fasta/ProteoBenchFASTA_MixedSpecies_HY.zip) | Human + Yeast + Contaminants | 27,488 | Module 9 (single-cell) |

A copy of the right ProteoBench FASTA is placed in each module's benchmark folder
under `benchmarks/` so that each project is self-contained.

**Note for MaxQuant users**: Disable the built-in contaminants file — the ProteoBench FASTA already includes curated contaminants with `Cont_` prefix.

### UniProt Individual Proteomes

Swiss-Prot reviewed canonical sequences downloaded from [UniProt](https://www.uniprot.org/) (2026-03-24):

| File | Organism | UniProt Proteome | Taxonomy | Proteins |
|------|----------|-----------------|----------|----------|
| `shared/human_sp.fasta` | Homo sapiens | UP000005640 | 9606 | 20,416 |
| `shared/yeast_sp.fasta` | Saccharomyces cerevisiae (S288c) | UP000002311 | 559292 | 6,066 |
| `shared/ecoli_sp.fasta` | Escherichia coli (K12) | UP000000625 | 83333 | 4,403 |
| `shared/UP000005640_9606.fasta` | Homo sapiens (general human proteome) | UP000005640 | 9606 | 20,431 |

### Project-Specific Databases

Each per-PXD FASTA lives next to its SDRF inside the matching `benchmarks/` (or
`testdata/`) folder.

| FASTA | Species | Location |
|-------|---------|----------|
| `PXD001819_uniprot_yeast_ups.fasta` | Yeast + UPS1 (48 human proteins) | `benchmarks/lfq/LTQOrbitrapVelos/PXD001819/` |
| `PXD007683_UP000005640_UP000002311_reviewed.fasta` | Human + Yeast | `benchmarks/lfq/OrbitrapFusionLumos/PXD007683/` + `benchmarks/tmt/OrbitrapFusionLumos/PXD007683/` |
| `PXD009449_UP000005640_synthesized.fasta` | Human (synthetic peptides) | `benchmarks/lfq/OrbitrapFusionLumos/PXD009449/` |
| `PXD026600_REF_EColi_K12_UPS1_combined.fasta` | E.coli + UPS1 | `benchmarks/dia/OrbitrapFusion/PXD026600/` |
| `PXD054559_UP000005640_contaminants.fasta` | Human + contaminants | `benchmarks/tmt/OrbitrapEclipse/PXD054559/` |
| `UP000005640_9606.fasta` (copy of `shared/`) | Human reference + contaminants | `benchmarks/lfq/OrbitrapAstral/PXD046453/` + `benchmarks/dia/OrbitrapFusionLumos/PXD063291/` |
| `PXD019643_UP000005640_.fasta` | Human | `databases/PXD019643/` (no benchmark folder yet) |
| `PXD065380.fasta` | Human | `databases/PXD065380/` (used by `testdata/dia_ci_dotd/`) |

The denovo module (`benchmarks/denovo/MultiInstrument/ProteoBench_Module_11/`)
does not use a single FASTA — de novo sequencing predicts peptides directly
from spectra. See its `DESCRIPTION.md` for the per-species PRIDE accessions.

### Contaminants databases

- [shared/contaminants-202105-uniprot.fasta](shared/contaminants-202105-uniprot.fasta): The merge of crap-202105.fasta and contaminants-mq-202105.fasta from the [MaxQuant](https://www.maxquant.org/) software, restricted to entries with a UniProt accession number. Used to filter out common contaminants from the search results.

- [shared/contaminants-202105-uniprot-description.fasta](shared/contaminants-202105-uniprot-description.fasta): Based on the file above, with the UniProt accession number and the protein description added.

### Decoy and Entrapment databases

We use the [FDRBench](https://github.com/Noble-Lab/FDRBench) to generate the decoy and entrapment databases for the DDA and DIA searches. 

### End-to-end workflow

1) Prerequisites

- Java 8+ (for FDRBench)
- Python 3.8+
- Python deps: `requests`, `urllib3` (for description fetching)

2) Prepare contaminants with UniProt descriptions

- Start from `contaminants-202105-uniprot.fasta`.
- Append UniProt description, OS/OX, and GN to each header (cached and resilient to API outages):

```bash
python databases/scripts/contaminants_uniprot_description.py \
  --input databases/shared/contaminants-202105-uniprot.fasta \
  --output databases/shared/contaminants-202105-uniprot-description.fasta
```

Optional quick QC (expect zero):

```bash
awk 'BEGIN{s=0;g=0} /^>/{if($0!~/ OS=/)s++; if($0!~/ GN=/)g++} END{print "missing_OS="s, "missing_GN="g}' \
  databases/shared/contaminants-202105-uniprot-description.fasta
```

3) Generate DDA database with FDRBench

- Choose your target database (e.g., reviewed human proteome) and include contaminants as desired (concatenate FASTAs prior to this step if needed).
- Run FDRBench to add entrapment and decoys:

```bash
java -jar databases/fdrbench-0.0.2/fdrbench-0.0.2.jar \
  -level protein \
  -db {database_name}.fasta \
  -o {database_name_output}.fasta \
  -I2L -fix_nc c -check \
  -decoy -decoy_label DECOY_ -decoy_pos 0 \
  -entrapment_label ENTRAP_ -entrapment_pos 0
```

- Normalize headers so `DECOY_`/`ENTRAP_` labels propagate consistently to accession and entry name:

```bash
python databases/scripts/fdrbench_accessions.py \
  --input {database_name_output}.fasta \
  --output output.fasta
```

- Optionally, if FDRBench produced headers containing `_p_target` markers for entrapment, normalize them:

```bash
python databases/scripts/accession_entrap.py input.fasta output.fasta
```

4) Generate DIA database with FDRBench

```bash
java -jar databases/fdrbench-0.0.2/fdrbench-0.0.2.jar \
  -level protein \
  -db {database_name}.fasta \
  -o {database_name_output}.fasta \
  -I2L -diann -uniprot -fix_nc c -check \
  -entrapment_label ENTRAP_ -entrapment_pos 0
```

- Normalize headers as in DDA:

```bash
python databases/scripts/fdrbench_accessions.py \
  --input {database_name_output}.fasta \
  --output output.fasta
```

5) Post-generation checks (recommended)

- Validate that all headers have organism and gene name fields:

```bash
awk 'BEGIN{s=0;g=0} /^>/{if($0!~/ OS=/)s++; if($0!~/ GN=/)g++} END{print "missing_OS="s, "missing_GN="g}' output.fasta
```

- Optional deeper QA is available in `databases/scripts/fasta_quality_control.py`.

#### DDA database generation: 

```bash 
$ java -jar fdrbench-0.0.2/fdrbench-0.0.2.jar -level protein -db {database_name}.fasta -o {database_name_output}.fasta -I2L -fix_nc c -check -decoy -decoy_label DECOY_ -decoy_pos 0 -entrapment_label ENTRAP_ -entrapment_pos 0
```

The following command line will generate an entrapment protein (prefix: `ENTRAP_`) and two decoy proteins (prefix: `DECOY_`) for each target protein.

This command will generate the following proteins for each target protein:

> sp|A0A087X1C5|CP2D7_HUMAN Putative cytochrome P450 2D7 OS=Homo sapiens OX=9606 GN=CYP2D7 PE=5 SV=1
MGLEALVPLAMLVALFLLLVDLMHRHQRWAARYPPGPLPLPGLGNLLHVDFQNTPYCFDQLRRRFGDVFSLQLAWTPVVVLNGLAAVREAMVTRGEDTADRPPAPLYQVLGFGPRSQGVLLSRYGPAWREQRRFSVSTLRNLGLGKKSLEQWVTEEAACLCAAFADQAGRPFRPNGLLDKAVSNVLASLTCGRRFEYDDPRFLRLLDLAQEGLKEESGFLREVLNAVPVLPHLPALAGKVLRFQKAFLTQLDELLTEHRMTWDPAQPPRDLTEAFLAKKEKAKGSPESSFNDENLRLVVGNLFLAGMVTTSTTLAWGLLLMLLHLDVQRGRRVSPGCPLVGTHVCPVRVQQELDDVLGQVRRPEMGDQAHMPCTTAVLHEVQHFGDLVPLGVTHMTSRDLEVQGFRLPKGTTLLTNLSSVLKDEAVWKKPFRFHPEHFLDAQGHFVKPEAFLPFSAGRRACLGEPLARMELFLFFTSLLQHFSFSVAAGQPRPSHSRVVSFLVTPSPYELCAVPR

> ENTRAP_sp|A0A087X1C5|CP2D7_HUMAN
ALGFLMLLLHVMLDVLALAMPELVRQHRAWARNPPLLDDLPLTGPLGFHFPYLQPYCVNQGRRRAAQFLWLFGVTVVLSAGLVVDPNRMTVAERATDDEGRALGVYFPPPLGQPRSSVQGLLRWYPAGRQERRTVFLSSRLGGNLKKFEQACCTAASLEAWALGDQVAERFPRNLGPDLKVGLNTSVASALCRRFEYPDDRLFRGLLQEALDLKGSEFLERLPLVAGVLPPLANHAEVKLVRQFKLTFLEQELHDTLARWQPPPDMTARLFTADLAEKKEKAKSPSSENNFELDGRTFLLLTGDLSLAGTVNLVGMHLTWLVMLLAQVRGRRVVPVGCGLHSCPVTPRDQGEQLVDLVQVRRGGPLAMPAFTVLQMPCVQVELDGHDTHEHTHVSMTRDELGFVQRPLKLVNLSLSTGTTLKDEVAWKKFPRQFAFLVPHHGHDFEKFPSFPEGAALRRAPCEALLGRFQEFFLPALLLSMVQTGHFSAFSRSHPSRVPPVCPESLTAVSYVFLR

> DECOY_sp|A0A087X1C5|CP2D7_HUMAN
VLAHAPLMLGFLMVLAELLVDMLLRQHRWAARLQYVPLPPPGHDPLLLFDTYGGPNCFLQNRRRALWVVLPQGSAVLLAFGFVNDTVRTVMEARGDEADTRFVPPPYPGGALLQRGSLVQSLRAPYWGRQERRSSFVLTRGGLLNKKLAEGFTAEADWSAAQEAVCLQCRFPRDLNGLPKSGLCNAVTSVALRREFPYDDRLFRGQLAEDLLLKEGELFSRAAVELLAPLPGVHLPNVKLVRQFKAFDEHLTLLETLQRAPTPDMPWQRFAELTLADKKEKAKNLSGSPENFDSERTTDLLMSGVGTLQWLFNMLVLLLAVTVHLGALRGRRVGPVHVPGTPVCSCLRDQDQGVVVLQLERRLFHVVLMMGPHGMLHGQVTETHDDTPCPTAEQVASREGDFQLVRPLKSLTNTLLSVTGLKVDAEWKKFPRLPEHAFFHVGDHQFKFALPEPFGASRRCALLPGEARAHELGFLFTVFSLSFFQQASMPLRSPSHRPSAFPYLVVLVVTEPCSR

We fixed the accessions after running the FDRBench to have every prefix `DECOY`, `ENTRAP` or `CONTAM` in the accession and also the name of each protein. For that we runs the script: 

```bash
python databases/scripts/fdrbench_accessions.py --input {database_name_output}.fasta --output output.fasta
```

The `output.fasta` file is the final DDA database and can be renamed to the final name (e.g. `Homo-sapiens-uniprot-reviewed-contam-entrap-decoy-20241105.fasta`).

#### DIA database generation: 

```bash
$ java -jar fdrbench-0.0.2/fdrbench-0.0.2.jar -level protein -db {database_name}.fasta -o {database_name_output}.fasta -I2L -diann -uniprot -fix_nc c -check -entrapment_label ENTRAP_ -entrapment_pos 0
```

The following command line will generate an entrapment protein (prefix: `ENTRAP_`) for each target protein:

>sp|A0A087X1C5|CP2D7_HUMAN Putative cytochrome P450 2D7 OS=Homo sapiens OX=9606 GN=CYP2D7 PE=5 SV=1
MGLEALVPLAMLVALFLLLVDLMHRHQRWAARYPPGPLPLPGLGNLLHVDFQNTPYCFDQLRRRFGDVFSLQLAWTPVVVLNGLAAVREAMVTRGEDTADRPPAPLYQVLGFGPRSQGVLLSRYGPAWREQRRFSVSTLRNLGLGKKSLEQWVTEEAACLCAAFADQAGRPFRPNGLLDKAVSNVLASLTCGRRFEYDDPRFLRLLDLAQEGLKEESGFLREVLNAVPVLPHLPALAGKVLRFQKAFLTQLDELLTEHRMTWDPAQPPRDLTEAFLAKKEKAKGSPESSFNDENLRLVVGNLFLAGMVTTSTTLAWGLLLMLLHLDVQRGRRVSPGCPLVGTHVCPVRVQQELDDVLGQVRRPEMGDQAHMPCTTAVLHEVQHFGDLVPLGVTHMTSRDLEVQGFRLPKGTTLLTNLSSVLKDEAVWKKPFRFHPEHFLDAQGHFVKPEAFLPFSAGRRACLGEPLARMELFLFFTSLLQHFSFSVAAGQPRPSHSRVVSFLVTPSPYELCAVPR

>sp|ENTRAP_A0A087X1C5|ENTRAP_CP2D7_HUMAN Putative cytochrome P450 2D7 OS=Homo sapiens OX=9606 GN=ENTRAP_CYP2D7 PE=5 SV=1
VLAHAPLMLGFLMVLAELLVDMLLRQHRWAARLCVHLGDPLFPYLGQGTPPLPYNPLFDQNRRRNGPLDVTVLAAVFSVFWLGAVQLRVAEMTREDADTGRPLQPYFGPAVLGPRQLLSSGVRAWGPYRQERRSSLFTVRGGLLNKKAFEACSCAEEGWALAAQVTDLQRFPRDPLGLNKTSAASVLVLNGCRRFEDPDYRLFRALLGEDQLLKSFEGLERLPHVAVGPLLALAVNPEKLVRQFKETHLTALEFLLDQRPDTMPAPWQRDEFLAATLKKEKAKFSNEGNDSSEPLRNVTTFLMTTVLLAMLHGQLLGLDLVGLWVLSARGRRLVVVTPVCSPPCGGHRDQDLEGQQLVVVRRVMTTTQLSLDGAVPPCDEQLHEGHFTMPAGMHHVVREQLVDGFRPLKGTTLNLLVSTSLKAWVDEKKFPRLVHQFAHPDEFFHGKFLGESAFPPARRPLCLGAAERLAGFTSFPVFEQMSQLFHLASFLRHPSSRVLLPFCVVTVAEYPSPSR

