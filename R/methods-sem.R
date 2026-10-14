# Methods for SEMFit: coef, vcov, nobs, logLik, print and summary.
#
# `logLik()` is the multivariate normal log likelihood at the estimates with the
# means free (saturated), the quantity lavaan reports for a fixed.x = FALSE model.
# Everything here reads the fitted object; nothing refits.

#' Methods for SEMFit objects
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Accessors and display for a [SEMFit] returned by [fit_sem()].
#'
#' @param object,x A [SEMFit] object
#' @param ... Additional arguments (ignored)
#'
#' @details
#' * `coef()` returns the free-parameter estimates, named as lavaan names its
#'   coefficients: the label when the row has one, else `lhs op rhs` without
#'   spaces (`"M~X"`, `"X~~X"`, `"eta=~m2"`). `vcov()`, `tidy()` and the
#'   accessors `extract_mediation()` reads use the same names.
#' * `vcov()` returns their covariance, projected onto the active constraints
#'   and bounds; rows for a pinned parameter are zero.
#' * `nobs()` returns the number of rows used after listwise deletion.
#' * `logLik()` returns the log likelihood with the means free; its `df`
#'   attribute counts the free parameters plus one mean per observed variable.
#' * `anova()` tests nested fits by the likelihood-ratio statistic
#'   \eqn{n (F_r - F_f)}{n * (F_r - F_f)} on the difference in model degrees
#'   of freedom: `anova(fit_full, fit_restricted)`, or several fits, each tested
#'   against the one with fewer degrees of freedom. It compares fits that were
#'   already made and never refits. The fits must use the same observed
#'   variables and rows, and neither may have sampling weights or have failed to
#'   converge. Nesting is checked by parameter-table inclusion: the restricted
#'   fit may free no parameter the other leaves out and must have more degrees
#'   of freedom. That is necessary for nesting, not sufficient; whether two
#'   models are nested in substance is the analyst's responsibility. A
#'   restricted fit with a smaller discrepancy than the model it restricts is an
#'   error (one fit is not at its global optimum). When a bound or an
#'   inequality on a tested parameter is active at the restricted fit, the null
#'   lies on the boundary of the parameter space, the statistic is a mixture of
#'   chi-squares, and the function warns that the p-value is not valid, as
#'   [mbco_sem()] does. Returns an object of class `"anova"` with columns `Df`,
#'   `Chisq` (n times the discrepancy), `Chisq diff`, `Df diff` and
#'   `Pr(>Chisq)`. Name rows by naming the arguments after the first.
#' * `confint()` returns Wald (normal) intervals for the free parameters and
#'   the defined parameters, `confint(fit, parm, level = 0.95)`; `parm` takes
#'   names or positions. A parameter pinned by a constraint or sitting on a
#'   bound has a zero standard error and a point interval.
#' * `tidy()` returns one row per free parameter, then per defined parameter:
#'   `term` (the name `coef()` uses), `op` (the operator of its row in the
#'   parameter table, `:=` for a defined parameter), `estimate`, `std_error`,
#'   `statistic` (the z value, `NA` when the standard error is zero),
#'   `p_value` (two-sided), and with `conf_int = TRUE` the interval
#'   `confint()` returns (`conf_low`, `conf_high`, at `conf_level`). `type`
#'   is `"all"` (default), `"parameters"` or `"defined"`.
#' * `glance()` returns one row: `nobs`, `npar` (free parameters after the
#'   equality constraints), `df`, `chisq` (n times the minimized discrepancy,
#'   the test of the model against the saturated one), `p_value` (`NA` when
#'   `df` is 0), `logLik`, `AIC` and `BIC` (with the means free, as `logLik()`
#'   defines them). A fit with sampling weights has no likelihood, so its
#'   `chisq`, `p_value`, `logLik`, `AIC` and `BIC` are `NA`. There is no
#'   `converged` column: `fit_sem()` returns a fit only for a solution that
#'   passed the acceptance gate and errors otherwise, so `@converged` is `TRUE`
#'   for every `SEMFit` and would carry no information.
#' * `summary()` collects the estimates, standard errors and z statistics, the
#'   defined parameters, and the diagnostics: rows dropped, information type,
#'   degrees of freedom, retries, stationarity, active bounds and constraints,
#'   improper-solution flags and the multiplier sign check.
#'
#' @return `coef()` a named numeric vector; `vcov()` a matrix; `nobs()` an
#'   integer; `logLik()` an object of class `"logLik"`; `summary()` an object of
#'   class `"summary_SEMFit"`; `print()` invisibly returns its argument.
#' @examples
#' \donttest{
#' fit <- fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
#'   data = mediation_demo
#' )
#' coef(fit)
#' vcov(fit)[c("a", "b"), c("a", "b")]
#' nobs(fit)
#' summary(fit)
#' generics::tidy(fit, conf_int = TRUE)
#' generics::glance(fit)
#'
#' # a likelihood-ratio test of b = 0 against the fitted model
#' fit0 <- fit_sem(paste0(fit@model, "\nb == 0"), data = mediation_demo)
#' anova(fit, fit0)
#' }
#'
#' @name SEMFit-methods
#' @seealso [fit_sem()], [SEMFit]
NULL

