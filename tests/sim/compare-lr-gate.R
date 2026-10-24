# Live gate for compare_lr() (#249 T5). The issue's cell: X, M independent N(0, 1), Y = 0.3 X + N(0, 1), n = 100 (the
# joint null a = b = 0), model `M ~ a*X; Y ~ b*M + cp*X`, null `a*b == 0`, through lavaan and OpenMx from their default
# and zero starts, over 15 seeds. The reference is the exact minimum of the two linear nulls (mbco_sem()).
#
# The gate passes whether or not the upstream bugs still reproduce (they are recorded: engine versions and the
# `drop` / `above` columns). It fails only when compare_lr() mislabels, per (engine, seed):
#   drop     a run whose returned fit violates a*b == 0 (scaled residual > 1e-4) must raise the constraint-dropped
#            warning, and that warning must not be raised without one
#   above    a feasible run whose statistic exceeds medfit's by more than 1e-4 * max(1, LR) must raise the
#            above-maximum warning, and not otherwise
#   error    compare_lr() must return (a refusal or crash fails the row)
#   resolved the reference must be accepted, and a verdict of "unresolved" is a mislabel only when every run converged
#            with a finite statistic (a run that failed to converge makes "unresolved" the honest label)
#   oracle   the reference LR must equal an independent closed form (the minimum of the two linear nulls from OLS
#            residual variances, no medfit fit), and a run whose statistic falls below that minimum is infeasible by
#            necessity and must be reported as a violated constraint, whatever residual the adapter reports
# `MUTANT=noresidual` plants a detector that ignores the constraint residual; `MUTANT=zeroresid` an adapter that
# reports a zero residual; the gate must then exit 1 (each needs a reproduced drop, which OpenMx's zero start gives 59
# times in 60 on the recorded versions).
# T4b (R-4) cells, lavaan only (the OpenMx adapter still refuses them until T4c): a non-null cell with a covariate C
# (n = 200, a = b = 0.4), `M ~ a*X + C; Y ~ b*M + cp*X + C`, fit with fixed_x = TRUE, fixed_x = "C", a saturated mean
# structure, and both (fixed_x = "C" with meanstructure = TRUE). The product-null LR is conditional on the exogenous
# block, so the same OLS closed form is the oracle (C partialled out of both branches). A row passes when compare_lr()
# returns, the reference equals the oracle, no run is unresolved (the unrestricted lavaan fit matches medfit's, so the
# fixed set was posed at medfit's values) and the warnings match the observed evidence as in the rule above (lavaan's
# zero start still lands on the wrong branch on some seeds; that is reported, not a failure). `MUTANT=fixedset` plants
# a translation that writes the fixed moments with the N - 1 denominator; the gate must then exit 1.
# Run from the package root:  Rscript tests/sim/compare-lr-gate.R   (FAST=1: 4 seeds, nothing written)

suppressMessages(pkgload::load_all(quiet = TRUE))
mutant <- Sys.getenv("MUTANT", "")
if (!mutant %in% c("", "noresidual", "zeroresid", "fixedset")) stop("unknown MUTANT: ", mutant)
fast <- nzchar(Sys.getenv("FAST", ""))
# 12 plain seeds, plus 15, 37 and 41: seeds on which lavaan's zero start returns a statistic above medfit's (found over
# seeds 1 to 300 on lavaan 0.7.3), so the above-maximum warning is exercised live for lavaan too.
seeds <- c(seq_len(12L), 15L, 37L, 41L)
if (fast) seeds <- seeds[c(1:3, 13L)]
if (!requireNamespace("lavaan", quietly = TRUE) || !requireNamespace("OpenMx", quietly = TRUE)) {
  stop("the compare-lr gate needs both lavaan and OpenMx")
}
if (mutant == "noresidual") {
  ns <- asNamespace("medfit")
  unlockBinding(".lr_constraint_tol", ns)
  assign(".lr_constraint_tol", Inf, envir = ns)
}
if (mutant == "zeroresid") {
  ns <- asNamespace("medfit")
  orig <- get(".lr_assess", ns)
  unlockBinding(".lr_assess", ns)
  assign(".lr_assess", function(reference, engines, ...) {
    engines <- lapply(engines, function(e) {
      e$runs <- lapply(e$runs, function(r) {
        r$residual <- 0
        r
      })
      e
    })
    orig(reference, engines, ...) # nolint: object_usage_linter.
  }, envir = ns)
}
if (mutant == "fixedset") {
  ns <- asNamespace("medfit")
  orig_model <- get(".lr_lavaan_model", ns)
  unlockBinding(".lr_lavaan_model", ns)
  assign(".lr_lavaan_model", function(object) {
    tab <- object@table
    fx <- tab$fixed_x %in% TRUE & tab$op == "~~"
    n <- nrow(object@data)
    tab$est[fx] <- tab$est[fx] * n / (n - 1)
    object@table <- tab
    orig_model(object) # nolint: object_usage_linter.
  }, envir = ns)
}
tol <- 1e-4
model <- "M ~ a*X\nY ~ b*M + cp*X"
versions <- c(lavaan = as.character(utils::packageVersion("lavaan")),
              openmx = as.character(utils::packageVersion("OpenMx")))

