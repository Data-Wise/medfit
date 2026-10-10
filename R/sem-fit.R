# Native SEM engine: syntax to fit.
#
# Internal. `.sem_fit_syntax()` runs the whole pipeline for model syntax and
# raw data: parse, complete, check the scale and the degrees of freedom, drop
# incomplete rows once, fit by maximum likelihood, and compute the covariance of
# the estimates. It returns a plain list; the exported fit object arrives with
# `fit_mediation(engine = "native")` (plan N4).

.sem_fit_syntax <- function(model, data, information = c("observed", "expected"), n_starts = 5L,
                            control = list(), weights = NULL, se_type = c("model", "sandwich")) {
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information)
  se_type <- match.arg(se_type)
  if (!is.null(weights)) {
    weights <- .sem_check_weights(weights, nrow(data))
  }
  parsed <- .sem_parse(model)
  if (any(parsed$parameters$level != 1L)) {
    stop("two-level estimation is not implemented: the model uses `level:` blocks", call. = FALSE)
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
  weights <- weights[keep]
  smp <- .sem_sample(x, ram, weights)

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
  cons <- .sem_constraint_rows(parsed$constraints, ram)
  fit <- .sem_optimize(ram, smp, start, lb, ub, n_starts = n_starts, control = control, constraints = cons)
  vc <- .sem_vcov(fit$theta, ram, smp, information, cons, lb, ub, se_type)
  defined <- .sem_defined(parsed$constraints, fit$theta, vc)
  act_cons <- if (is.null(cons)) .sem_no_cons(ram$q) else cons
  act <- .sem_active_set(fit$theta, ram, smp, lb, ub, act_cons)

  c(
    fit,
    list(
      vcov = vc, defined = defined, constraints = parsed$constraints,
      active_constraints = act$text[act$active_row], information = information, ram = ram, table = conv$table,
      par_map = conv$par_map, se_type = se_type, weights = smp$w,
      partable = .sem_to_partable(conv$table), data = x, n_obs = smp$n, n_dropped = n_dropped, df = df
    )
  )
}
