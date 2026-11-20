# Type I error of the two-level equal-indirect-effects test (IG3 T-B reliability cell, planning/specs/SCOPE-IG3-*.md
# section 8). `twolevel_equal_indirect(fit)` refers the likelihood ratio of the free two-level fit against the fit with
# `a_w*b_w == a_b*b_b` (the nonlinear gate, SLSQP rows, Lagrangian Hessian, polish) to chi-square(1). Away from the
# all-zero point the null is a smooth surface and chi-square(1) is asymptotic in the number of clusters J; at the origin
# it is singular. Model: two-level (1-1-1, observed) X -> M -> Y with a direct path at both levels, clusters of size N_J.
# Cells: J in {20, 50} x null pattern {equal, origin}. `equal`: within paths (0.4, 0.5) and between paths (0.5, 0.4), so
# both indirect effects are 0.2 and differ in their factors; `origin`: every mediation path 0 (the singular point).
# REPS replications per cell.
#
# Rules (nonzero exit when any fails):
#   size:   rejection rate at alpha = 0.05 is at most alpha + 3 MC standard errors in every cell; the rate is
#           conditional on the resolved tests (fails = fit-stage inadmissible + null-stage unresolved + ledger error
#           + other, each counted in its own column)
#   oracle: every p-value equals pchisq(statistic, 1, lower.tail = FALSE)
#   aborts: no test ends in a ledger error or an unclassified error (an inadmissible, non-PD or non-converged null
#           refit is unresolved with a warning, never an abort and never a number)
#   runs:   at most MAX_FAIL of the tests are unresolved or error (counted, not hidden)
# MUTANT=cross_pair (the wrong pairing a_w*b_b == a_b*b_w) alters twolevel_equal_indirect() in memory and must fail the
# size rule in the equal cells, where the true surface is a_w*b_w == a_b*b_b. MUTANT=df_two (chi-square(2) p-value)
# must fail the oracle rule.
# Run from the package root:  Rscript tests/sim/sem-twolevel-equal-size.R   (REPS=500 by default; REPS=20 smoke)
# Results: tests/sim/results/sem-twolevel-equal-size-<date>.csv (MUTANT runs write ...-<mutant>-<date>.csv)

suppressMessages(pkgload::load_all(quiet = TRUE))

reps <- as.integer(Sys.getenv("REPS", "500"))
n_j <- as.integer(Sys.getenv("N_J", "10"))
max_fail <- as.numeric(Sys.getenv("MAX_FAIL", "0.02"))
mutant <- Sys.getenv("MUTANT", "")
alpha <- 0.05

