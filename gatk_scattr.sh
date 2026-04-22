#!/bin/bash


#SBATCH --job-name=scatter_intervals
#SBATCH --output=scatter_intervals.%J.out
#SBATCH --error=scatter_intervals.%J.err
#SBATCH --partition=compute
#SBATCH --qos=common
#SBATCH --account=common
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --time=24:00:00
#SBATCH --mem=32G

# Paths
INPUT="gc_filter/gc.filtered.interval_list"
OUTPUT_DIR="scatter_asd"
CONTAINERS="/lustre/tancia.p/swalih_cnv/analysis_2026"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "▶ Running IntervalListTools..."

# Run GATK using Singularity
singularity run --bind ${CONTAINERS} ${CONTAINERS}/gatk_latest.sif gatk IntervalListTools \
    --INPUT "$INPUT" \
    --SUBDIVISION_MODE INTERVAL_COUNT \
    --SCATTER_CONTENT 10000 \
    --OUTPUT "$OUTPUT_DIR"

echo "✅ Scatter completed!"
