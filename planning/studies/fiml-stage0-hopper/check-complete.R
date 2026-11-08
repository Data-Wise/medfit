# Completeness checker: every (cell, dataset, effect, method) of the 60 x 2500 x 3 x 2 ledger exactly once.
# Usage: Rscript check-complete.R <outdir> [ncells=60] [ndatasets=2500]
a <- commandArgs(TRUE); outdir <- a[1]; nc <- as.integer(ifelse(is.na(a[2]), 60, a[2])); nd <- as.integer(ifelse(is.na(a[3]), 2500, a[3]))
fs <- list.files(outdir, pattern = "^cell[0-9]+_.*\\.csv$", full.names = TRUE)
L <- do.call(rbind, lapply(fs, read.csv, stringsAsFactors = FALSE))
key <- with(L, paste(cell, dataset, effect, method))
exp <- expand.grid(cell = seq_len(nc), dataset = seq_len(nd), effect = c("nie", "nde", "te"), method = c("nonparametric", "parametric"), stringsAsFactors = FALSE)
ek <- with(exp, paste(cell, dataset, effect, method))
missing <- setdiff(ek, key); dup <- key[duplicated(key)]; extra <- setdiff(key, ek)
cat(sprintf("files %d, rows %d, expected %d\nmissing %d, duplicated %d, unexpected %d\n", length(fs), nrow(L), nrow(exp), length(missing), length(dup), length(extra)))
cat("provenance: commits", paste(unique(L$medfit_commit), collapse = ","), "| fingerprints", paste(unique(L$fingerprint_sha256), collapse = ","), "\n")
print(table(L$method, L$status, useNA = "ifany"))
cap_hits <- sum(grepl("collection cap reached", L$reason), na.rm = TRUE)
cat("collection-cap hits (each is a generator DEFECT, not a statistical outcome):", cap_hits, "\n")
ok <- cap_hits == 0L && length(missing) + length(dup) + length(extra) == 0L && length(unique(L$medfit_commit)) == 1L && length(unique(L$fingerprint_sha256)) == 1L
cat(if (ok) "COMPLETE\n" else "INCOMPLETE OR INCONSISTENT\n"); quit(status = if (ok) 0L else 1L)