S7::method(coef, SEMFit) <- function(object, ...) {
  object@theta
}

S7::method(vcov, SEMFit) <- function(object, ...) {
  object@vcov
}

S7::method(nobs, SEMFit) <- function(object, ...) {
  object@n_obs
}

# -2 log L = n * (F + log|S| + p + p log(2 pi)), with S the ML covariance and F the minimized discrepancy.
# A covariance-only fit leaves the means saturated, so its parameter count adds the p means; a mean-structure
# fit already has its free intercepts in `theta`, and fixed ones are not parameters.
S7::method(logLik, SEMFit) <- function(object, ...) { # nolint: object_name_linter.
  if (!is.null(object@internals$weights)) {
    stop("logLik() is not defined for a fit with sampling weights: the weighted likelihood is a pseudo likelihood",
         call. = FALSE)
  }
  ram <- object@internals$ram
  smp <- .sem_sample(object@data, ram)
  ll <- -0.5 * smp$n * (object@f + smp$logdet + smp$p + smp$p * log(2 * pi))
  structure(ll, df = .sem_loglik_df(object, smp$p), nobs = smp$n, class = "logLik")
}

# Parameter count behind AIC and BIC (see logLik above).
.sem_loglik_df <- function(object, p) {
  .sem_n_free(object) + p * !isTRUE(object@internals$ram$has_mean)
}

# Effective number of free parameters: the parameter vector minus what the explicit equalities remove.
# A fit stored before that rank was recorded counts every element of `theta`.
.sem_n_free <- function(object) {
  length(object@theta) - (object@internals$eq_rank %||% 0L)
}

# Row names for the parameter table: the label when there is one, otherwise `lhs op rhs`.
.sem_row_names <- function(tab) {
  ifelse(!is.na(tab$label) & nzchar(tab$label), tab$label, trimws(paste(tab$lhs, tab$op, tab$rhs)))
}

S7::method(print, SEMFit) <- function(x, ...) {
  cat("SEMFit (native maximum likelihood)\n")
  cat("==================================\n\n")
  cat(sprintf("  Observations:  %d", x@n_obs))
  if (x@n_dropped > 0L) cat(sprintf(" (%d dropped for missing values)", x@n_dropped))
  cat("\n")
  cat(sprintf("  Parameters:    %d free, %s df\n", .sem_n_free(x), format(x@df)))
  cat(sprintf("  Information:   %s\n", x@information))
  if (!is.null(x@diagnostics$se_type)) {
    se_label <- if (x@diagnostics$se_type == "sandwich") "sandwich (robust)" else "model-based"
    cat(sprintf("  Std. errors:   %s%s\n", se_label, if (!is.null(x@internals$weights)) ", sampling weights" else ""))
  }
  cat(sprintf("  Converged:     %s\n", ifelse(x@converged, "Yes", "No")))
  act <- c(x@diagnostics$active_bounds, x@diagnostics$active_constraints)
  if (length(act)) cat(sprintf("  Active:        %s\n", paste(act, collapse = ", ")))
  if (length(x@diagnostics$improper)) {
    cat(sprintf("  Improper:      %s\n", paste(x@diagnostics$improper, collapse = "; ")))
  }
  if (nrow(x@defined)) {
    cat("\nDefined parameters:\n")
    for (i in seq_len(nrow(x@defined))) {
      cat(sprintf("  %-12s %9.4f  (SE %.4f)\n", x@defined$name[i], x@defined$est[i], x@defined$se[i]))
    }
  }
  cat("\nUse summary() for the parameter table and diagnostics.\n")
  invisible(x)
}

