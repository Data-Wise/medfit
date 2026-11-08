#!/bin/bash
# DRAFT, NOT RUN. Builds the pinned study environment on Hopper (run by the maintainer, interactively).
# Review items: exact R module build, compiler, how nloptr/S7/etc. are installed, library location.
set -euo pipefail
ROOT=/carc/scratch/users/$USER/medfit-stage0
SRC_SHA=${1:?usage: env-setup.sh <40-char medfit commit>}
module purge
module load r/4.4.0-fyqw gcc/8.5.0-lpgx   # system cmake (3.26.5) is used for nloptr; R module bundles OpenBLAS 0.3.26 (gcc 8.5.0); compiler matches it
mkdir -p "$ROOT/Rlib" "$ROOT/src" "$ROOT/out"
export R_LIBS_USER="$ROOT/Rlib" OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
# medfit source at the pinned commit (the maintainer copies it from a clean checkout; never an unpinned tree)
test -d "$ROOT/src/medfit/.git" || { test -f "$ROOT/medfit.bundle" && git clone -q "$ROOT/medfit.bundle" "$ROOT/src/medfit" || { echo "no clone and no $ROOT/medfit.bundle"; exit 1; }; }
git -C "$ROOT/src/medfit" checkout -q "$SRC_SHA"
test -z "$(git -C "$ROOT/src/medfit" status --porcelain)" || { echo "dirty tree"; exit 1; }
Rscript -e 'options(repos=c(CRAN="https://packagemanager.posit.co/cran/2026-11-01"))   # dated snapshot (verified reachable); install.packages(c("devtools","S7","checkmate","generics","MASS","nloptr","numDeriv","testthat","withr","rlang"))'
# Fingerprint: everything the results depend on, written once and referenced by every task.
FP="$ROOT/env-fingerprint.txt"
{ echo "medfit_commit $SRC_SHA"; module list 2>&1; cmake --version | head -1; gcc --version | head -1; uname -r; Rscript -e 'print(sessionInfo()); print(extSoftVersion()[["BLAS"]]); print(as.data.frame(installed.packages(lib.loc=Sys.getenv("R_LIBS_USER"))[,c("Package","Version")]))'; } > "$FP"
sha256sum "$FP" > "$FP.sha256"      # overwrite: a stale second line would fail every task; echo "fingerprint: $FP"
