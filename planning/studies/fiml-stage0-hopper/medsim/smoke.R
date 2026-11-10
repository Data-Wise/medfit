# Smoke-size study through medsim: a few cells x few datasets x B = 40, LOCAL ONLY (no Hopper, no sbatch).
# Usage (repo root, environment as in adapter.R): Rscript planning/studies/fiml-stage0-hopper/medsim/smoke.R <outdir> [datasets=3] [chunks=3]
a <- commandArgs(TRUE); outdir <- a[1]; nd <- as.integer(if (is.na(a[2])) 3L else a[2]); nch <- as.integer(if (is.na(a[3])) 3L else a[3])
source("planning/studies/fiml-stage0-hopper/medsim/analysis.R")
g <- stage0_cells(); pick <- function(n, regime, miss, direct) g$cell[g$n == n & g$regime == regime & g$miss == miss & g$direct == direct]
cells <- c(pick(200L, "nonzero", "mcar", TRUE), pick(500L, "a_null", "mar", FALSE), pick(200L, "b_null", "empty", TRUE), pick(200L, "local", "empty", FALSE))
stopifnot(!dir.exists(outdir) || length(list.files(outdir)) == 0L)
for (cc in cells) for (k in seq_len(nch)) stage0_adapter_run_task(cc, k, nch, nd, outdir)
cmb <- stage0_adapter_combine(outdir, cells, nd, nch)          # medsim: per-cell chunk audit, then the cross-cell audit
W <- cmb$results; L <- stage0_medsim_long(W)
cat("medsim violations:", length(cmb$violations), "\n")
rc <- stage0_receipts(W); cat("receipts ok:", rc$ok, rc$problems, "\n")
ig <- stage0_integrity(L, cells, nd); print(ig$counts); cat("ledger ok:", ig$ok, ig$problems, "\n")
cov <- stage0_coverage(L, cells, nd)
print(cov[, c("cell", "effect", "method", "attempted", "returned", "covered", "availability", "cond_coverage")], digits = 3)
cat("effective K (successful refits, nonparametric): ", paste(sort(unique(unlist(W[grep("_np_successful$", names(W))]))), collapse = ","), "\n")
cat("receipt:", unlist(unique(W[c("rcp_medsim_version", "rcp_medsim_commit", "rcp_medfit_commit", "rcp_r_version", "rcp_blas")])[1, ]), sep = "\n  ")
saveRDS(list(W = W, L = L, cov = cov), file.path(outdir, "smoke-results.rds"))
