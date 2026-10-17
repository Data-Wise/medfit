# Native SEM engine: MBCO.
#
# `mbco_sem()` tests the indirect effect a*b = 0 as the minimum of two likelihood-ratio tests: refit with
# `a == 0` and with `b == 0` (each linear, one solve), take the smaller diffLL, refer it to chi-square with
# one degree of freedom. The nonlinear solve of `a*b == 0` is not used: it can land at the wrong branch
# (plan S0(c): OpenMx's lands at a1 = 0 with diffLL 221.05, the true constrained optimum is b1 = 0 at 0.083).
# A product of k labeled paths (a serial indirect effect a*d*b) is the same test with k refits, one per path;
# the statistic stays the smallest diffLL and the reference stays chi-square(1).

#' Minimum-of-k Likelihood-Ratio Test for an Indirect Effect (MBCO)
#'
#' @description
#' Tests the null hypothesis that an indirect effect, the product of two or more
#' labeled paths (\eqn{a b}{a*b}, or a serial \eqn{a d b}{a*d*b}), is zero in a
#' model fitted by [fit_sem()]. The product is zero exactly when one factor is,
#' so the model is refitted once per path with that path set to zero; each is a
#' linear equality constraint, so each refit is a single solve. The statistic is
#' the smallest of the likelihood-ratio statistics, referred to a chi-square
#' distribution with one degree of freedom (the minimum-of-k LRTs; see the
#' Methods and Formulas article). The nonlinear constraint \eqn{a b = 0}{a*b = 0}
#' is never solved, because a nonlinear solver can stop at the branch with the
#' larger statistic.
#'
#' @param object A [SEMFit] from [fit_sem()], fitted without `weights`.
#' @param a,b Character strings: the labels of the two free regression paths
#'   whose product is the indirect effect (for example `"a"` and `"b"` in
#'   `"M ~ a*X"` and `"Y ~ b*M"`). They must be different, and each must be a
#'   labeled `~` row of the fit; a variance, a loading, an unlabeled path and a
#'   defined parameter are refused. For a product of more than two paths pass
#'   them all as `paths`, or as a character vector in `a` with `b` missing.
#' @param paths Character vector of two or more labels: the paths whose product
#'   is the indirect effect (`c("a", "d", "b")`). `NULL`, the default, uses `a`
#'   and `b`.
#' @param n_starts,control Passed to the optimizer for the two refits, as in
#'   [fit_sem()]. `NULL`, the default, uses the settings `object` was made with,
#'   so a better optimum in the full fit than in a refit cannot inflate the
#'   statistic; an explicit value overrides them.
#' @param fit `r lifecycle::badge("deprecated")` Renamed `object`; the old name
#'   still works with a warning.
#'
#' @return An object of class `c("mbco_sem", "htest")`: `statistic` (the
#'   smallest diffLL), `parameter` (`df = 1`), `p.value`, `method`,
#'   `data.name`, `n_obs`, and `tests`, a data frame with one row per refit
#'   (`constraint`, the minimized discrepancy `f`, `diff_ll` equal to
#'   `n_obs * (f - fit@f)`, and `converged`, always `TRUE` because a refit
#'   that does not converge is an error). It prints with the standard `htest`
#'   layout.
#'
#' @details
#' A fit made with `weights` is refused: the weighted discrepancy is
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
#' Only a product of labeled paths is tested; a sum of products (several
#' parallel indirect effects together) is not. If two of the paths are tied by
#' an equality (`a == b`), their refits impose the same restriction and their
#' `diff_ll` values coincide. The test is conservative: under a null where only
#' one factor is zero its size is at most the nominal level, and with more than
#' one zero factor it is smaller still.
#'
#' @examples
#' \donttest{
#' fit <- fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment",
#'   data = mediation_demo
#' )
#' mbco_sem(fit, "a", "b")
#'
#' # a serial indirect effect, the product of three paths
#' serial <- fit_sem(
#'   paste0("mediator1 ~ a*treatment\nmediator2 ~ d*mediator1 + treatment\n",
#'          "outcome ~ b*mediator2 + treatment"),
#'   data = mediation_demo
#' )
#' mbco_sem(serial, paths = c("a", "d", "b"))
#' }
#'
#' @seealso [fit_sem()], [SEMFit]
#' @export
mbco_sem <- function(object, a, b, n_starts = NULL, control = NULL, fit = lifecycle::deprecated(),
                     paths = NULL) {
  if (lifecycle::is_present(fit)) {
    lifecycle::deprecate_warn("0.8.0", "mbco_sem(fit)", "mbco_sem(object)")
    # `mbco_sem(fit = f, "a", "b")` leaves the two names in the first slots: shift them back.
    if (!missing(object) && missing(b)) {
      b <- a
      a <- object
    }
    object <- fit
  }
  if (!S7::S7_inherits(object, SEMFit)) {
    stop("`object` must be a SEMFit from fit_sem().", call. = FALSE)
  }
  fit <- object
  .sem_check_modeltest(list(fit), "mbco_sem()")
  two_form <- is.null(paths) && !missing(b)
  if (is.null(paths)) {
    if (missing(a)) {
      stop("give the paths of the indirect effect: `a` and `b`, or `paths`.", call. = FALSE)
    }
    # `mbco_sem(fit, c("a", "d", "b"))`: a vector in `a` with `b` missing is the list of paths
    paths <- if (missing(b)) a else c(a, b)
  } else if (!missing(a) || !missing(b)) {
    stop("give either `paths` or `a` and `b`, not both.", call. = FALSE)
  }
  if (two_form) {
    checkmate::assert_string(a, min.chars = 1L, .var.name = "a")
    checkmate::assert_string(b, min.chars = 1L, .var.name = "b")
  } else {
    checkmate::assert_character(paths, min.chars = 1L, min.len = 2L, any.missing = FALSE, .var.name = "paths")
  }
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  checkmate::assert_list(control, null.ok = TRUE, .var.name = "control")
  tab <- fit@table
  known <- unique(tab$label[tab$free & tab$op == "~" & !is.na(tab$label) & nzchar(tab$label)])
  for (nm in paths) {
    if (!(nm %in% known)) {
      stop(sprintf("'%s' is not a labeled regression path of the fit (labeled regression paths: %s)", nm,
                   if (length(known)) paste(known, collapse = ", ") else "none"), call. = FALSE)
    }
  }
  if (anyDuplicated(paths)) {
    stop(if (two_form) "`a` and `b` must be different parameters." else "`paths` must be different parameters.",
         call. = FALSE)
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
  constraints <- paste(paths, "== 0")
  # a fit with `fixed_x` is refit with the same fixed set, so the refits keep the fit's likelihood
  fixed_x <- if (length(fit@internals$fixed_x)) fit@internals$fixed_x else FALSE
  refit <- lapply(paths, function(tested) {
    con <- paste(tested, "== 0")
    # `fit@data` holds the rows the fit used, already free of missing values: no second deletion.
    r <- tryCatch(
      .sem_fit_syntax(paste0(fit@model, "\n", con), fit@data, fit@information, n_starts = n_starts,
                      control = control, meanstructure = if (isTRUE(fit@internals$ram$has_mean)) TRUE,
                      fixed_x = fixed_x, factors = fit@internals$factors),
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
      method = sprintf("Minimum-of-%s likelihood-ratio tests (MBCO) for an indirect effect",
                       if (length(paths) == 2L) "two" else length(paths)),
      data.name = sprintf("%s = 0", paste(paths, collapse = " * ")),
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
  # nonlinear inequalities (`a*b > 0`): active when the row is at 0 and a tested parameter moves it
  nli <- rows$nli
  if (!is.null(nli)) {
    idx <- match(labels, refit$ram$par_names)
    idx <- idx[!is.na(idx)]
    value <- nli$value(refit$theta)
    jac <- nli$jac(refit$theta, rep(1, length(refit$theta)))
    hit <- which(value > -1e-6 & rowSums(abs(jac[, idx, drop = FALSE])) > 1e-10)
    if (length(hit)) {
      active <- c(active, sprintf("the constraint '%s'", paste(nli$text[hit], collapse = "', '")))
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
