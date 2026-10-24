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

# Resolve unset `fixed_x` / `meanstructure` for the model syntax. Returns the values to fit with. With
# the opt-in, unset `meanstructure` becomes TRUE and unset `fixed_x` becomes TRUE (all observed exogenous variables);
# until the subset default lands (T6), a model with a `~~` or `~1` statement on an exogenous variable errors instead.
.native_defaults_resolve <- function(model, fixed_x, meanstructure, fx_unset, ms_unset) {
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
      touch <- (p$op == "~~" & (p$lhs %in% ov_x | p$rhs %in% ov_x)) | (p$op == "~1" & p$lhs %in% ov_x)
      if (any(touch)) {
        stop("options(medfit.native_defaults = \"0.15\") fixes every exogenous observed variable, but the model ",
             "has a statement on one (", trimws(paste(p$lhs[touch][1L], p$op[touch][1L], p$rhs[touch][1L])),
             "); pass `fixed_x` explicitly (a subset, or FALSE).", call. = FALSE)
      }
      fixed_x <- length(ov_x) > 0L
    }
    return(list(fixed_x = fixed_x, meanstructure = meanstructure))
  }
  warn_fx <- fx_unset && length(ov_x) > 0L
  # A written `~1` or a product turns the mean structure on, so the 0.15.0 default changes nothing there.
  warn_ms <- ms_unset && !any(p$op == "~1") && !.sem_has_product(p)
  .warn_native_defaults_once(warn_fx, warn_ms)
  list(fixed_x = fixed_x, meanstructure = meanstructure)
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
