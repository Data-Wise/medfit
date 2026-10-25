# Type I error gate for the min-of-k MBCO test (plan T18, G13).
#
# `mbco_sem(fit, paths = c("a", "d", "b"))` refers the smallest of k single-path LRTs to chi-square(1). The null
# is a union (some path is zero), so the size should sit at or below alpha whichever paths are zero. Serial model
# X -> M1 -> M2 -> Y with a direct path from X to each later variable. Cells: every pattern of zero paths (one,
# two and three zero paths, nonzero paths 0.4) x n in {50, 200, 1000}, REPS replications each; plus one
# alternative (all paths ALT_EFFECT, ALT_N) for the power floor.
#
# Rules (nonzero exit when any fails):
#   size:   rejection rate at alpha = 0.05 is at most alpha + 3 MC standard errors in every null cell
#   power:  at the alternative, power is at least POWER_FLOOR
#   oracle: every p-value equals pchisq(statistic, 1, lower.tail = FALSE)
#   mutant: referring the same statistics to chi-square(2) fails the oracle and the power floor
#   runs:   fewer than 1% of fits fail
# Run from the package root:  Rscript tests/sim/sem-mbco-k-size.R   (REPS=2000 by default; REPS=40 for a smoke run)
# Results: tests/sim/results/sem-mbco-k-size-<date>.csv

suppressMessages(pkgload::load_all(quiet = TRUE))

reps <- as.integer(Sys.getenv("REPS", "2000"))
alpha <- 0.05
nonzero <- 0.4
alt_effect <- as.numeric(Sys.getenv("ALT_EFFECT", "0.25"))
alt_n <- 200L
power_floor <- 0.75
syntax <- "M1 ~ a*X\nM2 ~ d*M1 + X\nY ~ b*M2 + X"
paths <- c("a", "d", "b")

patterns <- list(
  zero_a = c(a = 0, d = nonzero, b = nonzero), zero_d = c(a = nonzero, d = 0, b = nonzero),
  zero_b = c(a = nonzero, d = nonzero, b = 0), zero_ad = c(a = 0, d = 0, b = nonzero),
  zero_ab = c(a = 0, d = nonzero, b = 0), zero_db = c(a = nonzero, d = 0, b = 0),
  zero_adb = c(a = 0, d = 0, b = 0)
)
patterns$alt <- stats::setNames(rep(alt_effect, 3), paths)
cells <- rbind(
  expand.grid(cell = setdiff(names(patterns), "alt"), n = c(50L, 200L, 1000L), stringsAsFactors = FALSE),
  data.frame(cell = "alt", n = alt_n)
)

simulate <- function(eff, n) {
  x <- stats::rnorm(n)
  m1 <- eff[["a"]] * x + stats::rnorm(n)
  m2 <- eff[["d"]] * m1 + 0.2 * x + stats::rnorm(n)
  y <- eff[["b"]] * m2 + 0.2 * x + stats::rnorm(n)
  data.frame(X = x, M1 = m1, M2 = m2, Y = y)
}

one <- function(i) {
  cl <- cells[(i - 1L) %% nrow(cells) + 1L, ]
  rep <- (i - 1L) %/% nrow(cells) + 1L
  set.seed(1e5L * rep + 10L * cl$n + match(cl$cell, names(patterns)))
  d <- simulate(patterns[[cl$cell]], cl$n)
  out <- tryCatch({
    fit <- suppressWarnings(fit_sem(syntax, d, fixed_x = FALSE, meanstructure = NULL))
    r <- suppressWarnings(mbco_sem(fit, paths = paths))
    c(stat = unname(r$statistic), p = r$p.value)
  }, error = function(e) c(stat = NA_real_, p = NA_real_))
  data.frame(cell = cl$cell, n = cl$n, rep = rep, stat = out[["stat"]], p = out[["p"]])
}

cores <- max(1L, parallel::detectCores() - 1L)
runs <- do.call(rbind, parallel::mclapply(seq_len(reps * nrow(cells)), one, mc.cores = cores))

summ <- do.call(rbind, lapply(split(runs, list(runs$cell, runs$n), drop = TRUE), function(g) {
  ok <- !is.na(g$p)
  data.frame(
    cell = g$cell[1], n = g$n[1], reps = nrow(g), fails = sum(!ok),
    reject = mean(g$p[ok] < alpha),
    reject_df2 = mean(stats::pchisq(g$stat[ok], 2, lower.tail = FALSE) < alpha),
    mc_se = sqrt(alpha * (1 - alpha) / sum(ok)),
    oracle_gap = max(abs(g$p[ok] - stats::pchisq(g$stat[ok], 1, lower.tail = FALSE))),
    oracle_gap_df2 = max(abs(g$p[ok] - stats::pchisq(g$stat[ok], 2, lower.tail = FALSE)))
  )
}))
rownames(summ) <- NULL
summ$kind <- ifelse(summ$cell == "alt", "power", "size")
summ$limit <- ifelse(summ$kind == "size", alpha + 3 * summ$mc_se, power_floor)
summ$pass <- ifelse(summ$kind == "size", summ$reject <= summ$limit, summ$reject >= summ$limit)

dir.create("tests/sim/results", showWarnings = FALSE)
utils::write.csv(summ, file.path("tests/sim/results", sprintf("sem-mbco-k-size-%s.csv", Sys.Date())), row.names = FALSE)
print(summ, digits = 3)

alt <- summ[summ$kind == "power", ]
checks <- c(
  size = all(summ$pass[summ$kind == "size"]),
  power_floor = alt$pass,
  oracle = all(summ$oracle_gap < 1e-12),
  mutant_fails_oracle = all(summ$oracle_gap_df2 > 1e-3),
  mutant_fails_power = alt$reject_df2 < power_floor,
  fit_failures = sum(summ$fails) / sum(summ$reps) < 0.01
)
cat("\n")
for (nm in names(checks)) cat(sprintf("%-22s %s\n", nm, if (checks[[nm]]) "PASS" else "FAIL"))
if (!all(checks)) {
  cat("\nRULE NOT MET: withhold the k >= 3 path of mbco_sem() from the release.\n")
  quit(status = 1)
}
cat("\nRULE MET\n")
