# =============================================================================
# twolevel_statistic(): scalar bootstrap callbacks for two-level mediation (#394, slice S2, PR3)
# =============================================================================

#' Bootstrap Callback for Two-Level Mediation
#'
#' **Experimental.** The interface may change without the usual deprecation period.
#'
#' Builds the scalar `statistic_fn` that [bootstrap_mediation()] needs for one effect of a two-level
#' (1-1-1) mediation model, so the within and the between indirect effect and their contrast can be
#' bootstrapped without writing the callback by hand. The form of the callback depends on the first
#' argument:
#'
#' * `x` a [TwoLevelMediationData]: the callback for `method = "parametric"` (and `"plugin"`). It takes
#'   the named parameter vector drawn from \eqn{N(\hat\theta, \hat\Sigma)}{N(estimates, vcov)}, so the
#'   cross-level covariance is part of every draw.
#' * `x` a two-level `lavaan` fit (with `treatment`, `mediator` and `outcome`): the callback for
#'   `method = "nonparametric"` with `cluster =`. It refits the fit's own model on each resampled data
#'   set (the call stored in the fit, with `data` replaced) and returns the effect. The cluster
#'   bootstrap gives every drawn cluster a fresh id, so a cluster drawn twice is refitted as two
#'   clusters.
#' * `x` a [TwoLevelParallelMediationData] (several mediators), or a two-level `lavaan` fit with a `mediator`
#'   vector of length two or more: the same two callbacks for the effects that [nie()], [nde()] and [te()]
#'   define for that class. `effect` is then one of `"nie"` (the total indirect effect, the default), `"nie_j"`
#'   (the specific indirect effect of the mediator named in `specific`), `"nde"` or `"te"`, and `level` is
#'   `"within"` (default), `"between"` or `"contrast"` (within minus between, `"nie"` and `"nie_j"` only). The
#'   callback evaluates the same effect code as those generics, so at the estimate it returns their value.
#'
#' A refit that errors, does not converge, warns, or leaves the between level unidentified (a treatment
#' or any mediator ICC below `getOption("medfit.between_icc_error", 0.01)`, for a between effect or the
#' contrast; the ICC is the unrestricted (h1) one that `lavaan::lavInspect(refit, "icc")` reports) is a failed replicate: [bootstrap_mediation()] excludes it and reports the count in a
#' warning. An inadmissible refit (a negative variance) is kept, as the point estimate keeps it. The
#' covariance checks of the point-estimate extraction are not repeated per refit (no standard errors are
#' computed). Refits skip standard errors, the model test and lavaan's post-check (`se = "none"`,
#' `test = "none"`, `check.post = FALSE`), which do not change the maximum likelihood estimates;
#' everything else comes from the fit's own call.
#'
#' @details
#' **Refit environment.** The refit re-evaluates the call stored in the fit with `data` replaced by the
#' resampled data (and, for a `model` that is not a literal string, with the fit's parameter table). Names
#' that lavaan leaves unevaluated in that call (for example `control = ctl` or `estimator = est`) are
#' resolved in the environment that called `twolevel_statistic()`, captured at that call, not where the fit
#' was made and not where the callback later runs. Create the callback in the scope that holds those
#' objects. Calls written with a namespace, such as `lavaan::lavaan()` resolve regardless.
#'
#' The contrast is `NA` by constraint when both `a` and `b` are equated across levels and a between effect is
#' `NA` when the between level is not identified, so asking for either raises a classed error here
#' instead of returning a distribution of `NA`.
#'
#' **Several mediators.** An invalid `level`, or `level = "contrast"` with `effect = "nde"` or `"te"`, stops
#' with class `medfit_error_twolevel_level`. An effect not defined for several mediators, `effect = "nie_j"`
#' without `specific` or with a name that is not one of the mediators, and `specific` with another effect stop
#' with class `medfit_error_twolevel_unsupported`, as do `level` and `specific` given for one mediator. A
#' between effect or the contrast of a within-only fit stops with class `medfit_between_unidentified`, and the
#' contrast of a mediator (for `"nie_j"`) or of every mediator (for `"nie"`) whose `a` and `b` are both equated
#' across levels stops with class `medfit_error_twolevel_constrained`.
#'
#' @param x A [TwoLevelMediationData] or [TwoLevelParallelMediationData] object, or a two-level `lavaan`
#'   fit.
#' @param effect One of `"nie_within"` (default), `"nie_between"`, `"nie_contrast"` (within minus
#'   between, descriptive), `"nde_within"`, `"nde_between"`, `"te_within"`, `"te_between"`,
#'   `"pm_within"`, `"pm_between"`, or a path row: `"a_within"`, `"b_within"`, `"c_prime_within"`,
#'   `"a_between"`, `"b_between"`, `"c_prime_between"`. The proportion mediated is `NA` where the
#'   total effect is zero. For several mediators: `"nie"` (default), `"nie_j"`, `"nde"` or `"te"`.
#' @param treatment,mediator,outcome Variable names. Required for a `lavaan` fit; taken from the object
#'   for a [TwoLevelMediationData] or [TwoLevelParallelMediationData]. `mediator` is a character vector of
#'   length two or more for a fit with several mediators, a character scalar otherwise.
#' @param level For several mediators only: `"within"` (default), `"between"` or `"contrast"`. For one
#'   mediator the level is part of `effect`, and `level` must be left unset.
#' @param specific For `effect = "nie_j"` only: the name of the mediator whose specific indirect effect is
#'   returned.
#'
#' @return A function of one argument returning a number: a named parameter vector for a
#'   [TwoLevelMediationData] or [TwoLevelParallelMediationData], a data frame for a `lavaan` fit.
#'
#' @examples
#' \donttest{
#' if (requireNamespace("lavaan", quietly = TRUE) && requireNamespace("MASS", quietly = TRUE)) {
#'   set.seed(1)
#'   id <- rep(1:60, each = 5)
#'   x <- stats::rnorm(60)[id] + stats::rnorm(300)
#'   m <- 0.5 * x + stats::rnorm(60)[id] + stats::rnorm(300)
#'   y <- 0.4 * m + 0.2 * x + stats::rnorm(60)[id] + stats::rnorm(300)
#'   d <- data.frame(id = id, X = x, M = m, Y = y)
#'   model <- "
#'     level: 1
#'       M ~ X
#'       Y ~ M + X
#'     level: 2
#'       M ~ X
#'       Y ~ M + X
#'   "
#'   fit <- lavaan::sem(model, data = d, cluster = "id")
#'   td <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")
#'   bootstrap_mediation(twolevel_statistic(td, "nie_between"), method = "parametric",
#'                       mediation_data = td, n_boot = 200, seed = 1)
#'   bootstrap_mediation(
#'     twolevel_statistic(fit, "nie_between", treatment = "X", mediator = "M", outcome = "Y"),
#'     method = "nonparametric", data = d, cluster = "id", n_boot = 20, seed = 1
#'   )
#' }
#' }
#'
#' @seealso [bootstrap_mediation()], [TwoLevelMediationData], [TwoLevelParallelMediationData]
#' @export
twolevel_statistic <- function(x,
                               effect = c("nie_within", "nie_between", "nie_contrast",
                                          "nde_within", "nde_between", "te_within", "te_between",
                                          "pm_within", "pm_between",
                                          "a_within", "b_within", "c_prime_within",
                                          "a_between", "b_between", "c_prime_between"),
                               treatment = NULL, mediator = NULL, outcome = NULL, level = NULL,
                               specific = NULL) {
  # Captured here, eagerly: the environment that called twolevel_statistic() is where the names in the stored
  # lavaan call (`control = ctl`, `estimator = est`, ...) are resolved at refit time.
  refit_env <- rlang::caller_env()
  if (S7::S7_inherits(x, TwoLevelParallelMediationData) ||
        (inherits(x, "lavaan") && is.character(mediator) && length(mediator) >= 2L)) {
    effect <- if (missing(effect)) "nie" else effect
    return(.twolevel_stat_parallel(x, effect, treatment, mediator, outcome, level, specific, refit_env))
  }
  if (!is.null(level) || !is.null(specific)) {
    .twolevel_abort(paste0("`level` and `specific` apply to a model with several mediators; for one mediator the ",
                           "level is part of `effect` (for example \"nie_between\")."),
                    "medfit_error_twolevel_unsupported")
  }
  effect <- match.arg(effect)
  checkmate::assert_string(treatment, null.ok = TRUE, .var.name = "treatment")
  checkmate::assert_string(mediator, null.ok = TRUE, .var.name = "mediator")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")

  if (S7::S7_inherits(x, TwoLevelMediationData)) {
    if (!is.null(treatment) || !is.null(mediator) || !is.null(outcome)) {
      .twolevel_abort("`treatment`, `mediator` and `outcome` are read from the object; leave them unset.",
                      "medfit_error_twolevel_unsupported")
    }
    .twolevel_stat_check(x, effect)
    return(.twolevel_stat_parametric(effect))
  }
  if (inherits(x, "lavaan")) {
    if (is.null(treatment) || is.null(mediator) || is.null(outcome)) {
      .twolevel_abort("`treatment`, `mediator` and `outcome` are required for a lavaan fit.",
                      "medfit_error_twolevel_unsupported")
    }
    # The object is read once here to learn what the fit identifies and constrains; no refit.
    td <- suppressWarnings(extract_mediation(x, treatment = treatment, mediator = mediator, outcome = outcome))
    .twolevel_stat_check(td, effect)
    return(.twolevel_stat_refit(x, effect, treatment, mediator, outcome, refit_env))
  }
  .twolevel_abort("x must be a TwoLevelMediationData object or a two-level lavaan fit.",
                  "medfit_error_twolevel_unsupported")
}


