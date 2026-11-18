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
#   REP_START first replicate [501]: replicates REP_START to REP_START + REPS - 1, so the T6 default 501 to 1500 never
#          reuses the T5 pilot's 1 to 500 (plan section 12); the last replicate must stay below 1e5
#   MC_B   MC draws per dataset [2000]
#   EPS    P1 floor [1e-3]
#   CELLS  space-separated cell ids [all 120, 1001 to 1120]
#
# Layout under W: lib/ (medfit installed from HEAD, SHA in install-sha.txt), snap/ (driver, libs and P1 list from
# HEAD, hashes in snap-sha256.txt), manifest-R<REPS>.txt (written at the first launch: sha, rep_start, mc_b, eps and
# the medfit and lavaan versions; a resume with other values refuses), rows/cell-<id>-R<REPS>.csv,
# logs/cell-<id>-R<REPS>.log, logs/progress-R<REPS>.txt (a "# launch" line per launch, then "cell exit seconds" per
# cell), logs/done-R<REPS> once every requested cell has its CSV.
# Refresh the install by deleting W/lib: any missing piece of lib, snap or install-sha.txt clears all of them and
# reinstalls HEAD; rows of another SHA then make the runner refuse until they and their manifest are moved aside.
# Aggregate afterwards with tests/sim/twolevel-few-clusters-t6-aggregate.R.
set -u
REPO=$(cd "$(dirname "$0")/../.." && pwd)
W=${W:-$REPO/_agents_workspace/fc-t6}
CORES=${CORES:-10}
REPS=${REPS:-1000}
REP_START=${REP_START:-501}
MC_B=${MC_B:-2000}
EPS=${EPS:-1e-3}
CELLS=${CELLS:-$(seq 1001 1120)}
SHA=$(git -C "$REPO" rev-parse HEAD)
case "$REPS$REP_START" in *[!0-9]*) echo "REPS and REP_START must be positive integers" >&2; exit 1 ;; esac
[ "$REPS" -ge 1 ] && [ "$REP_START" -ge 1 ] || { echo "REPS and REP_START must be at least 1" >&2; exit 1; }
[ $(( REP_START + REPS - 1 )) -lt 100000 ] || {
  echo "REP_START + REPS - 1 must stay below 1e5 (seed cell_id * 1e5 + rep)" >&2; exit 1; }
mkdir -p "$W/rows" "$W/logs"
MAN=$W/manifest-R$REPS.txt
man_get() { grep "^$1=" "$MAN" | head -n 1 | cut -d= -f2-; }

