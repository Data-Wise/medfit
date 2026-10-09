#!/bin/sh
# Run every evidence script from this directory and save its output to results/<script>.out.
# Optional: LAVAAN_ALT_LIB=/path/to/library-with-another-lavaan  re-runs the lavaan probe under that version.
# Optional: REPS=5 for a quick benchmark.  Needs: nloptr, alabama, ucminf, lavaan, OpenMx, numDeriv, Matrix.
set -e
cd "$(dirname "$0")"
mkdir -p results
for f in 01-probe-lavaan 02-p0-openmx-information 03-bench-optimizers 04-constrained-solvers 04b-constraint-contract 05-speed 05b-optimizer-speed 06-evaluator-prototype; do
  echo "== $f"; Rscript "$f.R" > "results/$f.out" 2>&1 || echo "FAILED: $f (see results/$f.out)"
done
if [ -n "$LAVAAN_ALT_LIB" ]; then R_LIBS="$LAVAAN_ALT_LIB" Rscript 01-probe-lavaan.R > results/01-probe-lavaan-alt.out 2>&1; fi
