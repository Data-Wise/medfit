# Methods for SEMFit: coef, vcov, nobs, logLik, print and summary.
#
# `logLik()` is the multivariate normal log likelihood at the estimates with the
# means free (saturated), the quantity lavaan reports for a fixed.x = FALSE model.
# Everything here reads the fitted object; nothing refits.

#' Methods for SEMFit objects
#'
#' @description
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
#'   attribute counts the free parameters plus one mean per observed variable
#'   that is not fixed. With `fixed_x` it is conditional on the fixed variables
#'   (lavaan's value), so `AIC()` and `BIC()` of fits with different fixed sets
#'   or data stop instead of ranking them; the same holds for `anova()` and
#'   [mbco_sem()]. A `fixed_x` fit also lists its fixed moments after the free
#'   parameters in `tidy()` (`fixed_x` column `TRUE`, no standard error) and in
#'   `summary()`; `coef()` and `vcov()` leave them out. `print()` and `summary()`
#'   say what the log likelihood is conditional on.
#' * **Model test with a product term.** The global chi-square is not valid when
#'   a factor of a product term (`x:m`) is itself a regression target, because
#'   the model then treats the product as exogenous although it is a function of
#'   `m`; nor when the variances and covariances of the exogenous variables
#'   (every product included) are restricted (fixed, labeled, bounded, or left
#'   out because a `~~` statement names one of them; a `fixed_x` moment is not a
#'   restriction). `fit_sem()` then warns once, `glance()` reports `chisq`, `df`
#'   and `p_value` as `NA` (with the reason in `attr(, "note")`), `summary()`
#'   prints the reason, and `anova()` and [mbco_sem()] stop naming the product.
#'   The coefficients equal equation-wise least squares and the sandwich
#'   standard errors are unaffected, but only with observed information:
#'   `fit_sem(information = "expected")` stops for a product with an endogenous
#'   factor, because its standard errors (the sandwich built on them included)
#'   are wrong there. `fit_sem()` also warns once for any product term fitted
#'   without `se_type = "sandwich"`. `logLik()`, `AIC()` and `BIC()` stay
#'   defined, but the values of a fit with a product are not comparable with
#'   those of a fit without one (the product column enters the likelihood), so
#'   `AIC(fit_a, fit_b)`, `BIC()`, `anova()` and [mbco_sem()] refuse such a
#'   pair.
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
#'   [mbco_sem()] does. The p-value is still returned; the logical attribute
#'   `attr(x, "p_valid")` (named by row, `NA` for the first) is `FALSE` for each
#'   such row, so code can read the verdict without parsing the warning. It
#'   belongs to the object `anova()` returns: subsetting it with `[` or binding
#'   rows drops the attribute. Returns
#'   an object of class `"anova"` with columns `Df`,
#'   `Chisq` (n times the discrepancy), `Chisq diff`, `Df diff` and
#'   `Pr(>Chisq)`. Name rows by naming the arguments after the first.
#' * `confint()` returns Wald (normal) intervals for the free parameters and
#'   the defined parameters, `confint(fit, parm, level = 0.95)`; `parm` takes
#'   names or positions. A parameter pinned by a constraint or sitting on a
#'   bound has a zero standard error and a point interval.
#' * `tidy()` returns one row per free parameter, then the moments `fixed_x` fixed (a `fixed_x`
#'   column, only when something is fixed), then per defined parameter:
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
#'   defines them) and `fixed_x`, the names the fit holds at their sample moments,
#'   comma-joined (`""` when none). A fit with sampling weights has no likelihood, so its
#'   `chisq`, `p_value`, `logLik`, `AIC` and `BIC` are `NA`. There is no
#'   `converged` column: `fit_sem()` returns a fit only for a solution that
#'   passed the acceptance gate and errors otherwise, so `@converged` is `TRUE`
#'   for every `SEMFit` and would carry no information.
#' * `summary()` collects the estimates, standard errors and z statistics, the
#'   defined parameters, and the diagnostics: rows dropped, information type,
#'   degrees of freedom, retries, stationarity, optimum status, active bounds and constraints,
#'   improper-solution flags and the multiplier sign check.
#'
#' @return `coef()` a named numeric vector; `vcov()` a matrix; `nobs()` an
#'   integer; `logLik()` an object of class `"logLik"`; `summary()` an object of
#'   class `"summary_SEMFit"`; `print()` invisibly returns its argument.
#' @examples
#' \donttest{
#' fit <- fit_sem(
#'   "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment\nab := a*b",
#'   data = mediation_demo, fixed_x = FALSE, meanstructure = NULL
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
  # With `fixed_x` the likelihood is conditional on the fixed block: drop that block's marginal normal term, which
  # is evaluated at its fixed (sample) moments and does not depend on the model (lavaan's fixed.x = TRUE value).
  fx <- object@internals$fixed_x
  if (length(fx)) {
    k <- length(fx)
    sx <- smp$s[match(fx, ram$obs), match(fx, ram$obs), drop = FALSE]
    ll <- ll + 0.5 * smp$n * (as.numeric(determinant(sx, logarithm = TRUE)$modulus) + k + k * log(2 * pi))
  }
  structure(ll, df = .sem_loglik_df(object, smp$p), nobs = smp$n, class = "logLik")
}

# Parameter count behind AIC and BIC (see logLik above). Without a mean structure the means of the variables that
# are not fixed are saturated parameters; a fixed variable's mean is fixed, so it adds none.
.sem_loglik_df <- function(object, p) {
  .sem_n_free(object) + (p - length(object@internals$fixed_x)) * !isTRUE(object@internals$ram$has_mean)
}

