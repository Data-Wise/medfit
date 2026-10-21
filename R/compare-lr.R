# Comparison engines for constrained LR fits (#249). T1: the detection rules, pure functions on injected results.
#
# medfit's own product-null test (`mbco_sem()`) is the reference. An external engine (lavaan, OpenMx) is run on the same
# model; `.lr_assess()` judges each run. Evidence rules (grill 2026-10-21, decision 2): a warning needs observed
# evidence, never an LR value alone (a valid fit has LR = 0 when the unrestricted optimum already satisfies the
# null), and an unresolved reference or a model mismatch assigns no fault to either side.

# Tolerance scale shared with the nonlinear profile gate: |dLR| <= tol * max(1, LR_medfit).
.lr_tol <- 1e-4
# A product constraint is violated when |a*b| of the returned fit, in the natural units of the product, exceeds this.
.lr_constraint_tol <- 1e-4
# The unrestricted fits agree when the largest scaled estimate difference is below this.
.lr_precheck_tol <- 1e-4

# `reference`: list(lr, accepted, est, fit) from medfit (accepted = every branch fit accepted with a comparable
# likelihood; `fit` the unrestricted discrepancy on the LR scale).
# `engines`: list of list(engine, version, est, fit, runs = list(list(start, lr, converged, residual, residual_scale,
# jac_zero_at_start))); `residual` is |a*b| of the returned fit and `residual_scale` the natural unit of that
# product, so feasibility does not depend on the units of the variables.
# Returns list(verdict = agree | disagree | unresolved, reason, runs = data.frame, conditions = list of warnings).
.lr_assess <- function(reference, engines, tolerance = .lr_tol, constraint_tol = .lr_constraint_tol,
                       precheck_tol = .lr_precheck_tol) {
  scale <- tolerance * max(1, reference$lr)
  rows <- list()
  conditions <- list()
  reasons <- character()
  for (eng in engines) {
    mismatch <- .lr_precheck(reference, eng, precheck_tol)
    if (length(mismatch)) {
      reasons <- c(reasons, sprintf("the unrestricted %s fit differs from medfit's: %s", eng$engine, mismatch))
    }
    for (run in eng$runs) {
      resid <- run$residual / (if (is.null(run$residual_scale)) 1 else run$residual_scale)
      status <- if (!isTRUE(reference$accepted) || length(mismatch)) {
        "unresolved"
      } else if (!isTRUE(run$converged) || !is.finite(run$lr)) {
        "failed"
      } else if (!is.finite(resid)) {
        "unchecked"
      } else if (resid > constraint_tol) {
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
        converged = isTRUE(run$converged), residual = resid, status = status, stringsAsFactors = FALSE
      )
    }
  }
  runs <- do.call(rbind, rows)
  if (!isTRUE(reference$accepted)) {
    reasons <- c("medfit has no accepted comparable result for the null (a branch fit was not accepted)", reasons)
  }
  verdict <- if (all(runs$status %in% c("unresolved", "failed", "unchecked"))) {
    "unresolved"
  } else if (any(runs$status %in% c("constraint_violated", "above_reference", "below_reference"))) {
    "disagree"
  } else {
    "agree"
  }
  list(verdict = verdict, reason = paste(reasons, collapse = "; "), runs = runs, conditions = conditions)
}

# Why the engine's unrestricted fit cannot be compared with medfit's, or character(0) when it can: the parameter sets
# must match exactly, the estimates agree (scaled by max(1, |medfit|)) and the unrestricted discrepancy agrees on the
# same LR scale. Anything unavailable counts as a failure, never as agreement.
.lr_precheck <- function(reference, eng, tol) {
  ref_est <- reference$est
  eng_est <- eng$est
  missing_in_eng <- setdiff(names(ref_est), names(eng_est))
  extra_in_eng <- setdiff(names(eng_est), names(ref_est))
  if (!length(ref_est) || length(missing_in_eng) || length(extra_in_eng)) {
    return(sprintf("parameter sets differ (missing: %s; extra: %s)",
                   if (length(missing_in_eng)) paste(missing_in_eng, collapse = ", ") else "none",
                   if (length(extra_in_eng)) paste(extra_in_eng, collapse = ", ") else "none"))
  }
  gap <- abs(eng_est[names(ref_est)] - ref_est) / pmax(1, abs(ref_est))
  off <- names(ref_est)[!is.finite(gap) | gap > tol]
  if (length(off)) {
    return(sprintf("estimates differ on %s", paste(off, collapse = ", ")))
  }
  if (!is.finite(reference$fit) || !is.finite(eng$fit %||% NA_real_)) {
    return("unrestricted discrepancy unavailable")
  }
  if (abs(eng$fit - reference$fit) / max(1, abs(reference$fit)) > tol) {
    return("unrestricted discrepancy differs")
  }
  character()
}

