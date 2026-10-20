## Analysis of the A1 warm-start rerun (bench_edge_tw.R). Usage: Rscript analyze_tw.R tw_*.csv
d <- do.call(rbind, lapply(commandArgs(TRUE), read.csv))
lev <- unique(d$cell)
tab <- do.call(rbind, lapply(lev, function(cc) do.call(rbind, lapply(c("T", "TW"), function(m) {
  z <- d[d$cell == cc & d$method == m, ]
  data.frame(cell = cc, method = m, n = nrow(z), success = round(mean(z$success), 4), wrong = sum(z$wrong),
             unresolved = sum(z$unresolved), oracle_miss = sum(z$oracle_miss),
             max_inv_rel = if (any(!is.na(z$inv_rel))) signif(max(z$inv_rel, na.rm = TRUE), 3) else NA,
             sec_median = round(median(z$sec), 3), sec_p90 = round(quantile(z$sec, .9), 3))
}))))
print(tab, row.names = FALSE)
for (m in c("T", "TW")) {
  z <- d[d$method == m, ]; g <- z[grepl("^G", z$cell), ]; i <- z[grepl("^I", z$cell), ]
  cat("\n", m, ": wrong total", sum(z$wrong), "| unresolved", sum(z$unresolved),
      "| min G success", round(min(tapply(g$success, g$cell, mean)), 4),
      "| invariance max", signif(max(i$inv_rel, na.rm = TRUE), 3), "(n > 1e-6:", sum(i$inv_rel > 1e-6, na.rm = TRUE), ")\n")
  cat("   criteria (1) zero wrong:", sum(z$wrong) == 0, " (2) G >= .995:", all(tapply(g$success, g$cell, mean) >= .995),
      " (3) invariance:", all(i$inv_rel <= 1e-6) && !anyNA(i$inv_rel), "\n")
}