# Rows of a parameter table that `fixed_x` fixed; a table built without the flag column (a hand-built fit) has none.
.sem_fixed_rows <- function(tab) {
  if ("fixed_x" %in% names(tab)) tab$fixed_x %in% TRUE else rep(FALSE, nrow(tab))
}

# One line for print() and summary(): what the likelihood is conditional on, or NULL when nothing is fixed.
.sem_fixed_x_note <- function(fixed_x) {
  if (length(fixed_x)) paste0("logLik is conditional on: ", paste(fixed_x, collapse = ", ")) else NULL
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
  reason <- .sem_modeltest_reason(x)
  if (!is.null(reason)) cat(sprintf("  Note:          %s\n", .sem_modeltest_note(reason)))
  note <- .sem_fixed_x_note(x@internals$fixed_x)
  if (!is.null(note)) cat(sprintf("  %s\n", note))
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
  fx <- .sem_fixed_rows(object@table)
  tab <- object@table[object@table$free | fx, , drop = FALSE]
  coefs <- data.frame(
    name = .sem_row_names(tab), est = tab$est, se = tab$se, z = tab$est / tab$se,
    stringsAsFactors = FALSE
  )
  coefs$p <- 2 * stats::pnorm(-abs(coefs$z))
  if (any(fx)) coefs$fixed_x <- tab$fixed_x %in% TRUE
  reason <- .sem_modeltest_reason(object)
  structure(
    list(
      fixed_x = object@internals$fixed_x, coefficients = coefs, defined = object@defined, n_obs = object@n_obs,
      n_dropped = object@n_dropped, model_test_note = if (!is.null(reason)) .sem_modeltest_note(reason),
      df = if (is.null(reason)) object@df else NA_real_, information = object@information,
      converged = object@converged, f = object@f,
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
  if (!is.null(x$model_test_note)) cat("Note: ", x$model_test_note, "\n", sep = "")
  cat(sprintf("Information: %s\n", x$information))
  if (!is.null(x$diagnostics$se_type)) {
    cat(sprintf("Standard errors: %s\n",
                if (x$diagnostics$se_type == "sandwich") "sandwich (robust)" else "model-based"))
  }
  cat(sprintf("Converged: %s\n", ifelse(x$converged, "Yes", "No")))
  optimum <- x$diagnostics$optimum
  if (!is.null(optimum) && optimum$status %in% c("disagreed", "single")) {
    cat(sprintf("Optimum: %s (%d of %d starts accepted)\n", optimum$status,
                optimum$n_accepted, optimum$n_starts))
  }
  note <- .sem_fixed_x_note(x$fixed_x)
  if (!is.null(note)) cat(note, "\n", sep = "")
  cat("\nParameters:\n")
  out <- x$coefficients
  out[c("est", "se", "z")] <- lapply(out[c("est", "se", "z")], function(v) round(v, 4))
  out$p <- format.pval(x$coefficients$p, digits = 3, eps = 1e-4)
  out$p[is.na(x$coefficients$p)] <- ""
  print(out, row.names = FALSE, na.print = "")
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
  nm <- if (conf_int) c("conf_low", "conf_high") else character()
  out$fixed_x <- FALSE
  # Moments fixed by `fixed_x` are shown after the free parameters (estimate = the sample moment, no SE).
  fx <- x@table[.sem_fixed_rows(x@table), , drop = FALSE]
  if (nrow(fx) && type != "defined") {
    fixed_rows <- data.frame(
      term = paste0(fx$lhs, fx$op, ifelse(fx$op == "~1", "", fx$rhs)), op = fx$op, estimate = fx$est,
      std_error = NA_real_, statistic = NA_real_, p_value = NA_real_, stringsAsFactors = FALSE
    )
    for (col in nm) fixed_rows[[col]] <- NA_real_
    fixed_rows$fixed_x <- TRUE
    free_part <- out[keep & !v$defined, , drop = FALSE]
    def_part <- out[keep & v$defined, , drop = FALSE]
    out <- rbind(free_part, fixed_rows, def_part)
  } else {
    out <- out[keep, , drop = FALSE]
    out$fixed_x <- NULL
  }
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
  # a product term can make the global test invalid: chi-square, df and p-value are then NA, with a note
  note <- .sem_modeltest_reason(x)
  invalid <- !is.null(note)
  chisq <- if (weighted || invalid) NA_real_ else .sem_chisq(x)
  ll <- if (weighted) NULL else stats::logLik(x)
  out <- data.frame(
    nobs = x@n_obs, npar = .sem_n_free(x), df = if (invalid) NA_real_ else x@df, chisq = chisq,
    p_value = if (!weighted && !invalid && x@df > 0) stats::pchisq(chisq, df = x@df, lower.tail = FALSE) else NA_real_,
    logLik = if (weighted) NA_real_ else as.numeric(ll),
    AIC = if (weighted) NA_real_ else stats::AIC(ll), BIC = if (weighted) NA_real_ else stats::BIC(ll),
    fixed_x = paste(x@internals$fixed_x, collapse = ", "), stringsAsFactors = FALSE
  )
  if (requireNamespace("tibble", quietly = TRUE)) {
    out <- tibble::as_tibble(out)
  }
  if (invalid) attr(out, "note") <- .sem_modeltest_note(note)
  out
}

# The note `glance()` carries as attribute "note" and `summary()` prints when the model test is unavailable.
.sem_modeltest_note <- function(reason) {
  paste0("model test not valid with a product of an endogenous variable or a restricted exogenous block (", reason,
         ")")
}
