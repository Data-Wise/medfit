#!/bin/sh
# Run both fixtures from this directory and save each output to results/<script>.out.
# Each old output is deleted first, so a stale result can never pass for a fresh one; the script exits NONZERO if any
# fixture fails (a failed ASSERT makes the fixture exit nonzero, and the output then ends in a FAILED marker).
# Needs: nloptr, pkgload, and the medfit sources at the package root, four levels up.
cd "$(dirname "$0")" || exit 2
mkdir -p results
failed=0
for f in 01-stationarity-units 02-nnls-dependent-columns; do
  out="results/$f.out"
  rm -f "$out"
  echo "== $f"
  if ! Rscript "$f.R" > "$out" 2>&1; then
    echo "FAILED: $f (see $out)"; echo "FAILED: exit status nonzero" >> "$out"; failed=$((failed + 1))
  fi
done
if [ "$failed" -gt 0 ]; then echo "$failed fixture(s) failed"; exit 1; fi
echo "all fixtures passed"
