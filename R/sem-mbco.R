# Native SEM engine: MBCO.
#
# `mbco_sem()` tests the indirect effect a*b = 0 as the minimum of two likelihood-ratio tests: refit with
# `a == 0` and with `b == 0` (each linear, one solve), take the smaller diffLL, refer it to chi-square with
# one degree of freedom. The nonlinear solve of `a*b == 0` is not used: it can land at the wrong branch
# (plan S0(c): OpenMx's lands at a1 = 0 with diffLL 221.05, the true constrained optimum is b1 = 0 at 0.083).

#' Minimum-of-Two Likelihood-Ratio Test for an Indirect Effect (MBCO)
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Tests the null hypothesis that the indirect effect \eqn{a b}{a*b} is zero
#' in a model fitted by [fit_sem()]. The model is refitted twice, with
#' \eqn{a = 0}{a = 0} and with \eqn{b = 0}{b = 0}; each is a linear equality
#' constraint, so each refit is a single solve. The statistic is the smaller of
#' the two likelihood-ratio statistics, referred to a chi-square distribution
#' with one degree of freedom (the minimum-of-two LRTs; see the Methods and
#' Formulas article). The nonlinear constraint \eqn{a b = 0}{a*b = 0} is never
#' solved, because a nonlinear solver can stop at the branch with the larger
#' statistic.
#'
#' @param fit A [SEMFit] from [fit_sem()], fitted without sampling weights.
#' @param a,b Character strings: the labels of the two free parameters whose
#'   product is the indirect effect (for example `"a"` and `"b"` in
#'   `"M ~ a*X"` and `"Y ~ b*M"`). They must be different.
#' @param n_starts,control Passed to the optimizer for the two refits, as in
#'   [fit_sem()].
#'
#' @return An object of class `c("mbco_sem", "htest")`: `statistic` (the
#'   smaller diffLL), `parameter` (`df = 1`), `p.value`, `method`,
#'   `data.name`, `n_obs`, and `tests`, a data frame with one row per refit
#'   (`constraint`, the minimized discrepancy `f`, `diff_ll` equal to
#'   `n_obs * (f - fit@f)`, and `converged`). It prints with the standard
#'   `htest` layout.
#'
#' @details
#' A fit made with `sampling_weights` is refused: the weighted discrepancy is
#' not a likelihood, so its difference is not chi-square. A refit that fails
#' the acceptance gate of the optimizer is an error rather than a statistic.
#'
#' @examples
#' \donttest{
#' fit <- fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment",
#'   data = mediation_demo
#' )
#' mbco_sem(fit, "a", "b")
#' }
#'
#' @seealso [fit_sem()], [SEMFit]
#' @export
mbco_sem <- function(fit, a, b, n_starts = NULL, control = list()) {
  if (!S7::S7_inherits(fit, SEMFit)) {
    stop("`fit` must be a SEMFit from fit_sem().", call. = FALSE)
  }
  checkmate::assert_string(a, min.chars = 1L, .var.name = "a")
  checkmate::assert_string(b, min.chars = 1L, .var.name = "b")
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  checkmate::assert_list(control, .var.name = "control")
  for (nm in c(a, b)) {
    if (!(nm %in% names(fit@theta))) {
      stop(sprintf("'%s' is not a free parameter label of the fit (free labels: %s)", nm,
                   paste(names(fit@theta), collapse = ", ")), call. = FALSE)
    }
  }
  if (identical(a, b)) {
    stop("`a` and `b` must be different parameters.", call. = FALSE)
  }
  if (!is.null(fit@internals$weights)) {
    stop("MBCO is not available for a fit with sampling weights: the weighted discrepancy is not a ",
         "likelihood, so its difference is not chi-square.", call. = FALSE)
  }
  constraints <- c(paste(a, "== 0"), paste(b, "== 0"))
  refit <- lapply(constraints, function(con) {
    # `fit@data` holds the rows the fit used, already free of missing values: no second deletion.
    r <- .sem_fit_syntax(paste0(fit@model, "\n", con), fit@data, fit@information,
                         n_starts = if (is.null(n_starts)) 5L else n_starts, control = control)
    if (!isTRUE(r$converged)) {
      stop(sprintf("the refit with `%s` did not converge, so the MBCO statistic is not available.", con),
           call. = FALSE)
    }
    r
  })
  f <- vapply(refit, function(r) r$f, numeric(1))
  n <- fit@n_obs
  diff_ll <- n * (f - fit@f)
  stat <- min(diff_ll)
  structure(
    list(
      statistic = c(MBCO = stat),
      parameter = c(df = 1),
      p.value = stats::pchisq(stat, df = 1, lower.tail = FALSE),
      method = "Minimum-of-two likelihood-ratio tests (MBCO) for an indirect effect",
      data.name = sprintf("%s * %s = 0", a, b),
      n_obs = n,
      tests = data.frame(constraint = constraints, f = f, diff_ll = diff_ll, converged = TRUE,
                         stringsAsFactors = FALSE)
    ),
    class = c("mbco_sem", "htest")
  )
}