# A between effect needs an identified between level; the contrast also needs a and b free across levels.
.twolevel_stat_check <- function(td, effect) {
  if (grepl("between|contrast", effect) && !isTRUE(td@between_identified)) {
    .twolevel_abort(
      sprintf(paste0("`%s` needs the between level, which is not identified in this two-level fit (a ",
                     "within-only result)."), effect),
      "medfit_between_unidentified"
    )
  }
  if (identical(effect, "nie_contrast") && !.twolevel_contrast_available(td)) {
    .twolevel_abort(
      paste0("The contrast NIE_within - NIE_between is NA: both a and b are equated across levels, so the ",
             "contrast is zero by constraint."),
      "medfit_error_twolevel_constrained"
    )
  }
  invisible(td)
}

# One effect from a named vector of path rows (`a_within`, ..., `c_prime_between`); only the requested
# effect is computed.
.twolevel_stat_value <- function(effect, p) {
  if (effect %in% c("a_within", "b_within", "c_prime_within", "a_between", "b_between", "c_prime_between")) {
    return(as.numeric(p[[effect]]))
  }
  if (identical(effect, "nie_contrast")) {
    return(as.numeric(p[["a_within"]] * p[["b_within"]] - p[["a_between"]] * p[["b_between"]]))
  }
  type <- sub("_.*$", "", effect)
  level <- sub("^.*_", "", effect)
  row <- function(path) p[[paste0(path, "_", level)]]
  as.numeric(switch(type,
    nie = row("a") * row("b"),
    nde = row("c_prime"),
    te = row("a") * row("b") + row("c_prime"),
    pm = {
      nie <- row("a") * row("b")
      te <- nie + row("c_prime")
      if (.twolevel_te_defined(te, nie, row("c_prime"))) nie / te else NA_real_
    }
  ))
}

