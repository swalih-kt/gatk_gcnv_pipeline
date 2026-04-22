#!/bin/bash

#SBATCH --job-name=cnv_intervals
#SBATCH --output=cnv_intervals.%A_%a.out
#SBATCH --error=cnv_intervals.%A_%a.err
#SBATCH --partition=compute
#SBATCH --qos=common
#SBATCH --account=common
#SBATCH --nodes=1
#SBATCH --ntasks=1              # 👈 only 1 task
#SBATCH --cpus-per-task=7       # 👈 small CPU request
#SBATCH --mem=12G               # 👈 enough memory
#SBATCH --time=24:00:00
#SBATCH --array=1-21%3          # 👈 2 jobs at a time


# Paths
SCATTER_DIR="scatter_asd"
COUNTS_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026/readCount_full"
ANNOTATED_INTERVALS="/lustre/tancia.p/swalih_cnv/analysis_2026/hg38_ensembl/annotated_ensembl.interval_list"
PLOIDY_CALLS="ploidy_output/ploidy-calls"
BASE_OUTPUT_DIR="/lustre/tancia.p/swalih_cnv/analysis_2026/"
CONTAINERS="/lustre/tancia.p/swalih_cnv/analysis_2026/"

# Get task ID
TASK_ID=$(printf "%04d" ${SLURM_ARRAY_TASK_ID})

# Interval file
INTERVAL_LIST="${SCATTER_DIR}/temp_${TASK_ID}_of_21/scattered.interval_list"

# Create output folder
OUTPUT_DIR="${BASE_OUTPUT_DIR}/cnv/folder_${TASK_ID}"
mkdir -p "$OUTPUT_DIR"

echo "▶ Running chunk ${TASK_ID}"
echo "📁 Output folder: $OUTPUT_DIR"

# Safety check (optional but recommended)
if [ ! -f "$INTERVAL_LIST" ]; then
    echo "❌ Missing: $INTERVAL_LIST"
    exit 1
fi

# Build input args
INPUT_ARGS=""
for FILE in "$COUNTS_DIR"/*.tsv; do
    INPUT_ARGS="$INPUT_ARGS -I $FILE"
done

# Run GATK
singularity run --bind ${CONTAINERS} ${CONTAINERS}/gatk_latest.sif gatk \
    --java-options "-Xmx10G" GermlineCNVCaller \
    --run-mode COHORT \
    -L "$INTERVAL_LIST" \
    $INPUT_ARGS \
    --contig-ploidy-calls "$PLOIDY_CALLS" \
    --annotated-intervals "$ANNOTATED_INTERVALS" \
    --interval-merging-rule OVERLAPPING_ONLY \
    --output "$OUTPUT_DIR" \
    --output-prefix cohort_run_${TASK_ID} \
    --verbosity INFO

echo "✅ Finished chunk ${TASK_ID}"
