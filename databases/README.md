## Databases

This directory contains the databases used in the project. The databases are stored in fasta files with extensions fasta or fa.

### ProteoBench Benchmark Databases

Official curated FASTA files from the [ProteoBench](https://proteobench.cubimed.rub.de/) project, used for the benchmark datasets in `benchmarks/`. Contaminant proteins use a `Cont_` prefix in the accession (e.g., `sp|Cont_P00761|TRYP_PIG`).

| File | Download | Contents | Proteins | Used By |
|------|----------|----------|----------|---------|
| `ProteoBenchFASTA_MixedSpecies_HYE.fasta` | [HYE.zip](https://proteobench.cubimed.rub.de/fasta/ProteoBenchFASTA_MixedSpecies_HYE.zip) | Human (20,537) + Yeast (6,722) + E.coli (4,401) + Contaminants (381) | 31,889 | Modules 2, 3, 5, 7, 8, 10 |
| `ProteoBenchFASTA_DDAQuantification_noecoli.fasta` | [HY.zip](https://proteobench.cubimed.rub.de/fasta/ProteoBenchFASTA_MixedSpecies_HY.zip) | Human + Yeast + Contaminants | 27,488 | Module 9 (single-cell) |

A copy named `database.fasta` is placed in each benchmark project directory under `benchmarks/`.

**Note for MaxQuant users**: Disable the built-in contaminants file — the ProteoBench FASTA already includes curated contaminants with `Cont_` prefix.

### UniProt Individual Proteomes

Swiss-Prot reviewed canonical sequences downloaded from [UniProt](https://www.uniprot.org/) (2026-03-24):

| File | Organism | UniProt Proteome | Taxonomy | Proteins |
|------|----------|-----------------|----------|----------|
| `human_sp.fasta` | Homo sapiens | UP000005640 | 9606 | 20,416 |
| `yeast_sp.fasta` | Saccharomyces cerevisiae (S288c) | UP000002311 | 559292 | 6,066 |
| `ecoli_sp.fasta` | Escherichia coli (K12) | UP000000625 | 83333 | 4,403 |

### Project-Specific Databases

| File | Species | Used By |
|------|---------|---------|
| `PXD001819_uniprot_yeast_ups.fasta` | Yeast + UPS1 (48 human proteins) | PXD001819 (LFQ spike-in) |
| `PXD007683_UP000005640_UP000002311_reviewed.fasta` | Human + Yeast | PXD007683 (LFQ/TMT comparison) |
| `PXD009449_UP000005640_synthesized.fasta` | Human (synthetic peptides) | PXD009449 (PTM characterization) |
| `PXD019643_UP000005640_.fasta` | Human | PXD019643 (HLA ligand atlas) |
| `PXD026600_REF_EColi_K12_UPS1_combined.fasta` | E.coli + UPS1 | PXD026600 (DIA benchmark) |
| `UP000005640_9606.fasta` | Human | General human proteome |

### Contaminants databases

- [contaminants.fasta](contaminants.fasta): A database of common contaminants in proteomics experiments. This database is used to filter out common contaminants from the search results. It is the merge of crap-202105.fasta and contaminants-mq-202105.fasta from the [MaxQuant](https://www.maxquant.org/) software.

- [contaminants-202105-uniprot.fasta](contaminants-202105-uniprot.fasta): Based on the contaminants.fasta file, this database contains only the contaminants that have a UniProt accession number.

- [contaminants-202105-uniprot-description.fasta](contaminants-202105-uniprot-description.fasta): Based on the contaminants-202105-uniprot.fasta file, this database contains the contaminants with the UniProt accession number and the protein description.

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
python databases/contaminants_uniprot_description.py \
  --input databases/contaminants-202105-uniprot.fasta \
  --output databases/contaminants-202105-uniprot-description.fasta
```

Optional quick QC (expect zero):

```bash
awk 'BEGIN{s=0;g=0} /^>/{if($0!~/ OS=/)s++; if($0!~/ GN=/)g++} END{print "missing_OS="s, "missing_GN="g}' \
  databases/contaminants-202105-uniprot-description.fasta
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
python databases/fdrbench_accessions.py \
  --input {database_name_output}.fasta \
  --output output.fasta
```

- Optionally, if FDRBench produced headers containing `_p_target` markers for entrapment, normalize them:

```bash
python databases/accession_entrap.py input.fasta output.fasta
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
python databases/fdrbench_accessions.py \
  --input {database_name_output}.fasta \
  --output output.fasta
```

5) Post-generation checks (recommended)

- Validate that all headers have organism and gene name fields:

```bash
awk 'BEGIN{s=0;g=0} /^>/{if($0!~/ OS=/)s++; if($0!~/ GN=/)g++} END{print "missing_OS="s, "missing_GN="g}' output.fasta
```

- Optional deeper QA is available in `databases/fasta_quality_control.py`.

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
python databases/fdrbench_accessions.py --input {database_name_output}.fasta --output output.fasta
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