.lr_condition <- function(status, eng, run, reference) {
  who <- sprintf("%s %s", eng$engine, eng$version)
  start <- sprintf("%s start", run$start)
  if (identical(status, "constraint_violated")) {
    jac <- if (isTRUE(run$jac_zero_at_start)) " The constraint's Jacobian is zero at the start." else ""
    rlang::warning_cnd(
      class = c("medfit_warning_engine_constraint_dropped", "medfit_warning_engine_comparison"),
      message = sprintf(paste0("%s returned a fit that violates the product constraint (|a*b| = %s in natural units) ",
                               "from the %s; the constraint may have been dropped.%s Compare with medfit's result ",
                               "before using its statistic."), who,
                        format(run$residual / (if (is.null(run$residual_scale)) 1 else run$residual_scale),
                               digits = 3), start, jac)
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

# ---- reference and the lavaan adapter (#249 T2) -----------------------------------------------------------------------

# Why compare_lr() cannot run this fit, or NULL when it can. Only observed-variable covariance models are supported
# (grill P3): every other construct is refused with its name, never translated silently.
.lr_unsupported <- function(object) {
  tab <- object@table
  model <- object@model
  internals <- object@internals
  if (any(tab$op == "=~")) {
    return("latent variables")
  }
  if (any(grepl(":", c(tab$lhs, tab$rhs), fixed = TRUE))) {
    return("product terms")
  }
  if (isTRUE(internals$ram$has_mean)) {
    return("a mean structure (intercepts or `meanstructure`)")
  }
  if (!is.null(internals$weights)) {
    return("case weights")
  }
  if (length(internals$fixed_x)) {
    return("`fixed_x`")
  }
  if (length(internals$factors)) {
    return("factor covariates")
  }
  if (grepl("\\b(start|lower|upper)\\s*\\(", model)) {
    return("start, lower or upper modifiers")
  }
  if (grepl("==|<|>", model)) {
    return("constraints in the model (give the unrestricted fit)")
  }
  NULL
}

# Free parameters of a fit table keyed by "lhs op rhs", so medfit's and an engine's parameter sets can be compared.
.lr_key_est <- function(lhs, op, rhs, est) {
  stats::setNames(est, paste(lhs, op, rhs))
}

# medfit's side of the comparison: the product-null LR from `mbco_sem()` (the minimum over the zero-product branches),
# whether every branch fit was accepted, the unrestricted estimates and discrepancy.
.lr_reference <- function(object, paths) {
  tests <- mbco_sem(object, paths = paths)$tests
  free <- object@table[object@table$free, ]
  list(
    lr = min(tests$diff_ll),
    accepted = all(tests$converged) && all(is.finite(tests$diff_ll)),
    est = .lr_key_est(free$lhs, free$op, free$rhs, free$est),
    fit = object@n_obs * object@f
  )
}

# The natural unit of the product of the named regression paths: the product of sd(response) / sd(predictor), so a
# residual |a*b| is judged against how large those paths can plausibly be in the data's units.
.lr_residual_scale <- function(object, paths) {
  tab <- object@table
  unit <- vapply(paths, function(p) {
    row <- tab[tab$op == "~" & tab$label == p, ][1L, ]
    stats::sd(object@data[[row$lhs]]) / stats::sd(object@data[[row$rhs]])
  }, numeric(1))
  prod(unit)
}

.lr_lavaan_fit <- function(model, data, start) {
  fit <- tryCatch(
    suppressWarnings(lavaan::lavaan(model, data = data, fixed.x = FALSE, meanstructure = FALSE, auto.var = TRUE,
                                    auto.cov.y = TRUE, start = start)),
    error = function(e) NULL
  )
  if (is.null(fit) || !isTRUE(lavaan::lavInspect(fit, "converged"))) {
    return(NULL)
  }
  fit
}

# lavaan run on the same model and data, from lavaan's default start and from its "simple" start (the paths at 0, the
# start at which OpenMx drops a product constraint, grill P4). Returns the engine record `.lr_assess()` takes.
.lr_engine_lavaan <- function(object, paths) {
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("the lavaan package is needed for engine = \"lavaan\"; install it first.", call. = FALSE)
  }
  why <- .lr_unsupported(object)
  if (!is.null(why)) {
    stop(sprintf("compare_lr() does not support %s; it compares observed-variable covariance models only.", why),
         call. = FALSE)
  }
  model <- object@model
  data <- object@data
  null_model <- paste0(model, "\n", paste(paths, collapse = "*"), " == 0")
  full <- .lr_lavaan_fit(model, data, "default")
  scale <- .lr_residual_scale(object, paths)
  chisq <- function(f) if (is.null(f)) NA_real_ else unname(lavaan::fitMeasures(f, "chisq"))
  run <- function(start) {
    f <- .lr_lavaan_fit(null_model, data, start)
    resid <- NA_real_
    if (!is.null(f)) {
      pt <- lavaan::parTable(f)
      resid <- abs(prod(vapply(paths, function(p) pt$est[pt$label == p][1L], numeric(1))))
    }
    list(start = if (identical(start, "default")) "default" else "zero", lr = chisq(f) - chisq(full),
         converged = !is.null(f), residual = resid, residual_scale = scale, jac_zero_at_start = NA)
  }
  est <- NULL
  if (!is.null(full)) {
    pt <- lavaan::parTable(full)
    pt <- pt[pt$free > 0L, ]
    est <- .lr_key_est(pt$lhs, pt$op, pt$rhs, pt$est)
  }
  list(engine = "lavaan", version = as.character(utils::packageVersion("lavaan")), est = est, fit = chisq(full),
       runs = list(run("default"), run("simple")))
}
