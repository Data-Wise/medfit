# Type I error of the two-level MBCO product test (IG3 T-A reliability cell, planning/specs/SCOPE-IG3-*.md section 8).
#
# `mbco_sem(fit, "a_w", "b_w")` (within) and `mbco_sem(fit, "a_b", "b_b")` (between) on a native two-level fit
# (`fit_sem(cluster = )`) refer the smaller of two linear branch LRs (a path set to 0) to chi-square(1). The null is a
# union (a = 0 or b = 0), so the size should sit at or below alpha; at the origin (a = b = 0) the chi-square(1)
# reference is conservative. The between level rests on J clusters, so its asymptotics are in J.
# Model: two-level (1-1-1, observed) X -> M -> Y with a direct path at both levels, balanced clusters of size N_J.
# Cells: J in {20, 50} x null pattern {zero_a, zero_b, origin}; each dataset carries the same pattern at both levels
# (nonzero paths: within 0.4, between 0.5), and both levels are tested on it. REPS replications per cell.
#
# Rules (nonzero exit when any fails):
#   size:   rejection rate at alpha = 0.05 is at most alpha + 3 MC standard errors in every (cell, level); the rate is
#           conditional on the resolved tests (fails = fit-stage inadmissible + null-stage inadmissible + ledger error
#           + unresolved + other, each counted in its own column)
#   oracle: every p-value equals pchisq(statistic, 1, lower.tail = FALSE)
#           reject_all is the rate over every replication (a test that is not resolved counts as no rejection)
#   aborts: no test ends in a ledger error or an unclassified error (a failed null refit is unresolved or a classed
#           inadmissible error, never an abort)
#   runs:   at most MAX_FAIL of the tests are unresolved or error (inadmissible refits are counted, not hidden)
# MUTANT=max_branch (the larger branch LR in place of the smaller) alters mbco_sem() in memory and must fail the
# size rule in the zero_a and zero_b cells, where one branch is false.
# Run from the package root:  Rscript tests/sim/sem-twolevel-mbco-size.R   (REPS=500 by default; REPS=20 smoke)
# Results: tests/sim/results/sem-twolevel-mbco-size-<date>.csv (MUTANT runs write ...-<mutant>-<date>.csv)

suppressMessages(pkgload::load_all(quiet = TRUE))

reps <- as.integer(Sys.getenv("REPS", "500"))
n_j <- as.integer(Sys.getenv("N_J", "10"))
max_fail <- as.numeric(Sys.getenv("MAX_FAIL", "0.02"))
mutant <- Sys.getenv("MUTANT", "")
alpha <- 0.05
nz <- c(within = 0.4, between = 0.5)

ns <- asNamespace("medfit")
if (mutant == "max_branch") {
  src <- paste(deparse(get("mbco_sem", ns), width.cutoff = 500L), collapse = "\n")
  stopifnot(lengths(regmatches(src, gregexpr("min(diff_ll)", src, fixed = TRUE))) == 1L)
  # eval(parse()) on this package's own deparsed function with a literal swap, as sem_mutate() in helper-sem.R
  fn <- eval(parse(text = sub("min(diff_ll)", "max(diff_ll)", src, fixed = TRUE)))
  environment(fn) <- ns
  # the namespace and the attached package environment each hold a binding; the script calls the attached one
  for (env in list(ns, as.environment("package:medfit"))) {
    if (bindingIsLocked("mbco_sem", env)) unlockBinding("mbco_sem", env)
    assign("mbco_sem", fn, envir = env)
  }
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
patterns <- list(zero_a = c(a = 0, b = 1), zero_b = c(a = 1, b = 0), origin = c(a = 0, b = 0))
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
  w <- patterns[[pat]] * nz[["within"]]
  b <- patterns[[pat]] * nz[["between"]]
  sw <- lev_sigma(w[["a"]], w[["b"]], 0.2, c(1, 0.8, 0.9))
  sb <- lev_sigma(b[["a"]], b[["b"]], 0.1, c(0.5, 0.4, 0.4))
  cl <- rep(seq_len(n_cl), each = n_j)
  u <- matrix(stats::rnorm(n_cl * 3), ncol = 3) %*% chol(sb)
  e <- matrix(stats::rnorm(length(cl) * 3), ncol = 3) %*% chol(sw)
  z <- u[cl, , drop = FALSE] + e
  data.frame(cluster = cl, X = z[, 1] + 1, M = z[, 2] - 0.5, Y = z[, 3] + 2)
}

