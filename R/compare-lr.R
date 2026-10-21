# Comparison engines for constrained LR fits (#249). T1: the detection rules, pure functions on injected results.
#
# medfit's own product-null test (`mbco_sem()`) is the reference. An external engine (lavaan, OpenMx) is run on the same
# model; `.lr_assess()` judges each run. Evidence rules (grill 2026-10-21, decision 2): a warning needs observed
# evidence, never an LR value alone (a valid fit has LR = 0 when the unrestricted optimum already satisfies the
# null), and an unresolved reference or a model mismatch assigns no fault to either side.

# Tolerance scale shared with the nonlinear profile gate: |dLR| <= tol * max(1, LR_medfit).
.lr_tol <- 1e-4
# A product constraint is violated when |a*b| of the returned fit exceeds this.
.lr_constraint_tol <- 1e-4
# The unrestricted fits agree when the largest scaled estimate difference is below this.
.lr_precheck_tol <- 1e-4

# `reference`: list(lr, accepted, est) from medfit (accepted = every branch fit accepted with a comparable likelihood).
# `engines`: list of list(engine, version, est, runs = list(list(start, lr, converged, residual, jac_zero_at_start))).
# Returns list(verdict = agree | disagree | unresolved, reason, runs = data.frame, conditions = list of warnings).
.lr_assess <- function(reference, engines, tolerance = .lr_tol, constraint_tol = .lr_constraint_tol,
                       precheck_tol = .lr_precheck_tol) {
  scale <- tolerance * max(1, reference$lr)
  rows <- list()
  conditions <- list()
  reasons <- character()
  for (eng in engines) {
    mismatch <- .lr_precheck(reference$est, eng$est, precheck_tol)
    if (length(mismatch)) {
      reasons <- c(reasons, sprintf("the unrestricted %s fit differs from medfit's on %s", eng$engine,
                                    paste(mismatch, collapse = ", ")))
    }
    for (run in eng$runs) {
      status <- if (!isTRUE(reference$accepted) || length(mismatch)) {
        "unresolved"
      } else if (!isTRUE(run$converged) || !is.finite(run$lr)) {
        "failed"
      } else if (isTRUE(run$residual > constraint_tol)) {
        "constraint_violated"
      } else if (run$lr > reference$lr + scale) {
        "above_reference"
      } else if (run$lr < reference$lr - scale) {
        "below_reference"
      } else {
        "agree"
      }
      cnd <- .lr_condition(status, eng, run, reference)
      if (!is.null(cnd)) {
        conditions[[length(conditions) + 1L]] <- cnd
      }
      rows[[length(rows) + 1L]] <- data.frame(
        engine = eng$engine, version = eng$version, start = run$start, lr = run$lr,
        converged = isTRUE(run$converged), residual = run$residual, status = status, stringsAsFactors = FALSE
      )
    }
  }
  runs <- do.call(rbind, rows)
  if (!isTRUE(reference$accepted)) {
    reasons <- c("medfit has no accepted comparable result for the null (a branch fit was not accepted)", reasons)
  }
  verdict <- if (all(runs$status %in% c("unresolved", "failed"))) {
    "unresolved"
  } else if (any(runs$status %in% c("constraint_violated", "above_reference", "below_reference"))) {
    "disagree"
  } else {
    "agree"
  }
  list(verdict = verdict, reason = paste(reasons, collapse = "; "), runs = runs, conditions = conditions)
}

# Names of the parameters on which the engine's unrestricted estimates differ from medfit's, scaled by max(1, |medfit|).
.lr_precheck <- function(ref_est, eng_est, tol) {
  common <- intersect(names(ref_est), names(eng_est))
  if (!length(common)) {
    return("(no common parameters)")
  }
  gap <- abs(eng_est[common] - ref_est[common]) / pmax(1, abs(ref_est[common]))
  common[!is.finite(gap) | gap > tol]
}

.lr_condition <- function(status, eng, run, reference) {
  who <- sprintf("%s %s", eng$engine, eng$version)
  start <- sprintf("%s start", run$start)
  if (identical(status, "constraint_violated")) {
    jac <- if (isTRUE(run$jac_zero_at_start)) " The constraint's Jacobian is zero at the start." else ""
    rlang::warning_cnd(
      class = c("medfit_warning_engine_constraint_dropped", "medfit_warning_engine_comparison"),
      message = sprintf(paste0("%s returned a fit that violates the product constraint (|a*b| = %s) from the %s; the ",
                               "constraint may have been dropped.%s Compare with medfit's result before using its ",
                               "statistic."), who, format(run$residual, digits = 3), start, jac)
    )
  } else if (identical(status, "above_reference")) {
    rlang::warning_cnd(
      class = c("medfit_warning_engine_statistic_above_max", "medfit_warning_engine_comparison"),
      message = sprintf(paste0("%s returned a statistic (%s) above the restricted maximum found by medfit (%s) from ",
                               "the %s; the constrained fit may have stopped at a worse point."), who,
                        format(run$lr, digits = 6), format(reference$lr, digits = 6), start)
    )
  }
}

# Raise each condition of an assessment as a classed warning.
.lr_signal <- function(assessment) {
  for (cnd in assessment$conditions) {
    rlang::cnd_signal(cnd)
  }
  invisible(assessment)
}
