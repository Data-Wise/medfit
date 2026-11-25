# Native MLR gate, P1a (planning/PLAN-lavaan-parity-0.21.0-2026-11-24.md): `fit_sem(estimator = "MLR")`, the ML
# estimates, the sandwich standard errors and the Yuan-Bentler scaled chi-square (R/sem-mlr.R).
# Oracle: lavaan `estimator = "MLR"` (its default test is "yuan.bentler.mplus"), complete data, skewed and heavy-tailed
# data so the scaling factor is far from 1. Rows (cell, check, value, limit, pass):
#   oracle cells  five models (over, chain, cov, equal = a labeled equality, latent) x fixed_x TRUE/FALSE, four checks:
#                 est (max absolute gap of the estimates), se (of the standard errors), factor (the scaling factor), all
#                 at 1e-5; scaled (the scaled chi-square, relative to max(1, lavaan's), 1e-5: lavaan stops its optimizer
#                 about 1e-6 from the optimum, which moves a statistic near 24 by about 2e-5)
#   meta          invariance (max relative change of the scaling factor and the scaled chi-square, limit 1e-6) when the
#                 data rows are permuted, the columns and model statements are reordered, and the variables are
#                 rescaled (x by 10, m1 by 0.1)
#   size          a reliability cell: rejection rate of the scaled test at alpha = 0.05 under a true model with heavy
#                 tails and heteroskedastic errors (n = 2000, REPS = 2000, df = 2), limit 0.08 (the nominal rate plus
#                 the Monte Carlo band plus the small-sample slack of a scaled test); and the separation check: the
#                 plain ML test must reject at least 0.03 more often, so a scaling that does nothing is not size-OK
#   faults        injected misuse (the Satorra-Bentler estimator, weights, fiml, cluster, a nonlinear equality, a linear
#                 inequality, an estimate on a bound): the number not refused with the right classed error, limit 0;
#                 and the ML neutrality count (omitted vs "ML" estimator differ, or the scaled columns appear in an ML
#                 fit), limit 0
# MUTANT=sfac_df1 (factor divided by df + 1), keep_fixed (fixed exogenous moments kept in A1 and B1), sandwich_h0
# (robust covariance in the model trace), normal_trace (the normal-theory saturated trace), no_scaling (the statistic
# not divided by the factor), no_bound_guard (the bound refusal removed), fixed_pos (the fixed-x index by position)
# alter production functions in memory only and must fail.
# Run from the package root:  Rscript tests/sim/sem-mlr-gate.R   (REPS=2000 by default; the committed rows need 2000)
suppressMessages(pkgload::load_all(quiet = TRUE))
helpers <- new.env(parent = globalenv())
sys.source("tests/testthat/helper-sem.R", envir = helpers)
ns <- asNamespace("medfit")
mutant <- Sys.getenv("MUTANT", "")
swap <- function(name, pattern, replacement) {
  fn <- helpers$sem_mutate(get(name, ns), pattern, replacement)
  if (bindingIsLocked(name, ns)) unlockBinding(name, ns)
  assign(name, fn, envir = ns)
}
if (mutant == "sfac_df1") {
  swap(".sem_mlr_record", "sfac <- (h1 - h0)/df", "sfac <- (h1 - h0)/(df + 1)")
} else if (mutant == "keep_fixed") {
  swap(".sem_mlr_trace_h1", "keep_cov <- !(idx[, 1L] %in% fixed & idx[, 2L] %in% fixed)",
       "keep_cov <- rep(TRUE, nrow(idx))")
} else if (mutant == "sandwich_h0") {
  swap(".sem_mlr_record", "model_fit@vcov", "fit@vcov")
} else if (mutant == "normal_trace") {
  swap(".sem_mlr_record", "h1 <- .sem_mlr_trace_h1(smp$x, isTRUE(ram$has_mean), fixed)",
       "h1 <- ncol(smp$x) + ncol(smp$x) * (ncol(smp$x) + 1) / 2 - length(fixed) * (length(fixed) + 3) / 2")
} else if (mutant == "no_scaling") {
  swap(".sem_mlr_record", "mlr$chisq_scaled <- chisq/sfac", "mlr$chisq_scaled <- chisq")
} else if (mutant == "no_bound_guard") {
  swap(".sem_mlr_record", "if (length(fit@diagnostics$active_bounds)) {", "if (FALSE) {")
} else if (mutant == "fixed_pos") {
  swap(".sem_mlr_record", "fixed <- match(fit@internals$fixed_x, ram$obs)",
       "fixed <- seq_along(fit@internals$fixed_x)")
} else if (nzchar(mutant)) {
  stop("unknown MUTANT: ", mutant)
}