# medfit at HEAD into a scratch library and the study scripts from HEAD into snap/, once per work directory: a
# resumed run keeps the install and snapshot it started with. Any missing piece is a refresh, which clears every
# piece of install state together, so a stale install-sha.txt can never skip the install.
if [ ! -f "$W/install-sha.txt" ] || [ ! -f "$W/lib/medfit/DESCRIPTION" ] || [ ! -f "$W/snap/sha.txt" ]; then
  if [ -f "$MAN" ] && [ "$(man_get sha)" != "$SHA" ]; then
    echo "a refresh would install HEAD $SHA, but $MAN and its rows come from $(man_get sha);" \
      "move $MAN and $W/rows/cell-*-R$REPS.csv aside first" >&2; exit 1
  fi
  rm -rf "${W:?}/src" "${W:?}/lib" "${W:?}/snap" "$W/install-sha.txt" "$W/snap-sha256.txt"
  mkdir -p "$W/src" "$W/lib" "$W/snap/tests/sim" "$W/snap/planning/studies/few-clusters"
  git -C "$REPO" archive HEAD | tar -x -C "$W/src"
  R CMD INSTALL -l "$W/lib" "$W/src" > "$W/logs/install.log" 2>&1 || {
    echo "install failed, see $W/logs/install.log" >&2; exit 1; }
  for f in tests/sim/twolevel-few-clusters.R tests/sim/twolevel-few-clusters-lib.R \
           tests/sim/twolevel-few-clusters-t6-lib.R planning/studies/few-clusters/T6-p1-cells.csv; do
    git -C "$REPO" show "HEAD:$f" > "$W/snap/$f" || { echo "cannot snapshot $f at HEAD" >&2; exit 1; }
  done
  (cd "$W/snap" && shasum -a 256 tests/sim/*.R planning/studies/few-clusters/*.csv) > "$W/snap-sha256.txt"
  echo "$SHA" > "$W/snap/sha.txt"
  echo "$SHA" > "$W/install-sha.txt"
fi
[ "$(cat "$W/install-sha.txt")" = "$(cat "$W/snap/sha.txt")" ] || {
  echo "W/lib and W/snap come from different commits; delete $W/lib to refresh (the runner then clears" \
    "W/src, W/snap, W/install-sha.txt and W/snap-sha256.txt and reinstalls HEAD)" >&2; exit 1; }
RUN_SHA=$(cat "$W/install-sha.txt")
[ "$RUN_SHA" = "$SHA" ] || echo "note: running the install and snapshot of $RUN_SHA, not HEAD $SHA" >&2

# The medfit R loads must be the one in W/lib (not a user-library fallback) at the version of DESCRIPTION at RUN_SHA
WANT_MEDFIT=$(git -C "$REPO" show "$RUN_SHA:DESCRIPTION" | grep '^Version:' | awk '{print $2}')
VERS=$(R_LIBS="$W/lib" Rscript -e 'cat(normalizePath(find.package("medfit")), format(packageVersion("medfit")),
  format(packageVersion("lavaan")))') || { echo "cannot load medfit and lavaan from $W/lib" >&2; exit 1; }
read -r MEDFIT_PATH MEDFIT_V LAVAAN_V <<< "$VERS"
[ "$MEDFIT_PATH" = "$(cd "$W/lib/medfit" && pwd -P)" ] && [ "$MEDFIT_V" = "$WANT_MEDFIT" ] || {
  echo "R loads medfit $MEDFIT_V from $MEDFIT_PATH, not $WANT_MEDFIT from $W/lib/medfit; delete $W/lib to refresh" >&2
  exit 1; }
R_LIBS="$W/lib" Rscript -e 'library(medfit); library(lavaan); print(sessionInfo())' > "$W/logs/sessionInfo.txt" 2>&1 ||
  { echo "sessionInfo failed, see $W/logs/sessionInfo.txt" >&2; exit 1; }

# The launch manifest: written once; a resume must match it, so a work directory holds one replicate range, one
# install and one lavaan per R
if [ ! -f "$MAN" ]; then
  if ls "$W/rows/cell-"*"-R$REPS.csv" > /dev/null 2>&1; then
    echo "rows for R = $REPS exist in $W/rows but $MAN does not; move them aside" >&2; exit 1
  fi
  printf 'sha=%s\nrep_start=%s\nmc_b=%s\neps=%s\nmedfit_version=%s\nlavaan_version=%s\n' \
    "$RUN_SHA" "$REP_START" "$MC_B" "$EPS" "$MEDFIT_V" "$LAVAAN_V" > "$MAN"
fi
for kv in "sha=$RUN_SHA" "rep_start=$REP_START" "mc_b=$MC_B" "eps=$EPS" "medfit_version=$MEDFIT_V" \
          "lavaan_version=$LAVAAN_V"; do
  k=${kv%%=*}
  [ "$(man_get "$k")" = "${kv#*=}" ] || {
    echo "$MAN records $k=$(man_get "$k"), this launch has ${kv#*=}; resume with the recorded value" >&2; exit 1; }
done
echo "# launch $(date -u +%Y-%m-%dT%H:%M:%SZ) sha=$RUN_SHA rep_start=$REP_START reps=$REPS mc_b=$MC_B eps=$EPS" \
  >> "$W/logs/progress-R$REPS.txt"

P1=$(tail -n +2 "$W/snap/planning/studies/few-clusters/T6-p1-cells.csv" | cut -d, -f1 | tr '\n' ' ')
cd "$W/snap" || exit 1
for c in $CELLS; do
  f=$W/rows/cell-$c-R$REPS.csv
  [ -f "$f" ] && continue
  case " $P1 " in *" $c "*) arms=p0,p1 ;; *) arms=p0 ;; esac
  s=$(date +%s)
  R_LIBS="$W/lib" CELLS=$c REPS=$REPS REP_START=$REP_START ARMS=$arms EPS=$EPS MC_B=$MC_B CORES=$CORES OUT="$f.tmp" \
    Rscript tests/sim/twolevel-few-clusters.R > "$W/logs/cell-$c-R$REPS.log" 2>&1 && mv "$f.tmp" "$f"
  echo "$c $? $(( $(date +%s) - s ))" >> "$W/logs/progress-R$REPS.txt"
done

for c in $CELLS; do [ -f "$W/rows/cell-$c-R$REPS.csv" ] || { echo "cell $c has no rows" >&2; exit 1; }; done
date > "$W/logs/done-R$REPS"
