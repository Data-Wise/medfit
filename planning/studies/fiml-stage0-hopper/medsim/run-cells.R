# Run cells through the medsim adapter and write the long layout as one CSV per cell (same name pattern as run-chunk.R,
# so check-complete.R can read them) plus the wide frame as wide-cellNNN.rds. The medsim combine stops on any violation and
# the stage-0 gate (ledger, receipts, truth) must pass; exit status is nonzero otherwise. LOCAL ONLY.
# Usage (repo root, environment as in adapter.R):
#   Rscript planning/studies/fiml-stage0-hopper/medsim/run-cells.R <outdir> <datasets> <chunks> <cell> [<cell> ...]
# STAGE0_GATE=off skips only the final gate (for parity runs that deliberately contain failure rows).
a <- commandArgs(TRUE); outdir <- a[1]; nd <- as.integer(a[2]); nch <- as.integer(a[3]); cells <- as.integer(a[-(1:3)])
source("planning/studies/fiml-stage0-hopper/medsim/analysis.R")
# Test hook for planted-defect controls only: STAGE0_PRELUDE names a script run after setup (e.g. to change a function).
if (nzchar(pre <- Sys.getenv("STAGE0_PRELUDE"))) { stage0_adapter_setup(); source(pre) }
stage0_run_cells(outdir, nd, nch, cells, gate = !identical(Sys.getenv("STAGE0_GATE"), "off"))
cat("done", length(cells), "cells\n")
