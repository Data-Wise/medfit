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
#' * `coef()` returns the free-parameter estimates, named as in the parameter
#'   table (the label when the row has one).
#' * `vcov()` returns their covariance, projected onto the active constraints
#'   and bounds; rows for a pinned parameter are zero.
#' * `nobs()` returns the number of rows used after listwise deletion.
#' * `logLik()` returns the log likelihood with the means free; its `df`
#'   attribute counts the free parameters plus one mean per observed variable.
#' * `summary()` collects the estimates, standard errors and z statistics, the
#'   defined parameters, and the diagnostics: rows dropped, information type,
#'   degrees of freedom, retries, stationarity, active bounds and constraints,
#'   improper-solution flags and the multiplier sign check.
#'
#' @return `coef()` a named numeric vector; `vcov()` a matrix; `nobs()` an
#'   integer; `logLik()` an object of class `"logLik"`; `summary()` an object of
#'   class `"summary.SEMFit"`; `print()` invisibly returns its argument.
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
S7::method(logLik, SEMFit) <- function(object, ...) { # nolint: object_name_linter.
  ram <- object@internals$ram
  smp <- .sem_sample(object@data, ram)
  ll <- -0.5 * smp$n * (object@f + smp$logdet + smp$p + smp$p * log(2 * pi))
  structure(ll, df = length(object@theta) + smp$p, nobs = smp$n, class = "logLik")
}

# Row names for the parameter table: the label when there is one, otherwise `lhs op rhs`.
.sem_row_names <- function(tab) {
  ifelse(!is.na(tab$label) & nzchar(tab$label), tab$label, paste(tab$lhs, tab$op, tab$rhs))
}

S7::method(print, SEMFit) <- function(x, ...) {
  cat("SEMFit (native maximum likelihood)\n")
  cat("==================================\n\n")
  cat(sprintf("  Observations:  %d", x@n_obs))
  if (x@n_dropped > 0L) cat(sprintf(" (%d dropped for missing values)", x@n_dropped))
  cat("\n")
  cat(sprintf("  Parameters:    %d free, %s df\n", length(x@theta), format(x@df)))
  cat(sprintf("  Information:   %s\n", x@information))
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
    class = "summary.SEMFit"
  )
}

#' Print Summary for SEMFit
#'
#' @param x A summary.SEMFit object
#' @param ... Additional arguments (ignored)
#' @return Invisibly returns `x`. Called for its side effect of printing the
#'   formatted summary to the console.
#' @export
print.summary.SEMFit <- function(x, ...) {
  cat("Summary of SEMFit\n")
  cat("=================\n\n")
  cat(sprintf("Observations: %d", x$n_obs))
  if (x$n_dropped > 0L) cat(sprintf(" (%d dropped for missing values, listwise deletion)", x$n_dropped))
  cat("\n")
  cat(sprintf("Degrees of freedom: %s\n", format(x$df)))
  cat(sprintf("Information: %s\n", x$information))
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