reps <- as.integer(Sys.getenv("REPS", "2000"))
limits <- c(est = 1e-5, se = 1e-5, factor = 1e-5, scaled = 1e-5, invariance = 1e-6, reject_mlr = 0.08,
            separation = 0, refused = 0, ml_neutral = 0)
records <- new.env(parent = emptyenv())
records$rows <- list()
add <- function(cell, check, value) {
  records$rows[[length(records$rows) + 1L]] <- data.frame(
    cell = cell, check = check, value = value, limit = limits[[check]],
    pass = is.finite(value) && value >= 0 && value <= limits[[check]], stringsAsFactors = FALSE
  )
}

# ---- oracle cells: skewed data, five models, fixed_x TRUE/FALSE ----
set.seed(20261125)
n <- 400
x <- stats::rexp(n) - 1
m1 <- 0.5 * x + stats::rexp(n) - 1
m2 <- 0.3 * x + 0.2 * m1 + (stats::rchisq(n, 2) - 2) / 2
y <- 0.4 * m1 + 0.3 * m2 + 0.1 * x + (stats::rexp(n) - 1) * (1 + 0.5 * abs(x))
d <- data.frame(x = x, m1 = m1, m2 = m2, y = y, z = stats::rnorm(n))
f <- stats::rexp(n) - 1
dl <- data.frame(y1 = f + stats::rexp(n) - 1, y2 = 0.8 * f + stats::rexp(n) - 1, y3 = 1.1 * f + stats::rexp(n) - 1,
                 x = stats::rnorm(n))
dl$y1 <- dl$y1 + 0.3 * dl$x
cells <- list(
  over = list(m = "m1 ~ x\nm2 ~ x\ny ~ m1 + m2", d = d),
  chain = list(m = "m1 ~ x\nm2 ~ m1 + x\ny ~ m2", d = d),
  cov = list(m = "m1 ~ x + z\nm2 ~ x\ny ~ m1 + m2 + z", d = d),
  equal = list(m = "m1 ~ a*x\nm2 ~ a*x\ny ~ m1 + m2", d = d),
  latent = list(m = "f =~ y1 + y2 + y3\nf ~ x", d = dl)
)
mlr_gap <- function(fit, ref) {
  g <- generics::glance(fit)
  fm <- lavaan::fitMeasures(ref, c("chisq.scaled", "chisq.scaling.factor"))
  keep <- !duplicated(names(lavaan::coef(ref)))
  est <- lavaan::coef(ref)[keep]
  se <- sqrt(diag(lavaan::vcov(ref)))[keep]
  nm <- names(coef(fit))
  ok <- setequal(nm, names(est)) && length(nm) == length(est)
  c(est = if (ok) max(abs(unname(coef(fit)) - unname(est[nm]))) else NA_real_,
    se = if (ok) max(abs(unname(sqrt(diag(vcov(fit)))) - unname(se[nm]))) else NA_real_,
    factor = abs(g$scaling_factor - fm[["chisq.scaling.factor"]]),
    scaled = abs(g$chisq_scaled - fm[["chisq.scaled"]]) / max(1, fm[["chisq.scaled"]]))
}
for (nm in names(cells)) {
  for (fx in c(TRUE, FALSE)) {
    cell <- paste0(nm, if (fx) ":fx" else ":free")
    fit <- tryCatch(suppressWarnings(fit_sem(cells[[nm]]$m, cells[[nm]]$d, estimator = "MLR", fixed_x = fx)),
                    error = function(e) NULL)
    ref <- tryCatch(suppressWarnings(lavaan::sem(cells[[nm]]$m, cells[[nm]]$d, estimator = "MLR", fixed.x = fx,
                                                 meanstructure = TRUE)), error = function(e) NULL)
    gap <- if (is.null(fit) || is.null(ref)) c(est = NA, se = NA, factor = NA, scaled = NA) else mlr_gap(fit, ref)
    for (ch in c("est", "se", "factor", "scaled")) add(cell, ch, unname(gap[[ch]]))
  }
}

# ---- metamorphic invariance of the scaling factor and the scaled chi-square ----
mod <- cells$cov$m
base <- generics::glance(fit_sem(mod, d, estimator = "MLR"))
rel <- function(g) {
  max(abs(g$scaling_factor - base$scaling_factor) / base$scaling_factor,
      abs(g$chisq_scaled - base$chisq_scaled) / max(1, base$chisq_scaled))
}
set.seed(1)
perm_rows <- generics::glance(fit_sem(mod, d[sample(nrow(d)), ], estimator = "MLR"))
reordered <- paste(rev(strsplit(mod, "\n", fixed = TRUE)[[1L]]), collapse = "\n")
perm_cols <- generics::glance(fit_sem(reordered, d[, rev(names(d))], estimator = "MLR"))
ds <- d
ds$x <- ds$x * 10
ds$m1 <- ds$m1 * 0.1
rescaled <- generics::glance(fit_sem(mod, ds, estimator = "MLR"))
add("meta:rows", "invariance", rel(perm_rows))
add("meta:columns", "invariance", rel(perm_cols))
add("meta:rescale", "invariance", rel(rescaled))

