## Analysis of addendum A2 (ADDENDUM-A2-DESIGN.md). Usage: Rscript analyze_a2.R a2_*.csv
d <- do.call(rbind, lapply(commandArgs(TRUE), read.csv))
meths <- c("T", "TW", "TW11", "TW21", "TWr", "NP", "PC", "TWs", "AUG8")
main <- d[!grepl("^I", d$cell), ]; inv <- d[grepl("^I", d$cell), ]
cat("Datasets (non-invariance cells):", length(unique(paste(main$cell, main$rep))), "\n\n")
cat("Accepted-wrong by method and cell (non-invariance cells)\n")
w <- xtabs(wrong ~ cell + method, main)[, meths]; print(w[rowSums(w) > 0, , drop = FALSE])
summ <- do.call(rbind, lapply(meths, function(m) {
  z <- main[main$method == m, ]; iz <- inv[inv$method == m & !is.na(inv$inv_rel), ]
  data.frame(method = m, n = nrow(z), success = round(mean(z$success), 5), wrong = sum(z$wrong), unresolved = sum(z$unresolved),
             inv_max = if (nrow(iz)) signif(max(iz$inv_rel), 3) else NA, inv_gt_1e6 = if (nrow(iz)) sum(iz$inv_rel > 1e-6) else NA,
             sec_median = if (all(is.na(z$sec))) NA else round(median(z$sec, na.rm = TRUE), 3))
}))
cat("\nSummary\n"); print(summ, row.names = FALSE)
summ$robust <- with(summ, wrong == 0 & unresolved == 0 & (is.na(inv_gt_1e6) | inv_gt_1e6 == 0))
cat("\nRobust (0 wrong, 0 unresolved, invariance within 1e-6 where tested):\n"); print(summ[, c("method", "robust")], row.names = FALSE)
cat("\nOracle misses (some method below the oracle):", sum(tapply(main$oracle_miss, paste(main$cell, main$rep), any)), "\n")