ns <- asNamespace("medfit")
mutate <- function(pattern, replacement) {
  src <- paste(deparse(get("twolevel_equal_indirect", ns), width.cutoff = 500L), collapse = "\n")
  stopifnot(lengths(regmatches(src, gregexpr(pattern, src, fixed = TRUE))) == 1L)
  # eval(parse()) on this package's own deparsed function with a literal swap, as sem_mutate() in helper-sem.R
  fn <- eval(parse(text = sub(pattern, replacement, src, fixed = TRUE)))
  environment(fn) <- ns
  for (env in list(ns, as.environment("package:medfit"))) {
    if (bindingIsLocked("twolevel_equal_indirect", env)) unlockBinding("twolevel_equal_indirect", env)
    assign("twolevel_equal_indirect", fn, envir = env)
  }
}
if (mutant == "cross_pair") {
  mutate("sprintf(\"%s*%s == %s*%s\", a_within, b_within, a_between, b_between)",
         "sprintf(\"%s*%s == %s*%s\", a_within, b_between, a_between, b_within)")
} else if (mutant == "df_two") {
  mutate("stats::pchisq(stat, df = 1, lower.tail = FALSE)", "stats::pchisq(stat, df = 2, lower.tail = FALSE)")
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

model <- "
level: 1
  M ~ a_w*X
  Y ~ b_w*M + cp_w*X
level: 2
  M ~ a_b*X
  Y ~ b_b*M + cp_b*X
"
patterns <- list(equal = list(w = c(0.4, 0.5), b = c(0.5, 0.4)), origin = list(w = c(0, 0), b = c(0, 0)))
cells <- expand.grid(pattern = names(patterns), J = c(20L, 50L), stringsAsFactors = FALSE)

# one level's covariance from its paths, order X, M, Y
lev_sigma <- function(a, b, cp, v) {
  bm <- matrix(0, 3, 3)
  bm[2, 1] <- a
  bm[3, 2] <- b
  bm[3, 1] <- cp
  inv <- solve(diag(3) - bm)
  inv %*% diag(v) %*% t(inv)
}

simulate <- function(pat, n_cl) {
  p <- patterns[[pat]]
  sw <- lev_sigma(p$w[1], p$w[2], 0.2, c(1, 0.8, 0.9))
  sb <- lev_sigma(p$b[1], p$b[2], 0.1, c(0.5, 0.4, 0.4))
  cl <- rep(seq_len(n_cl), each = n_j)
  u <- matrix(stats::rnorm(n_cl * 3), ncol = 3) %*% chol(sb)
  e <- matrix(stats::rnorm(length(cl) * 3), ncol = 3) %*% chol(sw)
  z <- u[cl, , drop = FALSE] + e
  data.frame(cluster = cl, X = z[, 1] + 1, M = z[, 2] - 0.5, Y = z[, 3] + 2)
}

one <- function(i) {
  cl <- cells[(i - 1L) %% nrow(cells) + 1L, ]
  rep <- (i - 1L) %/% nrow(cells) + 1L
  set.seed(1e5L * rep + 100L * cl$J + match(cl$pattern, names(patterns)))
  d <- simulate(cl$pattern, cl$J)
  fit <- tryCatch(suppressWarnings(fit_sem(model, d, cluster = "cluster", fixed_x = FALSE, meanstructure = TRUE)),
                  error = function(e) e)
  res <- if (inherits(fit, "error")) {
    c(stat = NA, p = NA, err = paste("fit:", class(fit)[1], conditionMessage(fit)))
  } else {
    tryCatch({
      r <- suppressWarnings(suppressMessages(twolevel_equal_indirect(fit)))
      c(stat = unname(r$statistic), p = unname(r$p.value), err = if (isTRUE(r$unresolved)) "unresolved" else "")
    }, error = function(e) c(stat = NA, p = NA, err = paste(class(e)[1], conditionMessage(e))))
  }
  data.frame(pattern = cl$pattern, J = cl$J, rep = rep, stat = as.numeric(res[["stat"]]), p = as.numeric(res[["p"]]),
             err = substr(gsub("\\s+", " ", res[["err"]]), 1, 160))
}

t0 <- Sys.time()
cores <- max(1L, parallel::detectCores() - 1L)
runs <- do.call(rbind, parallel::mclapply(seq_len(reps * nrow(cells)), one, mc.cores = cores))
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

summ <- do.call(rbind, lapply(split(runs, list(runs$pattern, runs$J), drop = TRUE), function(g) {
  ok <- !is.na(g$p)
  data.frame(
    pattern = g$pattern[1], J = g$J[1], n_j = n_j, reps = nrow(g), fails = sum(!ok),
    reject = mean(g$p[ok] < alpha), mc_se = sqrt(alpha * (1 - alpha) / sum(ok)),
    fit_inadm = sum(startsWith(g$err, "fit: medfit_error_twolevel_inadmissible")),
    unresolved = sum(g$err == "unresolved"), ledger = sum(startsWith(g$err, "medfit_error_ledger")),
    reject_all = sum(g$p[ok] < alpha) / nrow(g), reject_10 = mean(g$p[ok] < 0.10), mean_stat = mean(g$stat[ok]),
    oracle_gap = max(abs(g$p[ok] - stats::pchisq(g$stat[ok], 1, lower.tail = FALSE)))
  )
}))
rownames(summ) <- NULL
summ <- summ[order(summ$J, summ$pattern), ]
summ$other <- summ$fails - summ$fit_inadm - summ$unresolved - summ$ledger
summ$limit <- alpha + 3 * summ$mc_se
summ$pass <- summ$reject <= summ$limit
summ$mutant <- mutant

dir.create("tests/sim/results", showWarnings = FALSE)
tag <- if (nzchar(mutant)) paste0(mutant, "-") else ""
utils::write.csv(summ, file.path("tests/sim/results", sprintf("sem-twolevel-equal-size-%s%s.csv", tag, Sys.Date())),
                 row.names = FALSE)
print(summ, digits = 3, row.names = FALSE)
errs <- runs$err[nzchar(runs$err)]
if (length(errs)) {
  cat("\nfailed or unresolved tests by reason:\n")
  print(utils::head(sort(table(substr(errs, 1, 60)), decreasing = TRUE), 10))
}
cat(sprintf("\nreps per cell %d, cluster size %d, %.1f minutes on %d cores\n", reps, n_j, elapsed, cores))

checks <- c(
  size = all(summ$pass),
  oracle = all(summ$oracle_gap < 1e-12),
  aborts = sum(summ$ledger + summ$other) == 0,
  fit_failures = sum(summ$fails) / sum(summ$reps) <= max_fail
)
cat("\n")
for (nm in names(checks)) cat(sprintf("%-14s %s\n", nm, if (checks[[nm]]) "PASS" else "FAIL"))
if (!all(checks)) {
  cat("\nRULE NOT MET\n")
  quit(status = 1)
}
cat("\nRULE MET\n")
