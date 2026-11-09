# Golden snapshot of the existing X -> M -> Y kernel (FI-G0c/G0d parity), see
# planning/specs/SPEC-fiml-generic-kernel-2026-11-08.md section 5. Captured from the pre-change kernel and compared
# after every generalization step. Regenerate only from a commit whose kernel is the declared baseline:
#   Rscript -e 'devtools::load_all(); source("tests/testthat/helper-fiml-golden.R"); gk_write_golden()'
gk_model <- function(direct) paste0("M ~ a*X\nY ~ b*M + ", if (direct) "cp" else "0", "*X")
gk_golden_path <- function() testthat::test_path("fixtures", "fiml-generic-golden.rds")
gk_snapshot <- function(kind, direct) {
  d <- gk_data(kind)
  p <- .sem_fiml_prepare(d, direct = direct)
  th <- gk_theta(direct, 5L)[p$ram$par_names]
  anchor <- gk_theta(direct, 6L)[p$ram$par_names]
  e <- .sem_fiml_eval(th, p)
  out <- list(
    prepare = list(
      par_names = p$ram$par_names, q = p$ram$q, groups = lapply(p$groups, unclass),
      standardized = p$standardized, direct = p$direct, n = p$n, center = p$center, scale = p$scale,
      units = p$units, transport = p$transport, offset = p$offset, jacobian = p$jacobian, rows = p$rows
    ),
    numerics = list(
      theta = th, value = e$value, gradient = e$gradient,
      value_nograd = .sem_fiml_eval(th, p, derivative = FALSE)$value,
      hessian = .sem_fiml_hessian(th, p), hessian2 = .sem_fiml_hessian(th, p, multiplier = 2),
      geometry = .sem_fiml_geometry(th, p), difference = .sem_fiml_difference(th, anchor, p)
    )
  )
  fit <- tryCatch(fit_sem(gk_model(direct), as.data.frame(d), missing = "fiml", fixed_x = FALSE), error = identity)
  out$fit <- if (inherits(fit, "error")) {
    list(error = TRUE, class = class(fit), message = conditionMessage(fit), stage = fit$stage,
         attempts = fit$attempts, n_calls = length(fit$solver_calls))
  } else {
    x <- extract_mediation(fit, treatment = "X", mediator = "M")
    list(
      error = FALSE, coef = stats::coef(fit), vcov = stats::vcov(fit), loglik = as.numeric(stats::logLik(fit)),
      nobs = stats::nobs(fit), n_dropped = fit@n_dropped, attempts = fit@diagnostics$attempts,
      n_calls = length(fit@diagnostics$solver_calls),
      ledger = fit@diagnostics$ledger[c("schema", "outcome", "stationarity", "solver_groups", "solver_calls",
                                        "accepted")],
      table = fit@table,
      likelihood = fit@internals$likelihood[c("method", "x_policy", "nll", "n_obs", "k", "rows", "selected",
                                              "jacobian", "variables")],
      effects = list(nie = as.numeric(nie(x)), nde = as.numeric(nde(x)), te = as.numeric(te(x)),
                     paths = paths(x), estimates = x@estimates, vcov = x@vcov)
    )
  }
  out
}
gk_write_golden <- function(path = file.path("tests", "testthat", "fixtures", "fiml-generic-golden.rds")) {
  cells <- list()
  for (direct in c(TRUE, FALSE)) {
    for (kind in gk_kinds) cells[[paste(kind, if (direct) "free" else "zero")]] <- gk_snapshot(kind, direct)
  }
  dir.create(dirname(path), showWarnings = FALSE, recursive = TRUE)
  saveRDS(cells, path, version = 2)
  invisible(cells)
}
