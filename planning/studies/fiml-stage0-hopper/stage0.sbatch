#!/bin/bash
# DRAFT, NOT SUBMITTED. Submission needs the maintainer's approval of this exact file.
# 60 cells x 100 chunks of 25 datasets = 6000 tasks, one core each. Cost (6 bootstrap calls/dataset, no refit sharing):
#   25 datasets x ~(3 x 114 s) ~ 2.4 h per task  ->  ~600 core-days, OVER the 250 core-day cap (see README).
#SBATCH --job-name=medfit-stage0
#SBATCH --account=2016507
#SBATCH --partition=general
#SBATCH --cpus-per-task=1
#SBATCH --mem=3G
#SBATCH --time=04:00:00
#SBATCH --array=1-6000%96
#SBATCH --output=/carc/scratch/users/%u/medfit-stage0/logs/%A_%a.out
set -euo pipefail
ROOT=/carc/scratch/users/$USER/medfit-stage0
module purge
module load r/4.4.0-fyqw openblas/0.3.23-rb3t gcc/11.2.0-hp2h cmake/3.27.9-fab7
export R_LIBS_USER="$ROOT/Rlib" OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 STAGE0_FINGERPRINT="$ROOT/env-fingerprint.txt"
sha256sum -c "$STAGE0_FINGERPRINT.sha256" >/dev/null
T=$((SLURM_ARRAY_TASK_ID - 1)); CELL=$((T / 100 + 1)); CHUNK=$((T % 100))
FIRST=$((CHUNK * 25 + 1)); LAST=$((CHUNK * 25 + 25))
cd "$ROOT/src/medfit"
test -z "$(git status --porcelain)"
Rscript planning/studies/fiml-stage0-hopper/run-chunk.R "$CELL" "$FIRST" "$LAST" "$ROOT/out"
