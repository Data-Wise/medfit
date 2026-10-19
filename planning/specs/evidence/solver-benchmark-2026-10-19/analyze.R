## Analysis of the solver benchmark per DESIGN.md (precommitted 0fa69b1).
## Usage: Rscript analyze.R bench_A.csv bench_B.csv bench_C.csv > analysis.out
files <- commandArgs(TRUE)
d <- do.call(rbind, lapply(files, read.csv))
d$wrong <- !d$success & !d$unresolved
d$wrong_relaxed <- !d$success_relaxed & !d$unresolved_relaxed

wilson <- function(x, n, z = 1.96) {
  p <- x / n; c0 <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  h <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  sprintf("%.3f [%.3f, %.3f]", p, max(0, c0 - h), min(1, c0 + h))
}

cat("Per cell and method (strict acceptance per DESIGN; relaxed = DEVIATION 2)\n")
tab <- do.call(rbind, lapply(split(d, list(d$cell, d$method), drop = TRUE), function(z) {
  n <- nrow(z)
  data.frame(cell = z$cell[1], method = z$method[1], n = n,
             success = wilson(sum(z$success), n), wrong = sum(z$wrong), unresolved = sum(z$unresolved),
             success_relaxed = wilson(sum(z$success_relaxed), n), wrong_relaxed = sum(z$wrong_relaxed),
             below_oracle = sum(z$below_oracle), infeasible_returns = sum(z$infeasible_returns),
             sec_median = round(median(z$sec), 3), sec_p90 = round(quantile(z$sec, .9), 3))
}))
tab <- tab[order(tab$cell, tab$method), ]
print(tab, row.names = FALSE)

cat("\nDecision rule (cells 5-11): T1 zero accepted-wrong AND paired LB(success_T1 - success_AUG) >= -0.005\n")
dcells <- intersect(5:11, unique(d$cell)); if (!length(dcells)) quit(save = "no")
dec <- do.call(rbind, lapply(dcells, function(cc) {
  t <- d[d$cell == cc & d$method == "T", ]; a <- d[d$cell == cc & d$method == "AUG", ]
  m <- merge(t[, c("rep", "success", "wrong")], a[, c("rep", "success")], by = "rep", suffixes = c("_T", "_A"))
  N <- nrow(m); d10 <- sum(m$success_T & !m$success_A); d01 <- sum(!m$success_T & m$success_A)
  diff <- (d10 - d01) / N; se <- sqrt(d10 + d01 - (d10 - d01)^2 / N) / N; lb <- diff - 1.645 * se
  data.frame(cell = cc, N = N, T_wrong = sum(m$wrong), T_success = mean(m$success_T), AUG_success = mean(m$success_A),
             d10 = d10, d01 = d01, diff = round(diff, 4), lb = round(lb, 4),
             pass = sum(m$wrong) == 0 && lb >= -0.005)
}))
print(dec, row.names = FALSE)
cat("\nRule met in every decision cell:", all(dec$pass), "\n")
