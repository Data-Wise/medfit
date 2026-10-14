# Restricted exogenous block with an exogenous product (0.10.0 plan U6; amendment section 2a, policy of decision 7).
# Companion to exo-product-null.R: three configurations of the exogenous block for the same TRUE model
# (m = .7 x + e; y = .4 m + .3 x + .3 w + .2 (x w) + e'; every restriction below is true):
#   free      no `~~` statement: the engine completes variances and covariances, all free
#   fixvar    factor variances fixed at their true value 1, the covariances written out so they stay free
#   dropcov   only `x ~~ 1*x`, `w ~~ 1*w` written: the pairing rule (R/sem-model.R) then leaves x, w and the product
#             out of the pairing, so their covariances are silently fixed at 0 (true values are 0)
# Factors are N(0, 1) or centered Exp(1) (variance 1, kurtosis 9), n = 500, REPS = 1000.
#
# PATH: PRODUCT_PATH=column (the default of this script) reaches the product through a PRECOMPUTED DATA COLUMN
# `p = x * w`; PRODUCT_PATH=colon (entry script exo-product-fixed-var-colon.R, gates.csv row "product-fixed-var-colon")
# writes `x:w`. The model-fitting function is an argument (`fit_fun`, default `fit_sem()`). On the colon path the
# `fixvar` configuration is skipped, because the grammar amendment has no `~~` statement on a product (a product is not
# allowed as an lhs), so it cannot be written; the (exp, fixvar) miscalibration evidence therefore stays on the
# column-path row, and the colon row keeps (free) and (dropcov).
#
# Rule (gates.csv row "product-fixed-var"; the row's `expect` column is set here from the amendment's table):
#   expected calibrated      (norm, free), (exp, free), (norm, fixvar): rejection at .05 within 0.05 +/- 0.02 and
#                            |mean chi-square / df - 1| <= 0.10
#   expected miscalibrated   (exp, fixvar) 0.38, (norm, dropcov) 0.25, (exp, dropcov) 0.69 in the amendment:
#   rejection at
#                            .05 of at least 0.15. This pins the evidence behind the model-test policy (chi-square
#                            reported NA when the exogenous block is restricted or a factor is endogenous).
# `MUTANT=<name>` plants a defect; the gate must then exit 1:
#   wrongvar    the `fixvar` configuration fixes the variances at 2 instead of the true 1: a wrong restriction, so the
#               calibrated (norm, fixvar) row rejects far above 0.07 (colon path: the `free` configuration is given the
#               same wrong restriction, since `fixvar` cannot be written there)
#   wrongdf     the p-value uses df + 1
# Run from the package root:  Rscript tests/sim/exo-product-fixed-var.R   (REPS=1000)

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  suppressMessages(pkgload::load_all(quiet = TRUE))
}
source("tests/sim/product-gate-common.R", local = TRUE)
# nolint start: object_usage_linter. (helpers come from the sourced files)

fv_templates <- function(var_fixed = 1) {
  c(
    free = "m ~ x\ny ~ m + x + w + P",
    fixvar = sprintf(
      "m ~ x\ny ~ m + x + w + P\nx ~~ %s*x\nw ~~ %s*w\nP ~~ P\nx ~~ w\nx ~~ P\nw ~~ P", var_fixed, var_fixed
    ),
    dropcov = "m ~ x\ny ~ m + x + w + P\nx ~~ 1*x\nw ~~ 1*w"
  )
}
fv_expect <- c("norm.free" = "calibrated", "exp.free" = "calibrated", "norm.fixvar" = "calibrated",
               "exp.fixvar" = "miscalibrated", "norm.dropcov" = "miscalibrated", "exp.dropcov" = "miscalibrated")

gate_product_fixed_var <- function(fit_fun = fit_sem, path = Sys.getenv("PRODUCT_PATH", "column"),
                                   reps = as.integer(Sys.getenv("REPS", "1000")), n = 500L,
                                   mutant = Sys.getenv("MUTANT", ""), cores = max(1L, parallel::detectCores() - 1L)) {
  stopifnot(mutant %in% c("", "wrongvar", "wrongdf"), path %in% c("column", "colon"))
  mods <- fv_templates(if (identical(mutant, "wrongvar")) 2 else 1)
  if (identical(path, "colon")) {
    mods <- mods[setdiff(names(mods), "fixvar")]
    # no `fixvar` configuration to corrupt on this path: `wrongvar` instead restricts the `free` block to a wrong
    # variance, so the calibrated (free) rows must reject
    if (identical(mutant, "wrongvar")) mods[["free"]] <- paste0(mods[["free"]], "\nx ~~ 2*x\nw ~~ 2*w")
  }
  rows <- list()
  for (xd in c("norm", "exp")) {
    for (nm in names(mods)) {
      cell <- exo_product_cell(fit_fun, path, mods[[nm]], n, reps, xd, cores, wrongdf = identical(mutant, "wrongdf"))
      rows[[length(rows) + 1L]] <- cbind(
        data.frame(xdist = xd, config = nm, path = path, expect = fv_expect[[paste(xd, nm, sep = ".")]]), cell,
        data.frame(mutant = mutant, stringsAsFactors = FALSE)
      )
    }
  }
  do.call(rbind, rows)
}

if (!exists("MEDFIT_GATE_SOURCE_ONLY")) {
  res <- gate_product_fixed_var()
  print(res, digits = 3, row.names = FALSE)
  sfx <- product_path_suffix(Sys.getenv("PRODUCT_PATH", "column"))
  if (!nzchar(Sys.getenv("MUTANT", ""))) product_write_results(res, paste0("exo-product-fixed-var", sfx))
  quit(status = product_gate_status(paste0("product-fixed-var", sfx), res,
                                    product_gate_spec(paste0("product-fixed-var", sfx))))
}
# nolint end