.twolevel_stat_parametric <- function(effect) {
  force(effect)
  function(p) .twolevel_stat_value(effect, p)
}

# The refit callback. The fit's stored call is re-evaluated with `data` replaced (the fit is never
# modified). A call whose `model` is a literal string is kept; a `model` given by name is replaced by the
# fit's own parameter table (estimates and standard errors removed), as `lavaan::update()` does, because the
# name need not resolve at bootstrap time.
.twolevel_stat_refit <- function(fit, effect, treatment, mediator, outcome, env,
                                 value_fn = function(p) .twolevel_stat_value(effect, p),
                                 needs_between = grepl("between|contrast", effect)) {
  force(effect)
  force(env)
  force(value_fn)
  force(needs_between)
  call <- fit@call
  if (is.null(call)) {
    .twolevel_abort("The lavaan fit has no stored call to refit.", "medfit_error_twolevel_unusable")
  }
  if (!is.character(call$model)) {
    model <- lavaan::parTable(fit)
    model$est <- NULL
    model$se <- NULL
    model$start <- NULL   # fresh starts, as a refit from a model string would use
    call$model <- model
  }
  call$se <- "none"
  call$test <- "none"
  # An inadmissible refit (a negative variance) is kept, as the point-estimate extraction keeps it and flags it;
  # lavaan's post-check warning would otherwise make the cluster loop drop the replicate.
  call$check.post <- FALSE
  rm(fit)   # the callback keeps the call, not the (large) fit

  function(d) {
    refit_call <- call
    refit_call$data <- d
    # Re-evaluates the fit's own lavaan call (the user's model and options), not arbitrary input.
    refit <- eval(refit_call, env)
    if (!.twolevel_converged(refit)) return(NA_real_)
    key <- .twolevel_key_rows(lavaan::parTable(refit), treatment, mediator, outcome)
    p <- stats::setNames(key$est, key$path)
    if (needs_between) {
      icc <- .twolevel_icc(refit)
      icc_floor <- .twolevel_option("icc_error")
      if (!all(c(treatment, mediator) %in% names(icc))) return(NA_real_)
      if (any(icc[c(treatment, mediator)] < icc_floor)) return(NA_real_)
    }
    value <- value_fn(p)
    if (is.finite(value)) value else NA_real_
  }
}


