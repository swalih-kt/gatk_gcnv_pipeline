#!/bin/bash

#SBATCH --job-name=ploidy_analysis
#SBATCH --output=ploidy.%J.out
#SBATCH --error=ploidy.%J.err
#SBATCH --partition=compute
#SBATCH --qos=common
#SBATCH --account=common
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --time=24:00:00
#SBATCH --mem=32G

set -euo pipefail

echo "===== DetermineGermlineContigPloidy STARTED ====="

# ------------------ PATHS ------------------ #

BASE_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026"

FILTERED_INTERVALS="${BASE_DIR}/gc_filter/gc.filtered.interval_list"
INPUT_TSV_DIR="${BASE_DIR}/readCount_full"
OUTPUT_DIR="${BASE_DIR}/ploidy_output"
PRIORS_FILE="${BASE_DIR}/priors.tsv"
CONTAINER="${BASE_DIR}/gatk_latest.sif"   # ⚠️ update this

# ------------------------------------------ #

mkdir -p "$OUTPUT_DIR"

OUTPUT_PREFIX="ploidy"

echo "Preparing TSV input list..."

TSV_LIST="${OUTPUT_DIR}/tsv_inputs.list"
> "$TSV_LIST"

for TSV in "$INPUT_TSV_DIR"/GDN*.tsv; do
    [[ -e "$TSV" ]] || { echo "❌ No TSV files found in $INPUT_TSV_DIR"; exit 1; }
    echo "$TSV" >> "$TSV_LIST"
done

echo "Running DetermineGermlineContigPloidy..."

singularity run \
    --bind ${BASE_DIR}:${BASE_DIR} \
    ${CONTAINER} \
    gatk --java-options "-Xmx16G" DetermineGermlineContigPloidy \
    -L "$FILTERED_INTERVALS" \
    --interval-merging-rule OVERLAPPING_ONLY \
    --input "$TSV_LIST" \
    --contig-ploidy-priors "$PRIORS_FILE" \
    --output "$OUTPUT_DIR" \
    --output-prefix "$OUTPUT_PREFIX"

echo "===== DONE ====="
echo "Output directory: $OUTPUT_DIR"
