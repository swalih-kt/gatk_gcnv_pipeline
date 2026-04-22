#!/bin/bash

#SBATCH --job-name=oldBam_analysis
#SBATCH --output=pipeline.%J.out
#SBATCH --error=pipeline.%J.err
#SBATCH --partition=compute
#SBATCH --qos=common
#SBATCH --account=common
#SBATCH --nodes=4
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=20
#SBATCH --time=24:00:00
#SBATCH --mem=50G
# ------------------ PATHS ------------------ #


REFERENCE_GENOME="/lustre/tancia.p/swalih_cnv/analysis_2026/reference/resources_broad_hg38_v0_Homo_sapiens_assembly38.fasta"
BED_FILE="/lustre/tancia.p/swalih_cnv/analysis_2026/hg38_ensembl/targets.preprocessed_ensembl.interval_list"
BAM_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026/Bams/old_bam_ASD"
OUTPUT_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026/read_count_oldBam"

# Singularity container path
CONTAINER="/lustre/tancia.p/swalih_cnv/analysis_2026/gatk_latest.sif"

# Base directory to bind (VERY IMPORTANT)
BASE_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026"

# ------------------------------------------ #

mkdir -p "$OUTPUT_DIR"

echo "Starting CollectReadCounts with Singularity..."

# Loop through BAM files
for BAM in "$BAM_DIR"/*.bam; do

    BASENAME=$(basename "$BAM" .bam)
    OUTPUT_FILE="${OUTPUT_DIR}/${BASENAME}_counts.tsv"

    echo "▶ Processing: $BAM"

    singularity run \
        --bind ${BASE_DIR}:${BASE_DIR} \
        ${CONTAINER} \
        gatk --java-options "-Xmx8G" CollectReadCounts \
        -L "$BED_FILE" \
        -R "$REFERENCE_GENOME" \
        -imr OVERLAPPING_ONLY \
        -I "$BAM" \
        --format TSV \
        -O "$OUTPUT_FILE"

    echo "Done: $BASENAME"

done

echo "🎉 All BAM files processed!"