# --- Several mediators (TwoLevelParallelMediationData, SPEC-IG5 D4) ---

.twolevel_stat_parallel_effects <- c("nie", "nie_j", "nde", "te")

# The parallel route: validate, read the object once (from the fit for the refit route), and return the
# callback. The value is always a key of .twolevel_parallel_effects(), the kernel nie(), nde() and te() use.
.twolevel_stat_parallel <- function(x, effect, treatment, mediator, outcome, level, specific, env) {
  checkmate::assert_string(effect, .var.name = "effect")
  level <- if (is.null(level)) "within" else level
  if (!checkmate::test_choice(level, c("within", "between", "contrast"))) {
    .twolevel_abort("`level` must be one of \"within\", \"between\" or \"contrast\".", "medfit_error_twolevel_level")
  }
  checkmate::assert_string(specific, null.ok = TRUE, .var.name = "specific")
  checkmate::assert_string(treatment, null.ok = TRUE, .var.name = "treatment")
  checkmate::assert_character(mediator, min.len = 2L, any.missing = FALSE, unique = TRUE, null.ok = TRUE,
                              .var.name = "mediator")
  checkmate::assert_string(outcome, null.ok = TRUE, .var.name = "outcome")
  if (!effect %in% .twolevel_stat_parallel_effects) {
    .twolevel_abort(
      sprintf(paste0("`effect = \"%s\"` is not defined for several mediators; use one of %s, with the level in ",
                     "`level` and the mediator of \"nie_j\" in `specific`."),
              effect, paste0("\"", .twolevel_stat_parallel_effects, "\"", collapse = ", ")),
      "medfit_error_twolevel_unsupported"
    )
  }

  if (S7::S7_inherits(x, TwoLevelParallelMediationData)) {
    if (!is.null(treatment) || !is.null(mediator) || !is.null(outcome)) {
      .twolevel_abort("`treatment`, `mediator` and `outcome` are read from the object; leave them unset.",
                      "medfit_error_twolevel_unsupported")
    }
    td <- x
  } else {
    if (is.null(treatment) || is.null(outcome)) {
      .twolevel_abort("`treatment`, `mediator` and `outcome` are required for a lavaan fit.",
                      "medfit_error_twolevel_unsupported")
    }
    # The object is read once here to learn what the fit identifies and constrains; no refit.
    td <- suppressWarnings(extract_mediation(x, treatment = treatment, mediator = mediator, outcome = outcome))
  }
  .twolevel_stat_parallel_check(td, effect, level, specific)
  key <- .twolevel_stat_parallel_key(td, effect, level, specific)
  mediators <- td@mediators
  avail <- .twolevel_parallel_contrast_available(td)
  value_fn <- function(p) as.numeric(.twolevel_parallel_effects(p, mediators, avail)[[key]])

  if (S7::S7_inherits(x, TwoLevelParallelMediationData)) return(value_fn)
  .twolevel_stat_refit(x, effect, treatment, mediator, outcome, env, value_fn = value_fn,
                       needs_between = !identical(level, "within"))
}

