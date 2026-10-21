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
# Run from the package root:  Rscript tests/sim/compare-lr-gate.R   (FAST=1: 4 seeds, nothing written)

suppressMessages(pkgload::load_all(quiet = TRUE))
mutant <- Sys.getenv("MUTANT", "")
if (!mutant %in% c("", "noresidual", "zeroresid")) stop("unknown MUTANT: ", mutant)
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
    orig(reference, engines, ...)
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
  fit <- suppressWarnings(fit_sem(model, d))
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
    return(data.frame(engine = engine, version = versions[[engine]], seed = seed, verdict = "error", all_converged = NA, ref_ok = NA, drop = NA,
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
             all_converged = all_converged, ref_ok = ref_ok, drop = any(violated), above = any(above), warn_drop = warn_drop, warn_above = warn_above,
             mislabel = mislabel, pass = !mislabel, note = "", stringsAsFactors = FALSE)
}

rows <- list()
for (engine in c("lavaan", "openmx")) {
  for (seed in seeds) {
    rows[[length(rows) + 1L]] <- one(engine, seed)
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
                   "openmx above %d; %s\n"),
            sum(res$pass), nrow(res), if (nzchar(mutant)) paste0(" (MUTANT=", mutant, ")") else "",
            sum(res$above[res$engine == "lavaan"], na.rm = TRUE), sum(res$drop[res$engine == "openmx"], na.rm = TRUE),
            sum(res$above[res$engine == "openmx"], na.rm = TRUE),
            paste(names(versions), versions, collapse = ", ")))
quit(status = if (all(res$pass)) 0L else 1L)