S7::method(summary, SEMFit) <- function(object, ...) {
  tab <- object@table[object@table$free, , drop = FALSE]
  coefs <- data.frame(
    name = .sem_row_names(tab), est = tab$est, se = tab$se, z = tab$est / tab$se,
    stringsAsFactors = FALSE
  )
  coefs$p <- 2 * stats::pnorm(-abs(coefs$z))
  structure(
    list(
      coefficients = coefs, defined = object@defined, n_obs = object@n_obs, n_dropped = object@n_dropped,
      df = object@df, information = object@information, converged = object@converged, f = object@f,
      diagnostics = object@diagnostics
    ),
    class = "summary_SEMFit"
  )
}

#' Print Summary for SEMFit
#'
#' @param x A summary_SEMFit object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x`. Called for its side effect of printing the
#'   formatted summary to the console.
#' @noRd
print_summary_semfit <- function(x, ...) {
  cat("Summary of SEMFit\n")
  cat("=================\n\n")
  cat(sprintf("Observations: %d", x$n_obs))
  if (x$n_dropped > 0L) cat(sprintf(" (%d dropped for missing values, listwise deletion)", x$n_dropped))
  cat("\n")
  cat(sprintf("Degrees of freedom: %s\n", format(x$df)))
  cat(sprintf("Information: %s\n", x$information))
  if (!is.null(x$diagnostics$se_type)) {
    cat(sprintf("Standard errors: %s\n",
                if (x$diagnostics$se_type == "sandwich") "sandwich (robust)" else "model-based"))
  }
  cat(sprintf("Converged: %s\n\n", ifelse(x$converged, "Yes", "No")))
  cat("Parameters:\n")
  out <- x$coefficients
  out[c("est", "se", "z")] <- lapply(out[c("est", "se", "z")], function(v) round(v, 4))
  out$p <- format.pval(x$coefficients$p, digits = 3, eps = 1e-4)
  print(out, row.names = FALSE)
  if (nrow(x$defined)) {
    cat("\nDefined parameters:\n")
    d <- x$defined[c("name", "expr", "est", "se")]
    d[c("est", "se")] <- lapply(d[c("est", "se")], function(v) round(v, 4))
    print(d, row.names = FALSE)
  }
  dg <- x$diagnostics
  none <- function(v, empty) if (length(v)) paste(v, collapse = ", ") else empty
  cat("\nDiagnostics:\n")
  cat(sprintf("  Optimizer status: %s; stationarity %.2e; retries %d\n", format(dg$status), dg$decrement,
              dg$retries))
  cat(sprintf("  Active bounds: %s\n", none(dg$active_bounds, "none")))
  cat(sprintf("  Active constraints: %s\n", none(dg$active_constraints, "none")))
  cat(sprintf("  Improper solution: %s\n", none(dg$improper, "no")))
  cat(sprintf("  Multiplier sign check: %s\n", dg$sign_check))
  invisible(x)
}


# Wald (normal) interval and test for estimates with standard errors; a zero or non-finite SE (a parameter pinned by
# a constraint or sitting on a bound) gives a point interval and no test, never an infinite z.
.sem_wald <- function(est, se, level) {
  a <- (1 - level) / 2
  z <- ifelse(is.finite(se) & se > 0, est / se, NA_real_)
  q <- stats::qnorm(1 - a)
  list(z = z, p = 2 * stats::pnorm(-abs(z)), low = est - q * se, high = est + q * se, probs = c(a, 1 - a))
}

# Estimates and standard errors of the free parameters, then the defined parameters, in one named list.
.sem_est_se <- function(object) {
  def <- object@defined
  list(
    est = c(object@theta, stats::setNames(def$est, def$name)),
    se = c(sqrt(diag(object@vcov)), stats::setNames(def$se, def$name)),
    defined = c(rep(FALSE, length(object@theta)), rep(TRUE, nrow(def)))
  )
}

