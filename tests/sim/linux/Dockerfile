# Linux with the reference BLAS/LAPACK, like the GitHub `ubuntu-latest` runner, for running the simulation gates
# locally (issue #238 showed gate results depend on the BLAS). The package is not baked in: run.sh mounts the
# checkout read-only and works on a copy. Build and run through tests/sim/linux/run.sh.
FROM --platform=linux/amd64 rocker/r-ver:latest

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      cmake libnlopt-dev libuv1-dev libcurl4-openssl-dev libssl-dev libxml2-dev libblas3 liblapack3 \
 && rm -rf /var/lib/apt/lists/* \
 && update-alternatives --set libblas.so.3-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/blas/libblas.so.3 \
 && update-alternatives --set liblapack.so.3-x86_64-linux-gnu /usr/lib/x86_64-linux-gnu/lapack/liblapack.so.3

# Imports of medfit plus what the gate scripts load (lavaan and OpenMx: the parity and compare-lr gates); add more with: docker build --build-arg EXTRA_PKGS="a b" ...
ARG EXTRA_PKGS=""
RUN Rscript -e 'pkgs <- c("S7", "checkmate", "generics", "lifecycle", "MASS", "nloptr", "rlang", "pkgload", "testthat", "lavaan", "OpenMx", \
                          strsplit(Sys.getenv("EXTRA_PKGS"), " ")[[1]]); \
                install.packages(pkgs[nzchar(pkgs)], Ncpus = 4); \
                stopifnot(all(c("S7", "nloptr", "pkgload") %in% rownames(installed.packages())))'

WORKDIR /w
