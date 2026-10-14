# Null calibration of the model test with an EXOGENOUS product (0.10.0 plan U6 "null gate"; amendment section 2a).
#
# True model: m = .7 x + e; y = .4 m + .3 x + .3 w + .2 (x w) + e'. The product x*w is a function of two purely
# exogenous variables, so the fitted model `m ~ x; y ~ m + x + w + P` is correct and its global chi-square must
# be calibrated although P is non-normal (normal and centered-exponential factors, n = 500, REPS = 1000).
#
# PATH: PRODUCT_PATH=column (the default) reaches the product through a PRECOMPUTED DATA COLUMN (`p = x * w`);
# PRODUCT_PATH=colon writes `x:w` in the model and drops the column, so the product goes through the `:` path (U6
# null gate; `tests/sim/exo-product-null-colon.R` sets it for tests/sim/run-gates.R). The model-fitting function is
# an argument (`fit_fun`, default `fit_sem()`). The chi-square is read with the test-only `.sem_chisq()`, never
# `glance()`, which reports NA for a model whose test is invalid (so the endogenous mutant is measured, not hidden).
#
# Rule (tests/sim/gates.csv rows "product-null" and "product-null-colon", implemented once in
# tests/sim/product-gate-common.R): per factor
# distribution, rejection at .05 within 0.05 +/- 0.02 and |mean chi-square - df| <= 0.15, with at least 99% of the
# replications fitted.
#
# `MUTANT=<name>` plants a defect; the gate must then exit 1:
#   endogenous  the product is x * m (an endogenous factor) while the model still treats it as exogenous: the unchanged
#               RAM implies Cov(e_m, P) = 0, which the data violate (the failure of amendment section 2a)
#   wrongdf     the p-value uses df + 1, a defect in the gate's own reference
# Run from the package root:  Rscript tests/sim/exo-product-null.R   (REPS=1000, PRODUCT_PATH=column by default)

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  suppressMessages(pkgload::load_all(quiet = TRUE))
}
source("tests/sim/product-gate-common.R", local = TRUE)
# nolint start: object_usage_linter. (helpers come from the sourced files)

null_template <- "m ~ x\ny ~ m + x + w + P"

gate_product_null <- function(fit_fun = fit_sem, path = Sys.getenv("PRODUCT_PATH", "column"),
                              reps = as.integer(Sys.getenv("REPS", "1000")), n = 500L,
                              mutant = Sys.getenv("MUTANT", ""),
                              cores = max(1L, parallel::detectCores() - 1L)) {
  stopifnot(mutant %in% c("", "endogenous", "wrongdf"), path %in% c("column", "colon"))
  rows <- lapply(c("norm", "exp"), function(xd) {
    cell <- exo_product_cell(fit_fun, path, null_template, n, reps, xd, cores, wrongdf = identical(mutant, "wrongdf"),
                             endogenous = identical(mutant, "endogenous"))
    cbind(data.frame(xdist = xd, path = path), cell, data.frame(mutant = mutant, stringsAsFactors = FALSE))
  })
  do.call(rbind, rows)
}

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  res <- gate_product_null()
  print(res, digits = 3, row.names = FALSE)
  gate <- if (identical(Sys.getenv("PRODUCT_PATH", "column"), "colon")) "product-null-colon" else "product-null"
  if (!nzchar(Sys.getenv("MUTANT", ""))) {
    product_write_results(res, if (gate == "product-null") "exo-product-null" else "exo-product-null-colon")
  }
  quit(status = product_gate_status(gate, res, product_gate_spec(gate)))
}
# nolint end
