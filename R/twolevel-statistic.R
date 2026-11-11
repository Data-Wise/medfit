# =============================================================================
# twolevel_statistic(): scalar bootstrap callbacks for two-level mediation (#394, slice S2, PR3)
# =============================================================================

#' Bootstrap Callback for Two-Level Mediation
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
#'
#' A refit that errors, does not converge, warns, or leaves the between level unidentified (a treatment
#' or mediator ICC below `getOption("medfit.between_icc_error", 0.01)`, for a between effect or the
#' contrast) is a failed replicate: [bootstrap_mediation()] excludes it and reports the count in a
#' warning. An inadmissible refit (a negative variance) is kept, as the point estimate keeps it. The
#' covariance checks of the point-estimate extraction are not repeated per refit (no standard errors are
#' computed). Refits skip standard errors, the model test and lavaan's post-check (`se = "none"`,
#' `test = "none"`, `check.post = FALSE`), which do not change the maximum likelihood estimates;
#' everything else comes from the fit's own call.
#'
#' The contrast is `NA` by constraint when `a` or `b` is equated across levels and a between effect is
#' `NA` when the between level is not identified, so asking for either raises a classed error here
#' instead of returning a distribution of `NA`.
#'
#' @param x A [TwoLevelMediationData] object, or a two-level `lavaan` fit.
#' @param effect One of `"nie_within"` (default), `"nie_between"`, `"nie_contrast"` (within minus
#'   between, descriptive), `"nde_within"`, `"nde_between"`, `"te_within"`, `"te_between"`,
#'   `"pm_within"`, `"pm_between"`, or a path row: `"a_within"`, `"b_within"`, `"c_prime_within"`,
#'   `"a_between"`, `"b_between"`, `"c_prime_between"`. The proportion mediated is `NA` where the
#'   total effect is zero.
#' @param treatment,mediator,outcome Character scalars: variable names. Required for a `lavaan` fit;
#'   taken from the object for a [TwoLevelMediationData].
#'
#' @return A function of one argument returning a number: a named parameter vector for a
#'   [TwoLevelMediationData], a data frame for a `lavaan` fit.
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
#' @seealso [bootstrap_mediation()], [TwoLevelMediationData]
#' @export
twolevel_statistic <- function(x,
                               effect = c("nie_within", "nie_between", "nie_contrast",
                                          "nde_within", "nde_between", "te_within", "te_between",
                                          "pm_within", "pm_between",
                                          "a_within", "b_within", "c_prime_within",
                                          "a_between", "b_between", "c_prime_between"),
                               treatment = NULL, mediator = NULL, outcome = NULL) {
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
    return(.twolevel_stat_refit(x, effect, treatment, mediator, outcome, rlang::caller_env()))
  }
  stop("x must be a TwoLevelMediationData object or a two-level lavaan fit", call. = FALSE)
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
      paste0("The contrast NIE_within - NIE_between is NA: a or b is equated across levels, so the two ",
             "levels are not compared freely."),
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
.twolevel_stat_refit <- function(fit, effect, treatment, mediator, outcome, env) {
  force(effect)
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
  needs_between <- grepl("between|contrast", effect)
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
      if (icc[[treatment]] < icc_floor || icc[[mediator]] < icc_floor) return(NA_real_)
    }
    value <- .twolevel_stat_value(effect, p)
    if (is.finite(value)) value else NA_real_
  }
}
