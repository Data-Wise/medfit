# Native SEM engine: syntax to fit.
#
# Internal. `.sem_fit_syntax()` runs the whole pipeline for model syntax and
# raw data: parse, complete, check the scale and the degrees of freedom, drop
# incomplete rows once, fit by maximum likelihood, and compute the covariance of
# the estimates. It returns a plain list; the exported fit object arrives with
# `fit_mediation(engine = "native")` (plan N4).

.sem_fit_syntax <- function(model, data, information = c("observed", "expected"), n_starts = 5L,
                            control = list()) {
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information)
  parsed <- .sem_parse(model)
  if (any(parsed$parameters$level != 1L)) {
    stop("two-level estimation is not implemented: the model uses `level:` blocks", call. = FALSE)
  }
  if (nrow(parsed$constraints)) {
    stop(
      "model constraints (==, <, > and :=) are not supported by the native engine yet: ",
      paste(unique(parsed$constraints$op), collapse = ", "), call. = FALSE
    )
  }
  tab <- .sem_complete(parsed$parameters)
  .sem_check_scale(tab)
  conv <- .sem_to_ram(tab)
  ram <- conv$ram

  absent <- setdiff(ram$obs, names(data))
  if (length(absent)) {
    stop("variables in the model are not columns of `data`: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  x <- data[, ram$obs, drop = FALSE]
  nonnum <- ram$obs[!vapply(x, is.numeric, TRUE)]
  if (length(nonnum)) {
    stop("model variables must be numeric: ", paste(nonnum, collapse = ", "), call. = FALSE)
  }
  # Listwise deletion once, on the model's observed variables only.
  keep <- stats::complete.cases(x)
  n_dropped <- sum(!keep)
  if (n_dropped > 0L) {
    message(sprintf(
      "%d of %d rows dropped for missing values in the model variables (listwise deletion).",
      n_dropped, nrow(x)
    ))
  }
  x <- x[keep, , drop = FALSE]
  smp <- .sem_sample(x, ram)

  df <- .sem_df(ram)
  if (df < 0) {
    stop(sprintf(
      "the model has more free parameters (%d) than observed moments (%d): df = %d",
      ram$q, length(ram$obs) * (length(ram$obs) + 1L) / 2, df
    ), call. = FALSE)
  }

  start <- .sem_default_start(ram, smp)
  given <- !is.na(conv$start)
  start[given] <- conv$start[given]
  lb <- ifelse(is.na(conv$lower), -Inf, conv$lower)
  ub <- ifelse(is.na(conv$upper), Inf, conv$upper)
  fit <- .sem_optimize(ram, smp, start, lb, ub, n_starts = n_starts, control = control)
  vc <- .sem_vcov(fit$theta, ram, smp, information)
  dimnames(vc) <- list(ram$par_names, ram$par_names)

  c(
    fit,
    list(
      vcov = vc, information = information, ram = ram, table = tab, par_map = conv$par_map,
      partable = .sem_to_partable(tab), data = x, n_obs = smp$n, n_dropped = n_dropped, df = df
    )
  )
}
