# GATK gCNV Pipeline (Cohort Mode)

A complete pipeline for germline copy number variant (gCNV) calling using GATK in **cohort mode**, designed for large-scale exome datasets on HPC clusters using **Singularity** and **SLURM**.

---

## Pipeline Overview

| Step | Tool | Script |
|------|------|--------|
| 1 | PreprocessIntervals | gatk_PreprocessIntervals.txt |
| 2 | AnnotateIntervals | gatk_AnnotateIntervals.txt |
| 3 | CollectReadCounts | `gatk_collect_upt.sh` |
| 4 | FilterIntervals | `gatk_filter.sh` |
| 5 | ScatterIntervals | `gatk_scattr.sh` |
| 6 | DetermineGermlineContigPloidy | `gatk_det.sh` |
| 7 | GermlineCNVCaller | `gatk_cnv_updt.sh` |
| 8 | PostprocessGermlineCNVCalls | `gatk_post_cnv.sh` |

---

## Environment

- **Cluster**: SLURM-based HPC
- **Container**: Singularity (`gatk_latest.sif`)
- **Reference**: `Homo_sapiens_assembly38` (hg38)
- **Base directory**: `/lustre/tancia.p/swalih_cnv/analysis_2026/`

---

## Step 1: PreprocessIntervals

**Purpose**: Prepares the target interval list for exome data. Pads regions and bins intervals to standardize the input for all downstream steps.

| | |
|---|---|
| **Input** | Raw target interval list (`targets.interval_list`), reference FASTA |
| **Output** | `targets.preprocessed_ensembl.interval_list` |
| **Key settings** | `--bin-length 0` (no binning for exome), `-imr OVERLAPPING_ONLY` |

> **Important**: Use `--padding 250` for exome data to capture reads near interval boundaries. This significantly improves sensitivity for variants near exon edges.

---

## Step 2: AnnotateIntervals

**Purpose**: Annotates each interval with GC content. This information is used later by `FilterIntervals` and `GermlineCNVCaller` to correct for GC bias in read depth.

| | |
|---|---|
| **Input** | Preprocessed interval list, reference FASTA |
| **Output** | `annotated_ensembl.interval_list` (TSV format) |
| **Key settings** | `-imr OVERLAPPING_ONLY` |

> **Important**: GC annotation is essential for denoising. Skipping this step will reduce CNV calling accuracy, especially in GC-rich or GC-poor regions.

---

## Step 3: CollectReadCounts

**Script**: `gatk_collect_upt.sh` | **SLURM**: 4 nodes, 20 CPUs, 50G RAM

**Purpose**: Counts the number of reads overlapping each interval for every BAM file. Produces one TSV count file per sample, which forms the core input for the cohort model.

| | |
|---|---|
| **Input** | All BAM files (`Bams/old_bam_ASD/*.bam`), preprocessed interval list, reference FASTA |
| **Output** | One `*_counts.tsv` per sample → `read_count_oldBam/` |
| **Format** | TSV |

> **Important**: All BAM files must be indexed (`.bai`). Output TSV filenames must be consistent as they are used as a batch input list in subsequent steps.

---

## Step 4: FilterIntervals

**Script**: `gatk_filter.sh` | **SLURM**: 1 node, 10 CPUs, 32G RAM

**Purpose**: Filters out low-quality intervals across the cohort based on GC content thresholds and read depth. Reduces noise in the model by removing intervals that are unreliable for CNV calling.

| | |
|---|---|
| **Input** | All sample TSVs (`readCount_full/*_counts.tsv`), preprocessed interval list, annotated intervals |
| **Output** | `gc_filter/gc.filtered.interval_list` |

> **Important**: A TSV input list file is auto-generated from the read count directory. The filtered interval list produced here is used in all downstream steps — filtering stringency directly affects sensitivity vs. specificity of final calls.

---

## Step 5: ScatterIntervals

**Script**: `gatk_scattr.sh` | **SLURM**: 1 node, 10 CPUs, 32G RAM

**Purpose**: Splits the filtered interval list into smaller chunks to enable parallel processing during `GermlineCNVCaller`. Each chunk is processed independently as a SLURM array task.

| | |
|---|---|
| **Input** | `gc_filter/gc.filtered.interval_list` |
| **Output** | 21 scatter chunks → `scatter_asd/temp_XXXX_of_21/scattered.interval_list` |
| **Key settings** | `SUBDIVISION_MODE INTERVAL_COUNT`, `SCATTER_CONTENT 10000` |

> **Important**: The number of scatter chunks (21) must match the array range in `gatk_cnv_updt.sh` (`--array=1-21`). Changing `SCATTER_CONTENT` will change the number of output chunks and requires updating the array job accordingly.

---

## Step 6: DetermineGermlineContigPloidy

