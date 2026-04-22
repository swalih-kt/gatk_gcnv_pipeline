#!/bin/bash

#SBATCH --job-name=post_analysis
#SBATCH --output=post_cnv.%A_%a.out
#SBATCH --error=post_cnv.%A_%a.err
#SBATCH --partition=compute
#SBATCH --qos=common
#SBATCH --account=common
#SBATCH --nodes=1
#SBATCH --ntasks=1              # <U+1F448> only 1 task
#SBATCH --cpus-per-task=10       # <U+1F448> small CPU request
#SBATCH --mem=32G               # <U+1F448> enough memory       

#set -euo pipefail

echo "===== PostprocessGermlineCNVCalls STARTED ====="

# ------------------ PATHS ------------------ #

BASE_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026"

CONTAINER="${BASE_DIR}/gatk_latest.sif"

CONTIG_PLOIDY_CALLS="${BASE_DIR}/ploidy_output/ploidy-calls"
SEQUENCE_DICTIONARY="${BASE_DIR}/reference/resources_broad_hg38_v0_Homo_sapiens_assembly38.dict"

BASE_OUTPUT_DIR="${BASE_DIR}/final_cnv"
OUTPUT_PREFIX="cohort_run"

# ------------------------------------------ #

mkdir -p "$BASE_OUTPUT_DIR"

# -------- AUTO-GENERATE SHARD PATHS -------- #

MODEL_ARGS=""
CALLS_ARGS=""

for i in $(seq -f "%04g" 1 21); do

    MODEL_PATH="${BASE_DIR}/cnv/folder_${i}/cohort_run_${i}-model"
    CALLS_PATH="${BASE_DIR}/cnv/folder_${i}/cohort_run_${i}-calls"

    # Check existence (very useful debug)
    [[ -d "$MODEL_PATH" ]] || { echo "❌ Missing: $MODEL_PATH"; exit 1; }
    [[ -d "$CALLS_PATH" ]] || { echo "❌ Missing: $CALLS_PATH"; exit 1; }

    MODEL_ARGS="$MODEL_ARGS --model-shard-path $MODEL_PATH"
    CALLS_ARGS="$CALLS_ARGS --calls-shard-path $CALLS_PATH"

done

echo "All shard paths collected successfully."

# -------- LOOP THROUGH SAMPLES -------- #

for SAMPLE_INDEX in {0..121}; do

    SAMPLE_OUTPUT_DIR="${BASE_OUTPUT_DIR}/sample_${SAMPLE_INDEX}"
    mkdir -p "$SAMPLE_OUTPUT_DIR"

    echo "▶ Processing sample index: $SAMPLE_INDEX"

    singularity run \
        --bind ${BASE_DIR}:${BASE_DIR} \
        ${CONTAINER} \
        gatk --java-options "-Xmx8G" PostprocessGermlineCNVCalls \
        $MODEL_ARGS \
        $CALLS_ARGS \
        --allosomal-contig chrX \
        --allosomal-contig chrY \
        --contig-ploidy-calls "$CONTIG_PLOIDY_CALLS" \
        --sample-index "$SAMPLE_INDEX" \
        --output-denoised-copy-ratios "${SAMPLE_OUTPUT_DIR}/denoised-copy-ratios-${OUTPUT_PREFIX}-sample${SAMPLE_INDEX}.vcf.gz" \
        --output-genotyped-intervals "${SAMPLE_OUTPUT_DIR}/genotyped-intervals-${OUTPUT_PREFIX}-sample${SAMPLE_INDEX}.vcf.gz" \
        --output-genotyped-segments "${SAMPLE_OUTPUT_DIR}/genotyped-segments-${OUTPUT_PREFIX}-sample${SAMPLE_INDEX}.vcf.gz" \
        --sequence-dictionary "$SEQUENCE_DICTIONARY"

    echo "✔ Done sample: $SAMPLE_INDEX"

done

echo "===== ALL SAMPLES COMPLETED ====="
