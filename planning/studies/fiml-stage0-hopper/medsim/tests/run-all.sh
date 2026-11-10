#!/bin/bash
# Run the whole adapter verification, LOCAL ONLY (about 15 minutes on one core: parity 6 min, mutant 1 min, defects 4 min). From the repo root:
#   STAGE0_FINGERPRINT=<file with a "medfit_commit <sha>" line, plus <file>.sha256> STAGE0_MEDSIM_LIB=<library with medsim> \
#   STAGE0_MEDSIM_COMMIT=<40-hex commit that library was built from> STAGE0_B=40 STAGE0_DRAWS=200 STAGE0_ALLOW_ANY_COMMIT=1 \
#   bash planning/studies/fiml-stage0-hopper/medsim/tests/run-all.sh <empty workdir>
# Use a private library directory for medsim: a shared scratch lib can be modified by other sessions.
# (STAGE0_ALLOW_ANY_COMMIT only because a local HEAD differs from the fingerprinted commit; never set it for a real run.)
set -eo pipefail
W=${1:?empty workdir}; T=planning/studies/fiml-stage0-hopper/medsim/tests
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
Rscript $T/parity.R "$W/parity"
Rscript $T/parity.R "$W/mutant" mutant
Rscript $T/defects.R "$W/defects" | grep -E "^(PASS|FAIL|DEFECTS|--)"
