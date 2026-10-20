## Analysis of addendum A1 per ADDENDUM-DESIGN.md. Usage: Rscript analyze_a1.R a1_P.csv a1_Q.csv a1_R.csv
d <- do.call(rbind, lapply(commandArgs(TRUE), read.csv))
wilson <- function(x, n, z = 1.96) {
  p <- x / n; c0 <- (p + z^2 / (2 * n)) / (1 + z^2 / n); h <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(p = p, lo = max(0, c0 - h), hi = min(1, c0 + h))
}
key <- unique(d$cell)
tab <- do.call(rbind, lapply(key, function(cc) do.call(rbind, lapply(c("T", "AUG"), function(m) {
  z <- d[d$cell == cc & d$method == m, ]; n <- nrow(z); w <- wilson(sum(z$success), n)
  data.frame(cell = cc, method = m, n = n, success = sprintf("%.3f [%.3f, %.3f]", w[1], w[2], w[3]),
             wrong = sum(z$wrong), unresolved = sum(z$unresolved), oracle_miss = sum(z$oracle_miss),
             success_relaxed = sprintf("%.3f", mean(z$success_relaxed)),
             max_inv_rel = if (m == "T" && any(!is.na(z$inv_rel))) signif(max(z$inv_rel, na.rm = TRUE), 3) else NA,
             lr_median = signif(median(z$ref), 3), sec_median = round(median(z$sec), 3), sec_p90 = round(quantile(z$sec, .9), 3))
}))))
print(tab, row.names = FALSE)

Tt <- d[d$method == "T", ]
c1 <- tapply(Tt$wrong, Tt$cell, sum)
gen <- grepl("^G", names(c1)); sr <- tapply(Tt$success, Tt$cell, mean)
inv <- Tt[grepl("^I", Tt$cell), ]
cat("\nPass criteria for T\n")
cat("1. zero accepted-wrong in every cell:", all(c1 == 0), "\n")
cat("2. success >= .995 in G1-G7:", all(sr[gen] >= .995), " (min", round(min(sr[gen]), 4), ")\n")
cat("3. invariance within 1e-6 relative in I1-I3:", all(inv$inv_rel <= 1e-6, na.rm = TRUE) && !any(is.na(inv$inv_rel)),
    " (max", signif(max(inv$inv_rel, na.rm = TRUE), 3), ")\n")
