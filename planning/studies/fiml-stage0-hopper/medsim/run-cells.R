# Run cells through the medsim adapter and write the long layout as one CSV per cell (same name pattern as run-chunk.R,
# so check-complete.R can read them). LOCAL ONLY. Usage (repo root, environment as in adapter.R):
#   Rscript planning/studies/fiml-stage0-hopper/medsim/run-cells.R <outdir> <datasets> <chunks> <cell> [<cell> ...]
a <- commandArgs(TRUE); outdir <- a[1]; nd <- as.integer(a[2]); nch <- as.integer(a[3]); cells <- as.integer(a[-(1:3)])
source("planning/studies/fiml-stage0-hopper/medsim/adapter.R")
# Test hook for planted-defect controls only: STAGE0_PRELUDE names a script run after setup (e.g. to change a function).
if (nzchar(pre <- Sys.getenv("STAGE0_PRELUDE"))) { stage0_adapter_setup(); source(pre) }
for (cc in cells) {
  for (k in seq_len(nch)) stage0_adapter_run_task(cc, k, nch, nd, file.path(outdir, "chunks"))
  cmb <- stage0_adapter_combine(file.path(outdir, "chunks"), cc, nd, nch, on_violation = "warn")
  L <- stage0_medsim_long(cmb$results)
  dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
  utils::write.table(L, file.path(outdir, sprintf("cell%03d_%05d-%05d.csv", cc, 1L, nd)), sep = ",", row.names = FALSE,
                     qmethod = "double")
}
cat("done", length(cells), "cells\n")
