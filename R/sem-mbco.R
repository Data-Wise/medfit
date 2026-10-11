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
#' @param a,b Character strings: the labels of the two free regression paths
#'   whose product is the indirect effect (for example `"a"` and `"b"` in
#'   `"M ~ a*X"` and `"Y ~ b*M"`). They must be different, and each must be a
#'   labeled `~` row of the fit; a variance, a loading, an unlabeled path and a
#'   defined parameter are refused.
#' @param n_starts,control Passed to the optimizer for the two refits, as in
#'   [fit_sem()]. `NULL`, the default, uses the settings `fit` was made with,
#'   so a better optimum in the full fit than in a refit cannot inflate the
#'   statistic; an explicit value overrides them.
#'
#' @return An object of class `c("mbco_sem", "htest")`: `statistic` (the
#'   smaller diffLL), `parameter` (`df = 1`), `p.value`, `method`,
#'   `data.name`, `n_obs`, and `tests`, a data frame with one row per refit
#'   (`constraint`, the minimized discrepancy `f`, `diff_ll` equal to
#'   `n_obs * (f - fit@f)`, and `converged`, always `TRUE` because a refit
#'   that does not converge is an error). It prints with the standard `htest`
#'   layout.
#'
#' @details
#' A fit made with `sampling_weights` is refused: the weighted discrepancy is
#' not a likelihood, so its difference is not chi-square. So is a fit that did
#' not converge, since its discrepancy is the reference both refits are
#' measured against. A refit that fails the acceptance gate of the optimizer is
#' an error rather than a statistic.
#'
#' Inequality constraints in the model matter only when they put the null on
#' the boundary of the parameter space. If a bound or an inequality that
#' involves the tested parameter is active at its refit (`a > 0` with the null
#' `a = 0`), the function warns that the statistic is a mixture of chi-squares,
#' not chi-square(1), and that the p-value is not valid. A bound the null sits
#' inside (`a < 0.2`), an inactive inequality and one on another parameter are
#' not mentioned. A null the constraints rule out (`a > 0.3` with the null
#' `a = 0`) is an error that says so.
#'
#' Only a product of two labeled paths is tested. A serial indirect effect
#' (a product of three paths) or a sum of products is not. If `a` and `b` are
#' tied by an equality (`a == b`), the two refits impose the same restriction
#' and the two `diff_ll` values coincide.
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
mbco_sem <- function(fit, a, b, n_starts = NULL, control = NULL) {
  if (!S7::S7_inherits(fit, SEMFit)) {
    stop("`fit` must be a SEMFit from fit_sem().", call. = FALSE)
  }
  checkmate::assert_string(a, min.chars = 1L, .var.name = "a")
  checkmate::assert_string(b, min.chars = 1L, .var.name = "b")
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  checkmate::assert_list(control, null.ok = TRUE, .var.name = "control")
  tab <- fit@table
  paths <- unique(tab$label[tab$free & tab$op == "~" & !is.na(tab$label) & nzchar(tab$label)])
  for (nm in c(a, b)) {
    if (!(nm %in% paths)) {
      stop(sprintf("'%s' is not a labeled regression path of the fit (labeled regression paths: %s)", nm,
                   if (length(paths)) paste(paths, collapse = ", ") else "none"), call. = FALSE)
    }
  }
  if (identical(a, b)) {
    stop("`a` and `b` must be different parameters.", call. = FALSE)
  }
  if (!is.null(fit@internals$weights)) {
    stop("MBCO is not available for a fit with sampling weights: the weighted discrepancy is not a ",
         "likelihood, so its difference is not chi-square.", call. = FALSE)
  }
  if (!isTRUE(fit@converged)) {
    stop("the fit did not converge, so the MBCO statistic is not available: its discrepancy is the ",
         "reference both refits are measured against.", call. = FALSE)
  }
  # The refits use the optimizer settings of the fit, so a better optimum in the full fit than in a refit
  # cannot inflate the statistic; an explicit argument overrides them.
  n_starts <- n_starts %||% fit@internals$n_starts %||% 5L
  control <- control %||% fit@internals$control %||% list()
  constraints <- c(paste(a, "== 0"), paste(b, "== 0"))
  refit <- lapply(c(a, b), function(tested) {
    con <- paste(tested, "== 0")
    # `fit@data` holds the rows the fit used, already free of missing values: no second deletion.
    r <- tryCatch(
      .sem_fit_syntax(paste0(fit@model, "\n", con), fit@data, fit@information, n_starts = n_starts,
                      control = control),
      error = function(e) {
        stop(sprintf(paste0("the refit with `%s` failed (%s). If the model has an inequality constraint on that ",
                            "parameter, the null `%s` may lie outside the parameter space."),
                     con, conditionMessage(e), con), call. = FALSE)
      }
    )
    .mbco_warn_boundary(r, con, tested)
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

# The boundary conditions at a fit, for the tested parameter labels: a bound on one of them that is active, or an
# inequality constraint that involves one of them and is active (the parser folds `a > 0` into a bound, so it is
# not an inequality row). When the null lies there, the likelihood-ratio statistic is a mixture of chi-squares
# rather than chi-square(df). An inequality that is inactive, one on another parameter, or one that leaves the
# null in the interior (`a < 0.2` with the null at 0) changes nothing here. `refit` is the engine's fit list
# (`active_bounds`, `constraints`, `ram`, `theta`); returns one phrase per active condition, or character(0).
.sem_boundary_active <- function(refit, labels) {
  active <- character()
  bounds <- intersect(refit$active_bounds, labels)
  if (length(bounds)) {
    active <- c(active, sprintf("a bound on %s", paste(bounds, collapse = ", ")))
  }
  rows <- .sem_constraint_rows(refit$constraints, refit$ram)
  ineq <- if (is.null(rows)) NULL else rows$ineq
  if (!is.null(ineq) && nrow(ineq$A)) {
    idx <- match(labels, refit$ram$par_names)
    idx <- idx[!is.na(idx)]
    value <- as.vector(ineq$A %*% refit$theta) + ineq$b
    hit <- which(value > -1e-6 & rowSums(abs(ineq$A[, idx, drop = FALSE]) > 0) > 0)
    if (length(hit)) {
      active <- c(active, sprintf("the constraint '%s'", paste(ineq$text[hit], collapse = "', '")))
    }
  }
  active
}

# Warn when the null lies on the boundary of the parameter space at a refit.
.mbco_warn_boundary <- function(refit, con, labels) {
  active <- .sem_boundary_active(refit, labels)
  if (length(active)) {
    warning(sprintf(paste0("%s is active at the refit with `%s`: the null lies on the boundary of the parameter ",
                           "space, so the statistic is a mixture of chi-squares, not chi-square(1), and its ",
                           "p-value is not valid."),
                    paste(active, collapse = " and "), con), call. = FALSE)
  }
  invisible(NULL)
}
