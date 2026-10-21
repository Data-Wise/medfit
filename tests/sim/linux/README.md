# Linux reference-BLAS container for the simulation gates

`run.sh` builds `Dockerfile` once (R release on Ubuntu with the reference BLAS/LAPACK, like the GitHub
`ubuntu-latest` runner) and runs an R script from a read-only copy of this checkout.

```sh
tests/sim/linux/run.sh                          # the #213 nonlinear profile gate (about 2 min)
tests/sim/linux/run.sh tests/sim/sem-se-gate.R  # any other script, path relative to the package root
```

It prints the R, BLAS and LAPACK versions first, so a drift from the runner is visible. Gate results can depend on the
BLAS (issue #238); a result that holds on macOS and here is the one CI will see. Needs Docker; not part of the package
(`tests/sim` is Rbuildignored).