S7::method(confint, SEMFit) <- function(object, parm = NULL, level = 0.95, ...) {
  checkmate::assert_number(level, lower = 0, upper = 1, .var.name = "level")
  v <- .sem_est_se(object)
  pick <- names(v$est)
  if (!is.null(parm)) {
    avail <- "Free parameters and defined parameters are available (see names(coef(fit)) and fit@defined$name)."
    if (is.numeric(parm)) {
      bad <- parm[!(parm %in% seq_along(v$est))]
      if (length(bad)) {
        stop("`parm` positions out of range: ", paste(bad, collapse = ", "), ". There are ", length(v$est),
             " parameters. ", avail, call. = FALSE)
      }
      pick <- names(v$est)[parm]
    } else {
      pick <- parm
      unknown <- setdiff(pick, names(v$est))
      if (length(unknown)) {
        stop("unknown parameter in `parm`: ", paste(unknown, collapse = ", "), ". ", avail, call. = FALSE)
      }
    }
  }
  w <- .sem_wald(v$est[pick], v$se[pick], level)
  out <- cbind(w$low, w$high)
  dimnames(out) <- list(pick, paste(format(100 * w$probs, trim = TRUE, scientific = FALSE, digits = 3), "%"))
  out
}

# The operator of the parameter-table row behind each element of `theta`: through `par_map` when the engine
# recorded it, else by matching the name to a row's label or to "lhs op rhs" (a hand-built object).
.sem_theta_op <- function(x) {
  tab <- x@table
  pm <- x@internals$par_map
  if (!is.null(pm)) {
    return(tab$op[match(seq_along(x@theta), pm)])
  }
  key <- ifelse(nzchar(tab$label) & !is.na(tab$label), tab$label, paste0(tab$lhs, tab$op, tab$rhs))
  tab$op[match(names(x@theta), key)]
}

# One row per free parameter, then per defined parameter: estimate, standard error, z statistic and its two-sided
# p-value, and with `conf_int` the Wald interval, the same numbers `confint()` returns. `term` is the name `coef()`
# uses; `op` is the operator of the parameter's row in the parameter table (`:=` for a defined parameter).
.tidy_semfit <- function(x, type = c("all", "parameters", "defined"), conf_int = FALSE, conf_level = 0.95, ...) {
  type <- match.arg(type)
  checkmate::assert_flag(conf_int, .var.name = "conf_int")
  checkmate::assert_number(conf_level, lower = 0, upper = 1, .var.name = "conf_level")
  v <- .sem_est_se(x)
  op <- c(.sem_theta_op(x), rep(":=", nrow(x@defined)))
  keep <- switch(type, all = rep(TRUE, length(v$est)), parameters = !v$defined, defined = v$defined)
  w <- .sem_wald(v$est, v$se, conf_level)
  out <- data.frame(
    term = names(v$est), op = op, estimate = unname(v$est), std_error = unname(v$se), statistic = w$z,
    p_value = w$p, stringsAsFactors = FALSE
  )
  if (conf_int) {
    out$conf_low <- w$low
    out$conf_high <- w$high
  }
  out <- out[keep, , drop = FALSE]
  rownames(out) <- NULL
  if (requireNamespace("tibble", quietly = TRUE)) {
    out <- tibble::as_tibble(out)
  }
  out
}

# One row: the sample size, the effective number of free parameters, the chi-square test of the model against the
# saturated one (n times the discrepancy, its df and p-value) and the likelihood-based criteria. There is no
# `converged` column: a SEMFit exists only for a solution that passed the acceptance gate (otherwise fit_sem()
# errors), so `@converged` is TRUE for every fit and would carry no information. A fit with sampling weights has
# a weighted discrepancy that is not a likelihood, so its chi-square, p-value, log likelihood, AIC and BIC are NA.
.glance_semfit <- function(x, ...) {
  weighted <- !is.null(x@internals$weights)
  chisq <- if (weighted) NA_real_ else x@n_obs * x@f
  if (!weighted && chisq < 0 && chisq > -1e-8) chisq <- 0 # a saturated fit's roundoff
  ll <- if (weighted) NULL else stats::logLik(x)
  out <- data.frame(
    nobs = x@n_obs, npar = .sem_n_free(x), df = x@df, chisq = chisq,
    p_value = if (!weighted && x@df > 0) stats::pchisq(chisq, df = x@df, lower.tail = FALSE) else NA_real_,
    logLik = if (weighted) NA_real_ else as.numeric(ll),
    AIC = if (weighted) NA_real_ else stats::AIC(ll), BIC = if (weighted) NA_real_ else stats::BIC(ll),
    stringsAsFactors = FALSE
  )
  if (requireNamespace("tibble", quietly = TRUE)) {
    out <- tibble::as_tibble(out)
  }
  out
}
