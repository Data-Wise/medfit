#!/bin/sh
# Run an R script (default: the #213 nonlinear profile gate) from a copy of this checkout inside a Linux container
# with the reference BLAS/LAPACK. Needs Docker. Usage, from the package root:
#   tests/sim/linux/run.sh                                     # the nonlinear profile gate
#   tests/sim/linux/run.sh tests/sim/sem-se-gate.R             # another script, relative to the package root
#   tests/sim/linux/run.sh -e 'devtools::test()'               # an R expression (needs EXTRA_PKGS=devtools at build)
# BLAS=openblas tests/sim/linux/run.sh ...   # the GitHub runner's OpenBLAS instead of the reference BLAS
# Rebuild the image after changing the Dockerfile: IMAGE_REBUILD=1 tests/sim/linux/run.sh
set -eu
root=$(cd "$(dirname "$0")/../../.." && pwd)
blas=${BLAS:-reference}   # BLAS=openblas: the GitHub runner's BLAS
case "$blas" in
  reference) image=medfit-linux-refblas ;;
  openblas) image=medfit-linux-openblas ;;
  *) echo "BLAS must be reference or openblas" >&2; exit 2 ;;
esac
if [ -n "${IMAGE_REBUILD:-}" ] || ! docker image inspect "$image" >/dev/null 2>&1; then
  docker build --platform linux/amd64 --build-arg BLAS="$blas" -t "$image" -f "$root/tests/sim/linux/Dockerfile" "$root/tests/sim/linux"
fi
[ "$#" -gt 0 ] || set -- tests/sim/sem-nonlinear-profile-gate.R
exec docker run --rm --platform linux/amd64 -v "$root":/src:ro "$image" sh -c '
  cp -r /src /tmp/medfit && cd /tmp/medfit
  Rscript -e "si <- sessionInfo(); cat(\"R\", as.character(getRversion()), \"| BLAS\", si\$BLAS, \"| LAPACK\", si\$LAPACK, \"\\n\")"
  if [ "$1" = "-e" ]; then shift; Rscript -e "$@"; else Rscript "$@"; fi' sh "$@"