# Independent reference: LR of a = 0 is n log(Vm0 / Vm.x), of b = 0 is n log(Vy.x / Vy.mx) (centered ML variances).
oracle_lr <- function(d) {
  n <- nrow(d)
  v <- function(r) mean(r^2)
  lr_a <- n * log(v(d$M - mean(d$M)) / v(stats::resid(stats::lm(M ~ X, d))))
  lr_b <- n * log(v(stats::resid(stats::lm(Y ~ X, d))) / v(stats::resid(stats::lm(Y ~ M + X, d))))
  min(lr_a, lr_b)
}

one <- function(engine, seed) {
  set.seed(seed)
  n <- 100
  d <- data.frame(X = rnorm(n), M = rnorm(n))
  d$Y <- 0.3 * d$X + rnorm(n)
  fit <- suppressWarnings(fit_sem(model, d, fixed_x = FALSE, meanstructure = FALSE))
  seen <- character()
  res <- tryCatch(
    withCallingHandlers(
      compare_lr(fit, c("a", "b"), engine = engine),
      medfit_warning_engine_comparison = function(w) {
        seen <<- c(seen, class(w)[1L])
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) conditionMessage(e)
  )
  if (is.character(res)) {
    return(data.frame(engine = engine, version = versions[[engine]], seed = seed, verdict = "error",
                      all_converged = NA, ref_ok = NA, drop = NA,
                      above = NA, warn_drop = NA, warn_above = NA, mislabel = TRUE, pass = FALSE, note = res,
                      stringsAsFactors = FALSE))
  }
  runs <- res$runs
  ref <- res$reference$lr
  ref_or <- oracle_lr(d)
  ref_ok <- res$reference$accepted && abs(ref - ref_or) <= 1e-6 * max(1, ref_or)
  below <- is.finite(runs$lr) & runs$converged & runs$lr < ref_or - tol * max(1, ref_or)
  below_unflagged <- any(below & runs$status != "constraint_violated")
  violated <- is.finite(runs$residual) & runs$residual > tol
  above <- !violated & is.finite(runs$lr) & runs$converged & runs$lr > ref + tol * max(1, ref)
  warn_drop <- any(seen == "medfit_warning_engine_constraint_dropped")
  warn_above <- any(seen == "medfit_warning_engine_statistic_above_max")
  all_converged <- all(runs$converged & is.finite(runs$lr))
  mislabel <- !ref_ok || (identical(res$verdict, "unresolved") && all_converged) || below_unflagged ||
    any(violated) != warn_drop || any(above) != warn_above
  data.frame(engine = engine, version = versions[[engine]], seed = seed, verdict = res$verdict,
             all_converged = all_converged, ref_ok = ref_ok, drop = any(violated), above = any(above),
             warn_drop = warn_drop, warn_above = warn_above,
             mislabel = mislabel, pass = !mislabel, note = "", stringsAsFactors = FALSE)
}

rows <- list()
for (engine in c("lavaan", "openmx")) {
  for (seed in seeds) {
    rows[[length(rows) + 1L]] <- one(engine, seed)
  }
}

# ---- T4b cells (R-4): fixed_x and a saturated mean structure through lavaan ------------------------------------------
model_c <- "M ~ a*X + C\nY ~ b*M + cp*X + C"
oracle_lr_c <- function(d) {
  n <- nrow(d)
  v <- function(r) mean(r^2)
  rv <- function(f) v(stats::resid(stats::lm(f, d)))
  min(n * log(rv(M ~ C) / rv(M ~ X + C)), n * log(rv(Y ~ X + C) / rv(Y ~ M + X + C)))
}
cells <- list(fixed_all = list(fixed_x = TRUE, meanstructure = FALSE),
              fixed_named = list(fixed_x = "C", meanstructure = FALSE),
              means = list(fixed_x = FALSE, meanstructure = TRUE),
              fixed_named_means = list(fixed_x = "C", meanstructure = TRUE))
one_t4b <- function(cell, seed) {
  set.seed(seed)
  n <- 200
  d <- data.frame(X = rnorm(n), C = rnorm(n))
  d$M <- 0.4 * d$X + 0.3 * d$C + rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
  spec <- cells[[cell]]
  fit <- suppressWarnings(fit_sem(model_c, d, fixed_x = spec$fixed_x, meanstructure = spec$meanstructure))
  seen <- character()
  res <- tryCatch(
    withCallingHandlers(
      compare_lr(fit, c("a", "b"), engine = "lavaan"),
      medfit_warning_engine_comparison = function(w) {
        seen <<- c(seen, class(w)[1L])
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) conditionMessage(e)
  )
  base <- data.frame(engine = paste0("lavaan:", cell), version = versions[["lavaan"]], seed = seed,
                     verdict = "error", all_converged = NA, ref_ok = NA, drop = NA, above = NA, warn_drop = NA,
                     warn_above = NA, mislabel = TRUE, pass = FALSE, note = "", stringsAsFactors = FALSE)
  if (is.character(res)) {
    base$note <- res
    return(base)
  }
  ref_or <- oracle_lr_c(d)
  ref_ok <- res$reference$accepted && abs(res$reference$lr - ref_or) <= 1e-6 * max(1, ref_or)
  runs <- res$runs
  violated <- is.finite(runs$residual) & runs$residual > tol
  above <- !violated & is.finite(runs$lr) & runs$converged & runs$lr > res$reference$lr + tol * max(1, ref_or)
  base$warn_drop <- any(seen == "medfit_warning_engine_constraint_dropped")
  base$warn_above <- any(seen == "medfit_warning_engine_statistic_above_max")
  # posed: every run reached a status (none unresolved), so the unrestricted lavaan fit matched medfit's
  posed <- !any(runs$status %in% c("unresolved", "failed", "unchecked"))
  ok <- ref_ok && posed && any(violated) == base$warn_drop && any(above) == base$warn_above
  base$verdict <- res$verdict
  base$all_converged <- all(runs$converged & is.finite(runs$lr))
  base$ref_ok <- ref_ok
  base$drop <- any(violated)
  base$above <- any(above)
  base$mislabel <- !ok
  base$pass <- ok
  base$note <- if (ok) "" else substr(res$reason, 1L, 200L)
  base
}
for (cell in names(cells)) {
  for (seed in seeds) {
    rows[[length(rows) + 1L]] <- one_t4b(cell, seed)
  }
}
res <- do.call(rbind, rows)
res$mutant <- mutant
shown <- c("engine", "seed", "verdict", "drop", "above", "warn_drop", "warn_above", "note")
print(res[!res$pass, shown], row.names = FALSE)
if (!nzchar(mutant) && !fast) {
  dir.create("tests/sim/results", showWarnings = FALSE)
  out <- file.path("tests/sim/results", sprintf("compare-lr-gate-%s.csv", Sys.Date()))
  utils::write.csv(res, out, row.names = FALSE)
}
cat(sprintf(paste0("COMPARE-LR GATE: %d of %d rows pass%s; reproduced: lavaan above %d, openmx dropped %d, ",
                   "openmx above %d; T4b cells %d of %d; %s\n"),
            sum(res$pass), nrow(res), if (nzchar(mutant)) paste0(" (MUTANT=", mutant, ")") else "",
            sum(res$above[res$engine == "lavaan"], na.rm = TRUE), sum(res$drop[res$engine == "openmx"], na.rm = TRUE),
            sum(res$above[res$engine == "openmx"], na.rm = TRUE),
            sum(res$pass[startsWith(res$engine, "lavaan:")]), sum(startsWith(res$engine, "lavaan:")),
            paste(names(versions), versions, collapse = ", ")))
quit(status = if (all(res$pass)) 0L else 1L)
