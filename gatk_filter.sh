#!/bin/bash

#SBATCH --job-name=filter_intervals
#SBATCH --output=filter_intervals.%J.out
#SBATCH --error=filter_intervals.%J.err
#SBATCH --partition=compute
#SBATCH --qos=common
#SBATCH --account=common
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --time=24:00:00
#SBATCH --mem=32G

#set -euo pipefail

echo "===== FilterIntervals STARTED ====="

# ------------------ PATHS ------------------ #

BASE_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026"

BED_FILE="${BASE_DIR}/hg38_ensembl/targets.preprocessed_ensembl.interval_list"
ANNOTATED_INTERVALS="${BASE_DIR}/hg38_ensembl/annotated_ensembl.interval_list"

READCOUNT_DIR="${BASE_DIR}/readCount_full"
FILTER_DIR="${BASE_DIR}/gc_filter"

CONTAINER="${BASE_DIR}/gatk_latest.sif"

# ------------------------------------------ #

mkdir -p "$FILTER_DIR"

FILTERED_INTERVALS="${FILTER_DIR}/gc.filtered.interval_list"

echo "Preparing TSV input list..."

TSV_LIST="${FILTER_DIR}/tsv_inputs.list"
> "$TSV_LIST"

for TSV in "$READCOUNT_DIR"/*_counts.tsv; do
    [[ -e "$TSV" ]] || { echo "❌ No TSV files found in $READCOUNT_DIR"; exit 1; }
    echo "$TSV" >> "$TSV_LIST"
done

echo "Running FilterIntervals..."

singularity run \
    --bind ${BASE_DIR}:${BASE_DIR} \
    ${CONTAINER} \
    gatk --java-options "-Xmx16G" FilterIntervals \
    -L "$BED_FILE" \
    --annotated-intervals "$ANNOTATED_INTERVALS" \
    --input "$TSV_LIST" \
    -imr OVERLAPPING_ONLY \
    -O "$FILTERED_INTERVALS"

echo "===== DONE ====="
echo "Output: $FILTERED_INTERVALS"
