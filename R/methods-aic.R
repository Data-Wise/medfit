# AIC() and BIC() for SEMFit.
#
# A fit with `fixed_x` has a likelihood that is conditional on its fixed block, so two such values are comparable
# only when the fixed sets and the estimation data agree. Base R's `AIC()`/`BIC()` reach `logLik()` through their
# default methods and would rank incompatible likelihoods; these methods refuse instead. They dispatch on the first
# argument only (a base-R limit): `AIC(lm_fit, sem_fit)` never reaches this code.

# The fixed set of a fit, sorted: what its likelihood conditions on.
.sem_fixed_signature <- function(fit) {
  sort(fit@internals$fixed_x %||% character())
}

# Error when the fits do not share a fixed set, or (when anything is fixed) the estimation data.
.sem_check_comparable <- function(models) {
  if (length(models) < 2L) {
    return(invisible(TRUE))
  }
  sets <- lapply(models, .sem_fixed_signature)
  if (!all(vapply(sets[-1L], identical, logical(1), sets[[1L]]))) {
    desc <- vapply(sets, function(s) if (length(s)) paste(s, collapse = ", ") else "none", character(1))
    stop("the fits have different `fixed_x` sets (", paste(sprintf("%s: %s", names(models), desc), collapse = "; "),
         "): their likelihoods condition on different variables, so they cannot be compared", call. = FALSE)
  }
  if (length(sets[[1L]])) {
    tryCatch(.sem_anova_same_data(models), error = function(e) {
      stop(conditionMessage(e), " With `fixed_x` the likelihood conditions on the data's fixed block.",
           call. = FALSE)
    })
  }
  invisible(TRUE)
}

.sem_ic_table <- function(object, dots, exprs, penalty) {
  models <- c(list(object), dots)
  nm <- vapply(exprs, function(e) if (is.language(e)) paste(deparse(e), collapse = "") else NA_character_, "")
  # a call that passes the fits by value (do.call) has no expression to name them by; number them instead
  if (anyNA(nm) || anyDuplicated(nm)) nm <- paste0("model", seq_along(models))
  names(models) <- nm
  sem <- vapply(models, function(m) S7::S7_inherits(m, SEMFit), logical(1))
  if (any(vapply(models[sem], function(m) length(.sem_fixed_signature(m)) > 0L, logical(1))) && !all(sem)) {
    stop("a SEMFit with `fixed_x` has a conditional likelihood and cannot be compared with a model of another class: ",
         paste(names(models)[!sem], collapse = ", "), call. = FALSE)
  }
  .sem_check_comparable(models[sem])
  lls <- lapply(models, stats::logLik)
  df <- vapply(lls, attr, numeric(1), "df")
  val <- -2 * vapply(lls, as.numeric, numeric(1)) + penalty(lls) * df
  data.frame(df = df, ic = unname(val), row.names = names(models))
}

#' @noRd
S7::method(AIC, SEMFit) <- function(object, ..., k = 2) {
  dots <- list(...)
  if (!length(dots)) {
    return(stats::AIC(stats::logLik(object), k = k))
  }
  exprs <- c(list(substitute(object)), as.list(substitute(list(...)))[-1L])
  out <- .sem_ic_table(object, dots, exprs, function(lls) k)
  names(out)[2L] <- "AIC"
  out
}

#' @noRd
S7::method(BIC, SEMFit) <- function(object, ...) {
  dots <- list(...)
  if (!length(dots)) {
    return(stats::BIC(stats::logLik(object)))
  }
  exprs <- c(list(substitute(object)), as.list(substitute(list(...)))[-1L])
  out <- .sem_ic_table(object, dots, exprs, function(lls) log(vapply(lls, attr, numeric(1), "nobs")))
  names(out)[2L] <- "BIC"
  out
}