**Script**: `gatk_det.sh` | **SLURM**: 1 node, 10 CPUs, 32G RAM

**Purpose**: Estimates the baseline ploidy of each contig for every sample using a contig ploidy prior. This is a required prerequisite for `GermlineCNVCaller` and ensures sex chromosomes and autosomes are modelled with the correct expected copy number.

| | |
|---|---|
| **Input** | Filtered interval list, all sample TSVs (`GDN*.tsv`), ploidy priors file (`priors.tsv`) |
| **Output** | `ploidy_output/ploidy-calls/` |

> **Important**: The `priors.tsv` file defines the prior probability of each copy number state (0, 1, 2, or 3 copies) for every contig. Most autosomes are set with near-certain diploid probability (ploidy 2 ≈ 0.99998), with tiny equal probabilities for monosomy and trisomy. Chromosomes with known higher aneuploidy rates (chr8, 9, 13, 18, 21, 22) use slightly relaxed priors. chrX and chrY use equal split priors between ploidy states to accommodate a mixed-sex cohort where ~50% of samples are male and ~50% are female. Incorrect priors will cause systematic errors in CNV calls, especially on sex chromosomes. Only `GDN*.tsv` files are used as input — ensure file naming matches this pattern.

---

## Step 7: GermlineCNVCaller

**Script**: `gatk_cnv_updt.sh` | **SLURM**: Array job — 21 tasks, 3 at a time, 7 CPUs / 12G RAM each

**Purpose**: Core CNV calling step. Runs a probabilistic model across all samples simultaneously (cohort mode) to detect copy number variants in each scatter chunk. Each SLURM array task processes one chunk independently.

| | |
|---|---|
| **Input** | Scatter interval list (per chunk), all sample TSVs, ploidy calls, annotated intervals |
| **Output** | Per-chunk model and calls → `cnv/folder_XXXX/cohort_run_XXXX-model/` and `cohort_run_XXXX-calls/` |
| **Run mode** | `COHORT` |

> **Important**: The array job (`--array=1-21%3`) runs 3 chunks at a time to balance speed and cluster resource usage. Both the `-model` and `-calls` output folders from every chunk are required for postprocessing — verify all 21 completed successfully before proceeding.

---

## Step 8: PostprocessGermlineCNVCalls

**Script**: `gatk_post_cnv.sh` | **SLURM**: 1 node, 10 CPUs, 32G RAM

**Purpose**: Combines all 21 scatter model and calls shards to produce final per-sample CNV output files. Generates three VCF outputs per sample covering denoised copy ratios, interval-level genotypes, and merged segments.

| | |
|---|---|
| **Input** | All 21 model shards (`cohort_run_XXXX-model`), all 21 calls shards (`cohort_run_XXXX-calls`), ploidy calls, sequence dictionary |
| **Output** | Per sample in `final_cnv/sample_N/`: denoised copy ratios VCF, genotyped intervals VCF, genotyped segments VCF |
| **Samples processed** | 122 samples (index 0–121) |

> **Important**: Sample indices (0–121) correspond to the order samples appear in the cohort TSV list used during `GermlineCNVCaller` — the order must be identical. `chrX` and `chrY` are flagged as allosomal contigs so ploidy is handled correctly for sex chromosomes.

---

## Output Files per Sample

| File | Description |
|------|-------------|
| `denoised-copy-ratios-*.vcf.gz` | Normalized copy ratio profile across intervals |
| `genotyped-intervals-*.vcf.gz` | CNV genotype calls at the interval level |
| `genotyped-segments-*.vcf.gz` | Final merged CNV segment calls (primary result) |

---

## Directory Structure

```
analysis_2026/
├── reference/                          # hg38 FASTA and .dict
├── hg38_ensembl/                       # Steps 1 & 2 outputs
├── Bams/old_bam_ASD/                   # Input BAM files
├── read_count_oldBam/                  # Step 3 outputs
├── readCount_full/                     # All cohort TSV count files
├── gc_filter/                          # Step 4 output
├── scatter_asd/                        # Step 5 output (21 chunks)
├── ploidy_output/                      # Step 6 output
├── cnv/                                # Step 7 output (21 folders)
├── final_cnv/                          # Step 8 output (122 sample folders)
├── priors.tsv                          # Contig ploidy priors
└── gatk_latest.sif                     # Singularity container
```

---

## References

- [GATK gCNV Cohort Mode Tutorial](https://gatk.broadinstitute.org/hc/en-us/articles/360035531152)
- [GermlineCNVCaller Docs](https://gatk.broadinstitute.org/hc/en-us/articles/360037593771)
- [PostprocessGermlineCNVCalls Docs](https://gatk.broadinstitute.org/hc/en-us/articles/360037593451)
- [GATK gCNV Best Practices](https://gatk.broadinstitute.org/hc/en-us/articles/360035890011)
