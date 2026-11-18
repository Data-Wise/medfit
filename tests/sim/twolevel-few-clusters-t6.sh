#!/bin/bash
# Few-clusters design study, task T6 (planning/PLAN-few-clusters-design-study-2026-11-16.md): the main delta and MC
# run on all 120 cells, R = 1000, MC_B = 2000, and P1 (EPS = 1e-3) on the cells of
# planning/studies/few-clusters/T6-p1-cells.csv (decision M7). One driver call and one CSV per cell; a rerun skips
# the cells whose CSV exists, so the run resumes after an interruption.
#
# Environment (defaults in brackets):
#   W      work directory, outside git [<repo>/_agents_workspace/fc-t6]
#   CORES  mclapply cores per cell [10]
#   REPS   replicates per cell [1000]; seeds cell_id * 1e5 + rep (L'Ecuyer-CMRG), as in the driver
#   MC_B   MC draws per dataset [2000]
#   EPS    P1 floor [1e-3]
#   CELLS  space-separated cell ids [all 120, 1001 to 1120]
#
# Layout under W: lib/ (medfit installed from HEAD, SHA in install-sha.txt), snap/ (driver, libs and P1 list from
# HEAD, hashes in snap-sha256.txt), rows/cell-<id>-R<REPS>.csv, logs/cell-<id>-R<REPS>.log, logs/progress-R<REPS>.txt
# ("cell exit seconds" per cell), logs/done-R<REPS> once every requested cell has its CSV.
# Aggregate afterwards with tests/sim/twolevel-few-clusters-t6-aggregate.R.
set -u
REPO=$(cd "$(dirname "$0")/../.." && pwd)
W=${W:-$REPO/_agents_workspace/fc-t6}
CORES=${CORES:-10}
REPS=${REPS:-1000}
MC_B=${MC_B:-2000}
EPS=${EPS:-1e-3}
CELLS=${CELLS:-$(seq 1001 1120)}
SHA=$(git -C "$REPO" rev-parse HEAD)
mkdir -p "$W/rows" "$W/logs"

# medfit at HEAD into a scratch library and the study scripts from HEAD into snap/, once per work directory: a
# resumed run keeps the install and snapshot it started with (delete W/lib or W/snap to refresh them)
if [ ! -f "$W/install-sha.txt" ]; then
  rm -rf "$W/src" "$W/lib" && mkdir -p "$W/src" "$W/lib"
  git -C "$REPO" archive HEAD | tar -x -C "$W/src"
  R CMD INSTALL -l "$W/lib" "$W/src" > "$W/logs/install.log" 2>&1 || {
    echo "install failed, see $W/logs/install.log" >&2; exit 1; }
  echo "$SHA" > "$W/install-sha.txt"
fi

if [ ! -f "$W/snap/sha.txt" ]; then
mkdir -p "$W/snap/tests/sim" "$W/snap/planning/studies/few-clusters"
for f in tests/sim/twolevel-few-clusters.R tests/sim/twolevel-few-clusters-lib.R \
         tests/sim/twolevel-few-clusters-t6-lib.R planning/studies/few-clusters/T6-p1-cells.csv; do
  git -C "$REPO" show "HEAD:$f" > "$W/snap/$f" || { echo "cannot snapshot $f at HEAD" >&2; exit 1; }
done
(cd "$W/snap" && shasum -a 256 tests/sim/*.R planning/studies/few-clusters/*.csv) > "$W/snap-sha256.txt"
echo "$SHA" > "$W/snap/sha.txt"
fi
[ "$(cat "$W/install-sha.txt")" = "$(cat "$W/snap/sha.txt")" ] || {
  echo "W/lib and W/snap come from different commits; delete both to refresh" >&2; exit 1; }
RUN_SHA=$(cat "$W/install-sha.txt")
[ "$RUN_SHA" = "$SHA" ] || echo "note: running the install and snapshot of $RUN_SHA, not HEAD $SHA" >&2
R_LIBS="$W/lib" Rscript -e 'library(medfit); library(lavaan); print(sessionInfo())' > "$W/logs/sessionInfo.txt" 2>&1

P1=$(tail -n +2 "$W/snap/planning/studies/few-clusters/T6-p1-cells.csv" | cut -d, -f1 | tr '\n' ' ')
cd "$W/snap" || exit 1
for c in $CELLS; do
  f=$W/rows/cell-$c-R$REPS.csv
  [ -f "$f" ] && continue
  case " $P1 " in *" $c "*) arms=p0,p1 ;; *) arms=p0 ;; esac
  s=$(date +%s)
  R_LIBS="$W/lib" CELLS=$c REPS=$REPS ARMS=$arms EPS=$EPS MC_B=$MC_B CORES=$CORES OUT="$f.tmp" \
    Rscript tests/sim/twolevel-few-clusters.R > "$W/logs/cell-$c-R$REPS.log" 2>&1 && mv "$f.tmp" "$f"
  echo "$c $? $(( $(date +%s) - s ))" >> "$W/logs/progress-R$REPS.txt"
done

for c in $CELLS; do [ -f "$W/rows/cell-$c-R$REPS.csv" ] || { echo "cell $c has no rows" >&2; exit 1; }; done
date > "$W/logs/done-R$REPS"
