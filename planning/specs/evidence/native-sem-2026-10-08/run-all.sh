#!/bin/sh
# Run every evidence script from this directory and save its output to results/<script>.out.
# Each old output is deleted first, so a stale result can never pass for a fresh one, and the script
# exits NONZERO if any script fails (a failed script leaves an output file ending in a FAILED marker).
# Optional: LAVAAN_ALT_LIB=/path/to/library-with-another-lavaan  re-runs the lavaan probe under that version.
# Optional: REPS=5 for a quick benchmark.  Needs: nloptr, alabama, ucminf, lavaan, OpenMx, numDeriv, Matrix.
cd "$(dirname "$0")" || exit 2
mkdir -p results
failed=0
run() {  # run <label> <output file> <command...>
  label=$1; out=$2; shift 2
  rm -f "$out"
  echo "== $label"
  if ! "$@" > "$out" 2>&1; then
    echo "FAILED: $label (see $out)"; echo "FAILED: exit status nonzero" >> "$out"; failed=$((failed + 1))
  fi
}
for f in 01-probe-lavaan 02-p0-openmx-information 03-bench-optimizers 04-constrained-solvers 04b-constraint-contract 05-speed 05b-optimizer-speed 06-evaluator-prototype 07-preflight; do
  run "$f" "results/$f.out" Rscript "$f.R"
done
if [ -n "$LAVAAN_ALT_LIB" ]; then
  run "01-probe-lavaan (alt lavaan)" results/01-probe-lavaan-alt.out env R_LIBS="$LAVAAN_ALT_LIB" Rscript 01-probe-lavaan.R
fi
if [ "$failed" -gt 0 ]; then echo "$failed script(s) failed"; exit 1; fi
echo "all scripts ran"
