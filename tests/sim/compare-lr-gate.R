# Live gate for compare_lr() (#249 T5). The issue's cell: X, M independent N(0, 1), Y = 0.3 X + N(0, 1), n = 100 (the
# joint null a = b = 0), model `M ~ a*X; Y ~ b*M + cp*X`, null `a*b == 0`, through lavaan and OpenMx from their default
# and zero starts, over SEEDS seeds. The reference is the exact minimum of the two linear nulls (mbco_sem()).
#
# The gate passes whether or not the upstream bugs still reproduce (they are recorded: engine versions and the
# `drop` / `above` columns). It fails only when compare_lr() mislabels, per (engine, seed):
#   drop     a run whose returned fit violates a*b == 0 (scaled residual > 1e-4) must raise the constraint-dropped
#            warning, and that warning must not be raised without one
#   above    a feasible run whose statistic exceeds medfit's by more than 1e-4 * max(1, LR) must raise the
#            above-maximum warning, and not otherwise
#   error    compare_lr() must return (a refusal or crash fails the row)
# `MUTANT=noresidual` plants a detector that ignores the constraint residual; the gate must then exit 1 (it needs a
# reproduced drop, which OpenMx's zero start gives 59 times in 60 on the recorded versions).
# Run from the package root:  Rscript tests/sim/compare-lr-gate.R   (FAST=1: 4 seeds, nothing written)

suppressMessages(pkgload::load_all(quiet = TRUE))
mutant <- Sys.getenv("MUTANT", "")
if (!mutant %in% c("", "noresidual")) stop("unknown MUTANT: ", mutant)
fast <- nzchar(Sys.getenv("FAST", ""))
seeds <- seq_len(if (fast) 4L else as.integer(Sys.getenv("SEEDS", "12")))
if (!requireNamespace("lavaan", quietly = TRUE) || !requireNamespace("OpenMx", quietly = TRUE)) {
  stop("the compare-lr gate needs both lavaan and OpenMx")
}
if (mutant == "noresidual") {
  ns <- asNamespace("medfit")
  unlockBinding(".lr_constraint_tol", ns)
  assign(".lr_constraint_tol", Inf, envir = ns)
}
tol <- 1e-4
model <- "M ~ a*X\nY ~ b*M + cp*X"
versions <- c(lavaan = as.character(utils::packageVersion("lavaan")),
              openmx = as.character(utils::packageVersion("OpenMx")))

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
    return(data.frame(engine = engine, version = versions[[engine]], seed = seed, verdict = "error", drop = NA,
                      above = NA, warn_drop = NA, warn_above = NA, mislabel = TRUE, pass = FALSE, note = res,
                      stringsAsFactors = FALSE))
  }
  runs <- res$runs
  ref <- res$reference$lr
  violated <- is.finite(runs$residual) & runs$residual > tol
  above <- !violated & is.finite(runs$lr) & runs$converged & runs$lr > ref + tol * max(1, ref)
  warn_drop <- any(seen == "medfit_warning_engine_constraint_dropped")
  warn_above <- any(seen == "medfit_warning_engine_statistic_above_max")
  mislabel <- res$reference$accepted && (any(violated) != warn_drop || any(above) != warn_above)
  data.frame(engine = engine, version = versions[[engine]], seed = seed, verdict = res$verdict,
             drop = any(violated), above = any(above), warn_drop = warn_drop, warn_above = warn_above,
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