test_level <- function(fit, a, b) {
  tryCatch({
    r <- suppressWarnings(mbco_sem(fit, a, b))
    c(stat = unname(r$statistic), p = unname(r$p.value), err = if (isTRUE(r$unresolved)) "unresolved" else "")
  }, error = function(e) c(stat = NA, p = NA, err = paste(class(e)[1], conditionMessage(e))))
}

one <- function(i) {
  cl <- cells[(i - 1L) %% nrow(cells) + 1L, ]
  rep <- (i - 1L) %/% nrow(cells) + 1L
  set.seed(1e5L * rep + 100L * cl$J + match(cl$pattern, names(patterns)))
  d <- simulate(cl$pattern, cl$J)
  fit <- tryCatch(suppressWarnings(fit_sem(model, d, cluster = "cluster")), error = function(e) e)
  res <- if (inherits(fit, "error")) {
    msg <- paste("fit:", class(fit)[1], conditionMessage(fit))
    list(within = c(stat = NA, p = NA, err = msg), between = c(stat = NA, p = NA, err = msg))
  } else {
    list(within = test_level(fit, "a_w", "b_w"), between = test_level(fit, "a_b", "b_b"))
  }
  do.call(rbind, lapply(names(res), function(lv) {
    data.frame(pattern = cl$pattern, J = cl$J, level = lv, rep = rep, stat = as.numeric(res[[lv]][["stat"]]),
               p = as.numeric(res[[lv]][["p"]]), err = substr(gsub("\\s+", " ", res[[lv]][["err"]]), 1, 160))
  }))
}

t0 <- Sys.time()
cores <- max(1L, parallel::detectCores() - 1L)
runs <- do.call(rbind, parallel::mclapply(seq_len(reps * nrow(cells)), one, mc.cores = cores))
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))

summ <- do.call(rbind, lapply(split(runs, list(runs$pattern, runs$J, runs$level), drop = TRUE), function(g) {
  ok <- !is.na(g$p)
  data.frame(
    pattern = g$pattern[1], J = g$J[1], level = g$level[1], n_j = n_j, reps = nrow(g), fails = sum(!ok),
    reject = mean(g$p[ok] < alpha), mc_se = sqrt(alpha * (1 - alpha) / sum(ok)),
    reject_se = sqrt(mean(g$p[ok] < alpha) * (1 - mean(g$p[ok] < alpha)) / sum(ok)),
    fit_inadm = sum(startsWith(g$err, "fit: medfit_error_twolevel_inadmissible")),
    null_inadm = sum(startsWith(g$err, "medfit_error_twolevel_inadmissible")),
    ledger = sum(startsWith(g$err, "medfit_error_ledger")), unresolved = sum(g$err == "unresolved"),
    reject_all = sum(g$p[ok] < alpha) / nrow(g), reject_all_se = sqrt(alpha * (1 - alpha) / nrow(g)),
    reject_10 = mean(g$p[ok] < 0.10), mean_stat = mean(g$stat[ok]),
    oracle_gap = max(abs(g$p[ok] - stats::pchisq(g$stat[ok], 1, lower.tail = FALSE)))
  )
}))
rownames(summ) <- NULL
summ <- summ[order(summ$level, summ$J, summ$pattern), ]
summ$other <- summ$fails - summ$fit_inadm - summ$null_inadm - summ$ledger - summ$unresolved
summ$limit <- alpha + 3 * summ$mc_se
summ$pass <- summ$reject <= summ$limit
summ$mutant <- mutant

dir.create("tests/sim/results", showWarnings = FALSE)
tag <- if (nzchar(mutant)) paste0(mutant, "-") else ""
utils::write.csv(summ, file.path("tests/sim/results", sprintf("sem-twolevel-mbco-size-%s%s.csv", tag, Sys.Date())),
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
