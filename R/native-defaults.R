# 0.14.0 default-change warning and opt-in for fit_sem()'s `fixed_x` and `meanstructure` (spec R-2, R-3, R-11a;
# plan T5). In 0.14.x an unset setting keeps the old value (`fixed_x = FALSE`, `meanstructure = NULL`) and warns once
# per session per argument, unless `options(medfit.native_defaults = "0.15")` opts in to the 0.15.0 values. This
# file and the option are removed in 0.16.0 (E-9).

.native_defaults_env <- new.env(parent = emptyenv())
.native_defaults_env$shown <- c(fixed_x = FALSE, meanstructure = FALSE)

# Which warnings this session has shown, a named logical; `.native_defaults_reset()` sets them (tests).
.native_defaults_state <- function() {
  .native_defaults_env$shown
}

.native_defaults_reset <- function(shown = FALSE) {
  .native_defaults_env$shown <- stats::setNames(rep_len(as.logical(shown), 2L), c("fixed_x", "meanstructure"))
  invisible(NULL)
}

# TRUE when the opt-in is on, FALSE when the option is unset; any other value is an error.
.native_defaults_opt_in <- function() {
  opt <- getOption("medfit.native_defaults")
  if (is.null(opt)) {
    return(FALSE)
  }
  if (!identical(opt, "0.15")) {
    stop("`options(medfit.native_defaults = )` takes \"0.15\" (opt in to the 0.15.0 defaults of fit_sem()'s ",
         "`fixed_x` and `meanstructure`) or NULL.", call. = FALSE)
  }
  TRUE
}

# Resolve unset `fixed_x` / `meanstructure` for the model syntax and data. Returns the values to fit with. With the
# opt-in, unset `meanstructure` becomes TRUE and unset `fixed_x` becomes `.sem_default_fixed_x()`'s explicit subset
# (R-11b, E-13), never a bare TRUE, so refits and comparisons see which variables the default fixed.
.native_defaults_resolve <- function(model, data, fixed_x, meanstructure, fx_unset, ms_unset) {
  opt_in <- .native_defaults_opt_in()
  keep <- list(fixed_x = fixed_x, meanstructure = meanstructure)
  if (!fx_unset && !ms_unset) {
    return(keep)
  }
  # Syntax the raw table cannot classify (a constraint naming a factor column before its dummies exist) is left to the
  # fit, which fails on it with the specific message.
  p <- tryCatch(.sem_parse(model)$parameters, error = function(e) NULL)
  ov_x <- if (!is.null(p)) tryCatch(.sem_roles(p)$ov_x, error = function(e) NULL)
  if (is.null(ov_x)) {
    return(keep)
  }
  if (opt_in) {
    if (ms_unset) meanstructure <- TRUE
    if (fx_unset) {
      # When factor expansion fails here the fit fails on the same data with the specific message; only fixed_x falls
      # through to the old value, and the opt-in meanstructure = TRUE is kept (QA O2).
      fixed_x <- tryCatch(.sem_default_fixed_x(p, data), error = function(e) keep$fixed_x)
    }
    return(list(fixed_x = fixed_x, meanstructure = meanstructure))
  }
  warn_fx <- fx_unset && length(ov_x) > 0L
  # A written `~1` or a product turns the mean structure on, so the 0.15.0 default changes nothing there.
  warn_ms <- ms_unset && !any(p$op == "~1") && !.sem_has_product(p)
  .warn_native_defaults_once(warn_fx, warn_ms)
  list(fixed_x = fixed_x, meanstructure = meanstructure)
}

# The 0.15.0 `fixed_x` default (R-5, R-11b, E-5, E-11): the observed exogenous columns after factor expansion and
# with products (`m:x`, factor dummies), minus those the model writes a `~~` or `~1` statement on (a statement on a
# factor touches all its dummies). A character subset, or FALSE when none is left. A variable left free because of a
# statement is named in a classed message (not a warning, so the once-per-session state is not involved), on every
# fit where it happens. An explicit `fixed_x = TRUE` does not come here and keeps its error.
.sem_default_fixed_x <- function(parameters, data) {
  expanded <- .sem_expand_factors(parameters, data, FALSE)
  p <- expanded$table
  ov_x <- .sem_roles(p)$ov_x
  named <- unique(c(p$lhs[p$op == "~~"], p$rhs[p$op == "~~"], p$lhs[p$op == "~1"]))
  dummies <- unlist(lapply(expanded$map[intersect(names(expanded$map), named)], function(m) m$dummies),
                    use.names = FALSE)
  free <- intersect(ov_x, c(named, dummies))
  # A statement on a factor's name makes the fit fail ("model variables must be numeric"), so no note for it (QA O1).
  if (length(free) && !any(names(expanded$map) %in% named)) {
    message(structure(
      class = c("medfit_message_fixed_x_lenient", "message", "condition"),
      list(message = paste0(
        "fit_sem(): the `fixed_x` default leaves ", paste(free, collapse = ", "), " free, because the model writes ",
        "a `~~` or `~1` statement on ", if (length(free) == 1L) "it" else "them",
        "; the other exogenous observed variables are fixed. Pass `fixed_x` explicitly to choose.\n"
      ), call = NULL, variables = free)
    ))
  }
  sel <- setdiff(ov_x, free)
  if (length(sel)) sel else FALSE
}

# Once per session per argument. The state is set before the warning is signaled, so a muffled warning (the articles'
# setup chunks) or a handler that errors still consumes it.
.warn_native_defaults_once <- function(fixed_x, meanstructure) {
  msgs <- c(
    fixed_x = paste0(
      "fit_sem(): `fixed_x` is unset. Its default changes from FALSE to the model's exogenous observed variables in ",
      "medfit 0.15.0 (lavaan's fixed.x = TRUE): their variances, covariances and means are fixed at the sample ",
      "values, which changes logLik, npar, AIC and BIC; structural estimates and SEs are unchanged on the measured ",
      "cases."
    ),
    meanstructure = paste0(
      "fit_sem(): `meanstructure` is unset. Its default changes from NULL (a mean structure only when the model ",
      "writes `~1`) to TRUE in medfit 0.15.0: intercepts and means become free parameters, which changes logLik, ",
      "npar, AIC and BIC; structural estimates and SEs are unchanged on the measured cases."
    )
  )
  silence <- paste0(
    " To silence this, pass the argument explicitly (the old default keeps today's results), or opt in to the 0.15.0 ",
    "defaults with options(medfit.native_defaults = \"0.15\"). Shown once per session."
  )
  for (arg in names(msgs)[c(fixed_x, meanstructure)]) {
    if (.native_defaults_env$shown[[arg]]) next
    .native_defaults_env$shown[[arg]] <- TRUE
    warning(structure(
      class = c("medfit_warning_default_change", "warning", "condition"),
      list(message = paste0(msgs[[arg]], silence), call = NULL, argument = arg)
    ))
  }
  invisible(NULL)
}
