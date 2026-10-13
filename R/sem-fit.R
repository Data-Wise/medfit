# Native SEM engine: syntax to fit.
#
# Internal. `.sem_fit_syntax()` runs the whole pipeline for model syntax and
# raw data: parse, complete, check the scale and the degrees of freedom, drop
# incomplete rows once, fit by maximum likelihood, and compute the covariance of
# the estimates. It returns a plain list; the exported fit object arrives with
# `fit_mediation(engine = "native")` (plan N4).

.sem_fit_syntax <- function(model, data, information = c("observed", "expected"), n_starts = 5L,
                            control = list(), weights = NULL, se_type = c("model", "sandwich"), parsed = NULL,
                            meanstructure = NULL) {
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information)
  se_type <- match.arg(se_type)
  if (!is.null(weights)) {
    weights <- .sem_check_weights(weights, nrow(data))
  }
  if (is.null(parsed)) {
    parsed <- .sem_parse(model)
    products <- .sem_zero_product_rows(parsed$constraints)
    if (length(products)) {
      return(.sem_fit_branches(parsed, products, data, information, n_starts, control, weights, se_type,
                               meanstructure))
    }
  }
  if (any(parsed$parameters$level != 1L)) {
    stop("two-level estimation is not implemented: the model uses `level:` blocks", call. = FALSE)
  }
  tab <- .sem_complete(parsed$parameters, meanstructure)
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

  # The constraint rows come first: an equality removes a free parameter (by its rank, since a dependent
  # row removes none), so the df and the guard below count q - rank, not q.
  cons <- .sem_constraint_rows(parsed$constraints, ram)
  u0 <- .sem_step_floor(ram, smp)
  start <- .sem_default_start(ram, smp)
  eq_rank <- if (is.null(cons$nl)) .sem_eq_rank(cons$eq) else .sem_eq_rank_at(cons, start, u0)
  df <- .sem_df(ram, eq_rank)
  if (df < 0) {
    stop(sprintf(
      "the model has more free parameters (%d) than observed moments (%d): df = %d",
      ram$q - eq_rank, .sem_moments(ram), df
    ), call. = FALSE)
  }

  given <- !is.na(conv$start)
  start[given] <- conv$start[given]
  lb <- ifelse(is.na(conv$lower), -Inf, conv$lower)
  ub <- ifelse(is.na(conv$upper), Inf, conv$upper)
  fit <- .sem_optimize(ram, smp, start, lb, ub, n_starts = n_starts, control = control, constraints = cons)
  if (!is.null(cons$nl)) {
    # a nonlinear equality removes parameters where its gradient is: count them at the solution
    eq_rank <- .sem_eq_rank_at(cons, fit$theta, u0)
    df <- .sem_df(ram, eq_rank)
  }
  vc <- .sem_vcov(fit$theta, ram, smp, information, cons, lb, ub, se_type)
  defined <- .sem_defined(parsed$constraints, fit$theta, vc)
  act_cons <- if (is.null(cons)) .sem_no_cons(ram$q) else cons
  act <- .sem_active_set(fit$theta, ram, smp, lb, ub, act_cons)

  c(
    fit,
    list(
      vcov = vc, defined = defined, constraints = parsed$constraints,
      active_constraints = act$text[act$active_row], information = information, ram = ram, table = conv$table,
      par_map = conv$par_map, se_type = se_type, weights = smp$w, n_starts = n_starts, control = control,
      partable = .sem_to_partable(conv$table), data = x, n_obs = smp$n, n_dropped = n_dropped, df = df,
      eq_rank = eq_rank, branch = character()
    )
  )
}

# A model with zero-product constraints (`a*b == 0`, `b1*b2*b3 == 0`): one fit per way of setting a factor of
# each product to zero, every branch a linear model fitted from the default start (never from another
# branch's or the full model's estimates, so a branch cannot inherit an infeasible point), and the branch
# with the smallest discrepancy wins. A branch that fails the acceptance gate is skipped; when none succeeds
# the error lists each. Messages and warnings of the losing branches are dropped, those of the winner are
# passed on. The returned fit keeps the user's constraints; `branch` names the lines the winner used.
.sem_fit_branches <- function(parsed, products, data, information, n_starts, control, weights, se_type,
                              meanstructure = NULL) {
  grid <- do.call(expand.grid, c(lapply(products, `[[`, "factors"), stringsAsFactors = FALSE))
  if (nrow(grid) > 64L) {
    stop(sprintf("the zero-product constraints give %d branches to fit; at most 64 are supported", nrow(grid)),
         call. = FALSE)
  }
  fits <- vector("list", nrow(grid))
  fail <- character(nrow(grid))
  for (b in seq_len(nrow(grid))) {
    cons <- parsed$constraints
    lines <- character()
    for (j in seq_along(products)) {
      i <- products[[j]]$row
      lines <- c(lines, paste(grid[b, j], "== 0"))
      cons$lhs[i] <- grid[b, j]
      cons$rhs[i] <- "0"
    }
    held <- list(messages = list(), warnings = list())
    res <- tryCatch(
      withCallingHandlers(
        .sem_fit_syntax(NULL, data, information, n_starts, control, weights, se_type,
                        parsed = list(parameters = parsed$parameters, constraints = cons),
                        meanstructure = meanstructure),
        message = function(m) {
          held$messages[[length(held$messages) + 1L]] <<- m
          invokeRestart("muffleMessage")
        },
        warning = function(w) {
          held$warnings[[length(held$warnings) + 1L]] <<- w
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) conditionMessage(e)
    )
    if (is.character(res)) {
      fail[b] <- sprintf("%s: %s", paste(lines, collapse = ", "), res)
    } else {
      res$branch <- lines
      fits[[b]] <- list(fit = res, held = held)
    }
  }
  ok <- which(!vapply(fits, is.null, TRUE))
  if (!length(ok)) {
    stop("no branch of the zero-product constraints converged:\n  ", paste(fail, collapse = "\n  "), call. = FALSE)
  }
  win <- ok[which.min(vapply(ok, function(b) fits[[b]]$fit$f, numeric(1)))]
  for (m in fits[[win]]$held$messages) message(conditionMessage(m))
  for (w in fits[[win]]$held$warnings) warning(conditionMessage(w), call. = FALSE)
  out <- fits[[win]]$fit
  out$constraints <- parsed$constraints
  out
}