# ---- reliability cell: size of the scaled test under heavy tails and heteroskedastic errors ----
gen <- function(n, seed) {
  set.seed(seed)
  x <- stats::rt(n, 5)
  m1 <- 0.5 * x + stats::rt(n, 5)
  m2 <- 0.3 * x + stats::rt(n, 5)
  y <- 0.4 * m1 + 0.3 * m2 + stats::rt(n, 5) * sqrt(1 + 0.5 * m1^2) / 1.5
  data.frame(x = x, m1 = m1, m2 = m2, y = y)
}
p <- parallel::mclapply(seq_len(reps), function(s) {
  fit <- tryCatch(suppressWarnings(fit_sem("m1 ~ x\nm2 ~ x\ny ~ m1 + m2", gen(2000L, s), estimator = "MLR")),
                  error = function(e) NULL)
  g <- if (is.null(fit)) NULL else generics::glance(fit)
  if (is.null(g)) c(NA_real_, NA_real_) else c(g$p_value, g$p_value_scaled)
}, mc.cores = max(1L, min(12L, parallel::detectCores() - 1L)))
p <- do.call(rbind, p)
p <- p[stats::complete.cases(p), , drop = FALSE]
rej_ml <- mean(p[, 1L] < 0.05)
rej_mlr <- mean(p[, 2L] < 0.05)
add("size:heavy-tail", "reject_mlr", if (nrow(p) >= 0.98 * reps) rej_mlr else NA_real_)
add("size:heavy-tail", "separation", if (nrow(p) >= 0.98 * reps) max(0, 0.03 - (rej_ml - rej_mlr)) else NA_real_)

# ---- fault injection: misuse refused with the right classed error; ML neutrality ----
caught <- function(expr, cls) inherits(tryCatch(expr, error = function(e) e), cls)
dm <- d
dm$id <- rep(1:40, each = 10)
b <- data.frame(x = stats::rnorm(200))
b$y <- 0.01 * b$x + stats::rnorm(200)
m <- cells$over$m
refused <- c(
  caught(fit_sem(m, d, estimator = "MLM"), "medfit_error_estimator"),
  caught(fit_sem(m, d, estimator = "MLR", weights = rep(1, nrow(d))), "medfit_error_mlr_weights"),
  caught(fit_sem(m, d, estimator = "MLR", missing = "fiml"), "medfit_error_mlr_missing"),
  caught(fit_sem(m, dm, estimator = "MLR", cluster = "id"), "medfit_error_mlr_twolevel"),
  caught(fit_sem("m1 ~ a*x\ny ~ b*m1 + cp*x\ncp == a*b", d, estimator = "MLR"), "medfit_error_mlr_constraints"),
  caught(fit_sem("m1 ~ a*x\ny ~ b*m1 + x\na - b > 0.1", d, estimator = "MLR"), "medfit_error_mlr_constraints"),
  caught(suppressWarnings(fit_sem("y ~ x\ny ~~ lower(1.5)*y", b, estimator = "MLR")), "medfit_error_mlr_bounds")
)
add("faults", "refused", sum(!refused))
ml_a <- fit_sem(m, d)
ml_b <- fit_sem(m, d, estimator = "ML")
mlr <- fit_sem(m, d, estimator = "MLR", se_type = "model")
same <- function(a, b) {
  identical(coef(a), coef(b)) && identical(vcov(a), vcov(b)) &&
    identical(generics::glance(a), generics::glance(b)) && identical(generics::tidy(a), generics::tidy(b))
}
scaled_cols <- c("chisq_scaled", "scaling_factor", "p_value_scaled")
add("faults", "ml_neutral", sum(
  !same(ml_a, ml_b),
  any(scaled_cols %in% names(generics::glance(ml_a))),
  !all(scaled_cols %in% names(generics::glance(mlr))),
  !identical(coef(mlr), coef(ml_a)),
  !identical(vcov(mlr), vcov(ml_a))
))

results <- do.call(rbind, records$rows)
rownames(results) <- NULL
dir.create("tests/sim/results", recursive = TRUE, showWarnings = FALSE)
out <- if (nzchar(mutant)) {
  tempfile("mlr-mutant-", fileext = ".csv")
} else {
  file.path("tests/sim/results", paste0("sem-mlr-gate-", Sys.Date(), ".csv"))
}
utils::write.csv(results, out, row.names = FALSE)
print(results)
cat(sprintf("size: ML rejects %.4f, MLR rejects %.4f over %d replications\n", rej_ml, rej_mlr, nrow(p)))
if (!all(results$pass %in% TRUE)) stop("native MLR gate failed")
