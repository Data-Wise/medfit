# sem_control(): the typed form of the native engine's `control` argument (0.18.0 plan S2, ADR V-5). `fit_sem()` and
# `mbco_sem()` resolve it once, at entry, with `.sem_resolve_control()`; everything downstream keeps receiving the plain
# nloptr list, so a fit made with `sem_control(nloptr = L)` is the fit made with `control = L`.

# the nloptr algorithm the listwise solver runs when the options do not name one (`.sem_optimize()`)
.sem_nloptr_algorithm <- "NLOPT_LD_SLSQP"

#' Optimizer settings for the native SEM engine
#'
#' @description
#' Builds the `control` argument of [fit_sem()] and [mbco_sem()] (and of
#' [fit_mediation()] with `engine = "native"`, through
#' `engine_args = list(control = )`). A plain list is still accepted there and
#' keeps its earlier meaning: every entry is an `nloptr` option, exactly as
#' `sem_control(nloptr = <list>)`.
#'
#' @param optimizer Character: `"auto"` (default) leaves the algorithm to the
#'   engine (SLSQP for a listwise fit, unless `nloptr` names another
#'   `algorithm`; the fixed SLSQP-plus-`nlminb` protocol for FIML). `"slsqp"`
#'   requests SLSQP explicitly; it gives the same fit as `"auto"`, and naming a
#'   different `nloptr` `algorithm` with it is an error. FIML accepts only
#'   `"auto"`.
#' @param n_starts Positive integer or `NULL` (default): the number of starts,
#'   as the `n_starts` argument of [fit_sem()]. Giving it both here and at the
#'   top level is an error unless the two agree. `NULL` uses the top-level
#'   value, or the default of the estimator (5 listwise, 3 for FIML).
#' @param nloptr Named list of options passed to `nloptr` for a listwise fit
#'   (for example `list(maxeval = 20000L)`). The empty list (default) keeps the
#'   engine's options. FIML requires the empty list.
#'
#' @return An object of class `medfit_sem_control`: a list with elements
#'   `optimizer`, `n_starts` and `nloptr`.
#'
#' @details
#' The resolved search protocol of a fit (estimator, the algorithm that ran,
#' the number of starts and the start rule) is recorded in
#' `fit@diagnostics$protocol`.
#'
#' A top-level `n_starts` that differs in value from `sem_control(n_starts = )`,
#' or `optimizer = "slsqp"` with a different `nloptr` `algorithm`, stops with
#' an error of class `medfit_error_sem_control_conflict`.
#'
#' @examples
#' ctl <- sem_control(nloptr = list(maxeval = 20000L))
#' ctl
#' fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment",
#'                mediation_demo, control = ctl)
#' fit@diagnostics$protocol
#'
#' @seealso [fit_sem()], [mbco_sem()]
#' @export
sem_control <- function(optimizer = "auto", n_starts = NULL, nloptr = list()) {
  # R would partially match `n_start = 3` to `n_starts`; a misspelled setting is an error, not a guess
  given <- names(sys.call())[-1L]
  inexact <- setdiff(given[nzchar(given)], names(formals(sys.function())))
  if (length(inexact)) {
    stop(sprintf("unknown sem_control() argument%s: %s (the arguments are optimizer, n_starts and nloptr)",
                 if (length(inexact) > 1L) "s" else "", paste0("`", inexact, "`", collapse = ", ")), call. = FALSE)
  }
  checkmate::assert_choice(optimizer, c("auto", "slsqp"), .var.name = "optimizer")
  checkmate::assert_count(n_starts, positive = TRUE, null.ok = TRUE, .var.name = "n_starts")
  checkmate::assert_list(nloptr, names = "unique", .var.name = "nloptr")
  if (optimizer == "slsqp" && !is.null(nloptr$algorithm) && !identical(nloptr$algorithm, .sem_nloptr_algorithm)) {
    stop(structure(list(
      message = sprintf("optimizer = \"slsqp\" conflicts with nloptr algorithm '%s'; give one or the other.",
                        format(nloptr$algorithm)),
      call = NULL
    ), class = c("medfit_error_sem_control_conflict", "error", "condition")))
  }
  structure(
    list(optimizer = optimizer, n_starts = if (is.null(n_starts)) NULL else as.integer(n_starts), nloptr = nloptr),
    class = "medfit_sem_control"
  )
}

#' @export
print.medfit_sem_control <- function(x, ...) {
  cat("<sem_control>\n")
  cat("  optimizer:", x$optimizer, "\n")
  cat("  n_starts: ", if (is.null(x$n_starts)) "default" else x$n_starts, "\n")
  opts <- if (length(x$nloptr)) {
    paste(names(x$nloptr), vapply(x$nloptr, function(v) paste(format(v), collapse = " "), character(1)),
          sep = " = ", collapse = ", ")
  } else {
    "engine defaults"
  }
  cat("  nloptr:   ", opts, "\n")
  invisible(x)
}

# Resolve `control` (a plain list, a `sem_control()` object, or NULL where `null_ok`) and the top-level `n_starts`
# into the plain nloptr list every internal receives, the `n_starts` the caller supplied from either source (NULL when
# neither did, so the caller applies its own default), and the search protocol recorded on the fit. `supplied` is
# decided by the caller with `missing()`/`is.null()`, never by value: a defaulted 5 is not a supplied 5.
.sem_resolve_control <- function(control, n_starts, n_starts_supplied, estimator = c("listwise", "fiml"),
                                 null_ok = FALSE) {
  estimator <- match.arg(estimator)
  top <- if (isTRUE(n_starts_supplied)) n_starts else NULL
  optimizer <- "auto"
  if (inherits(control, "medfit_sem_control")) {
    obj_n <- control$n_starts
    if (!is.null(top) && !is.null(obj_n) && !identical(as.integer(top), as.integer(obj_n))) {
      stop(structure(list(
        message = sprintf(paste0("n_starts = %s and sem_control(n_starts = %s) disagree; give n_starts in one ",
                                 "place, or the same value in both."), format(top), format(obj_n)),
        call = NULL
      ), class = c("medfit_error_sem_control_conflict", "error", "condition")))
    }
    optimizer <- control$optimizer
    n_out <- top %||% obj_n
    control <- control$nloptr
  } else {
    checkmate::assert_list(control, null.ok = null_ok, .var.name = "control")
    n_out <- top
  }
  protocol <- if (estimator == "fiml") {
    list(version = 1L, estimator = "fiml", optimizer = c(.sem_nloptr_algorithm, "nlminb"),
         n_starts = as.integer(n_out %||% 3L), start_rule = "fiml_three_fixed_per_solver")
  } else {
    list(version = 1L, estimator = "listwise", optimizer = control$algorithm %||% .sem_nloptr_algorithm,
         n_starts = as.integer(n_out %||% 5L), start_rule = "model_start_then_perturbed")
  }
  list(control = control, n_starts = n_out, optimizer = optimizer, protocol = protocol)
}