# The name of the requested effect in the kernel's vector: `nie_<level>`, `nie_<M>_<level>`, `nde_<level>`,
# `te_<level>`.
.twolevel_stat_parallel_key <- function(td, effect, level, specific) {
  if (identical(effect, "nie_j")) paste0("nie_", specific, "_", level) else paste0(effect, "_", level)
}

# The parallel counterpart of .twolevel_stat_check(): the mediator of "nie_j", the contrast only for nie (as
# nie(), nde(), te() define it), an identified between level, and a contrast that is not zero by constraint.
.twolevel_stat_parallel_check <- function(td, effect, level, specific) {
  if (identical(effect, "nie_j")) {
    if (is.null(specific) || !specific %in% td@mediators) {
      .twolevel_abort(
        sprintf("`effect = \"nie_j\"` needs `specific`, one of the mediators: %s.",
                paste0("\"", td@mediators, "\"", collapse = ", ")),
        "medfit_error_twolevel_unsupported"
      )
    }
  } else if (!is.null(specific)) {
    .twolevel_abort(sprintf("`specific` applies to `effect = \"nie_j\"` only, not to \"%s\".", effect),
                    "medfit_error_twolevel_unsupported")
  }
  if (identical(level, "contrast") && effect %in% c("nde", "te")) {
    .twolevel_abort(
      sprintf("`level = \"contrast\"` is defined only for nie(); %s() has no first-class contrast. Use tidy().",
              effect),
      "medfit_error_twolevel_level"
    )
  }
  if (!identical(level, "within") && !isTRUE(td@between_identified)) {
    .twolevel_abort(
      sprintf(paste0("`%s` at `level = \"%s\"` needs the between level, which is not identified in this ",
                     "two-level fit (a within-only result)."), effect, level),
      "medfit_between_unidentified"
    )
  }
  if (identical(level, "contrast")) {
    avail <- .twolevel_parallel_contrast_available(td)
    ok <- if (identical(effect, "nie_j")) avail[[specific]] else avail[["total"]]
    if (!ok) {
      what <- if (identical(effect, "nie_j")) sprintf("mediator \"%s\"", specific) else "every mediator"
      .twolevel_abort(
        sprintf(paste0("The contrast NIE_within - NIE_between is NA: both a and b of %s are equated across ",
                       "levels, so the contrast is zero by constraint."), what),
        "medfit_error_twolevel_constrained"
      )
    }
  }
  invisible(td)
}
