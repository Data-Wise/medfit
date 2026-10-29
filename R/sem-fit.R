# Native SEM engine: syntax to fit.
#
# Internal. `.sem_fit_syntax()` runs the whole pipeline for model syntax and
# raw data: parse, complete, check the scale and the degrees of freedom, drop
# incomplete rows once, fit by maximum likelihood, and compute the covariance of
# the estimates. It returns a plain list; the exported fit object arrives with
# `fit_mediation(engine = "native")` (plan N4).

# The fit and its outcome ledger (`R/sem-outcomes.R`). The pipeline runs with its warnings and messages held; a success
# replays them after the ledger is built, a failure keeps its class and carries them in the ledger and the message.
.sem_fit_syntax <- function(model, data, information = c("observed", "expected"), n_starts = 5L,
                            control = list(), weights = NULL, se_type = c("model", "sandwich"), parsed = NULL,
                            meanstructure = NULL, fixed_x = FALSE, factors = NULL, covariance_transport = FALSE) {
  context <- .sem_outcome_context(model, parsed, data, information, weights, meanstructure, fixed_x,
                                  n_starts, control, se_type, factors)
  captured <- .sem_capture_outcome(.sem_fit_pipeline(model, data, information, n_starts, control, weights,
                                                     se_type, parsed, meanstructure, fixed_x, factors))
  out <- captured$value
  err <- captured$error
  if (inherits(err, "medfit_covariance_untyped")) {
    if (covariance_transport) stop(err)
    stop(err$original)
  }
  covariance <- !is.null(err) && inherits(err, "medfit_sem_covariance_error")
  if (!is.null(err) && !covariance) {
    constraints <- if (!is.null(parsed)) {
      parsed$constraints
    } else {
      tryCatch(.sem_parse(model)$constraints, error = function(e) data.frame())
    }
    .sem_reraise_outcome(err, context, constraints, captured$notices)
  }
  # a covariance-stage failure holds the accepted fit: its ledger is built exactly as a success's, then marked
  if (covariance) {
    out <- err$partial
  }
  context <- .sem_fit_context(context, out)
  if (is.null(out$ledger)) {
    out$ledger <- .sem_outcome(context, out$constraints, out, notices = captured$notices)
  } else {
    # a union's ledger holds the parsed parameters its certificates are checked against; the entry has none
    context$model$parameters <- out$ledger$context$model$parameters
    out$ledger$context <- context
  }
  if (covariance && is.null(out$ledger$post_fit)) {
    out$ledger$covariance <- "failed"
    out$ledger$post_fit <- err$post_fit
  }
  out$ledger <- .sem_compact_outcome(out$ledger)
  if (covariance) {
    # the notices raised before the failure are in the ledger; the error keeps the original message
    .sem_abort_covariance(out, conditionMessage(err))
  }
  .sem_require_outcome(out, model)
  .sem_replay_notices(captured$notices)
  out
}

.sem_fit_pipeline <- function(model, data, information, n_starts, control, weights, se_type, parsed,
                              meanstructure, fixed_x, factors) {
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information, c("observed", "expected"))
  se_type <- match.arg(se_type, c("model", "sandwich"))
  if (!is.null(weights)) {
    weights <- .sem_check_weights(weights, nrow(data))
  }
  if (is.null(parsed)) {
    parsed <- tryCatch(.sem_parse(model), error = function(e) {
      hint <- .sem_factor_label_hint(conditionMessage(e), data)
      stop(if (is.null(hint)) conditionMessage(e) else hint, call. = FALSE)
    })
    # factors become dummies before completion sees the table; branch fits re-enter with `parsed` and the
    # expanded data, so this runs once
    expanded <- .sem_expand_factors(parsed$parameters, data, fixed_x, factors)
    parsed$parameters <- expanded$table
    data <- expanded$data
    fixed_x <- expanded$fixed_x
    factors <- expanded$map
    products <- .sem_zero_product_rows(parsed$constraints)
    if (length(products)) {
      # one check before the branch grid, which would swallow it into "no branch converged"
      # a product's inputs are split at the colon: its rows go at materialization, like any other model variable
      sides <- unlist(strsplit(c(parsed$parameters$lhs, parsed$parameters$rhs), ":", fixed = TRUE))
      latent <- parsed$parameters$lhs[parsed$parameters$op == "=~"]
      # a latent is not a column, even when one shares its name
      vars <- setdiff(intersect(unique(sides), names(data)), latent)
      rows <- stats::complete.cases(data[, vars, drop = FALSE])
      .sem_check_dummy_support(factors, data, rows, if (!is.null(weights)) weights[rows])
      out <- .sem_fit_branches(parsed, products, data, information, n_starts, control, weights, se_type,
                               meanstructure = meanstructure, fixed_x = fixed_x, factors = factors)
      out$factors <- factors
      return(out)
    }
  }
  if (any(parsed$parameters$level != 1L)) {
    stop("two-level estimation is not implemented: the model uses `level:` blocks", call. = FALSE)
  }
  certificate <- .sem_literal_zero_certificate(parsed$parameters, parsed$constraints)
  if (!is.null(certificate)) {
    # a contradiction proved by syntax: nothing to optimize, and no fit exists (D2)
    context <- .sem_outcome_context(model, parsed, data, information, weights, meanstructure, fixed_x,
                                    n_starts, control, se_type, factors)
    .sem_abort_outcome(.sem_certificate_message(parsed$constraints, certificate),
                       .sem_excluded_outcome(context, parsed$constraints, certificate))
  }
  tab <- .sem_complete(parsed$parameters, meanstructure, fixed_x)
  .sem_check_scale(tab)
  modeltest <- .sem_product_modeltest(tab)
  .sem_product_refuse(modeltest, information)
  fixed_set <- attr(tab, "fixed_x")
  # Product columns are built before anything reads the model's columns: `.sem_assign_fixed_x()` returns early
  # when one is absent, which would leave every fixed row unassigned. NA propagates through `*`, so building
  # before listwise deletion is safe; the check of a user-supplied column waits until after it.
  mat <- .sem_materialize_products(tab, data)
  if (length(fixed_set)) {
    # the fixed values are moments of the rows the fit will use, so the rows are chosen before the RAM is built
    tab <- .sem_assign_fixed_x(tab, mat$data, weights)
  }
  data <- mat$data
  conv <- .sem_to_ram(tab)
  ram <- conv$ram
  ram$modeltest <- modeltest # NULL (no entry) unless a product invalidates the model test

  absent <- setdiff(ram$obs, names(data))
  if (length(absent)) {
    stop("variables in the model are not columns of `data`: ", paste(absent, collapse = ", "), call. = FALSE)
  }
  x <- data[, ram$obs, drop = FALSE]
  nonnum <- ram$obs[!vapply(x, is.numeric, TRUE)]
  if (length(nonnum)) {
    stop("model variables must be numeric: ", paste(nonnum, collapse = ", "),
         ". A factor, character or logical column is expanded to dummies only on a regression's right side; ",
         "as an outcome or mediator, or for any other type (a date), convert it to a numeric column", call. = FALSE)
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
  .sem_check_dummy_support(factors, data, keep, weights[keep])
  .sem_check_product_columns(mat$checks, keep)
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
  shift <- .sem_shift_ok(ram, smp, parsed$constraints, lb, ub, given)
  if (shift) {
    # Constraints that leave every intercept free act on A and S alone, which a shift of the data by its mean does
    # not change: optimize on the centered data (the intercepts are then the centered coordinates phi, free of
    # the mean/sd conditioning problem) and map the solution back, theta = T (phi + c0).
    smp_opt <- .sem_sample(as.data.frame(sweep(as.matrix(x[, ram$obs, drop = FALSE]), 2L, smp$xbar)), ram, weights)
    # a fixed exogenous mean is the sample mean, which is 0 on the centered data
    ram_opt <- ram
    ram_opt$m0[ram$fixed_x_mean] <- 0
    start <- .sem_default_start(ram_opt, smp_opt)
    start[given] <- conv$start[given]
    fit <- .sem_optimize(ram_opt, smp_opt, start, lb, ub, n_starts = n_starts, control = control, constraints = cons)
    ctr <- .sem_center_map(ram, smp)
    fit$theta <- stats::setNames(as.vector(ctr$t %*% (fit$theta + ctr$c0)), ram$par_names)
  } else {
    fit <- .sem_optimize(ram, smp, start, lb, ub, n_starts = n_starts, control = control, constraints = cons)
  }
  if (!is.null(cons$nl)) {
    # a nonlinear equality removes parameters where its gradient is: count them at the solution
    eq_rank <- .sem_eq_rank_at(cons, fit$theta, u0)
    df <- .sem_df(ram, eq_rank)
  }
  # Definition values and gradients are checked before the covariance, so an invalid definition is not hidden by a
  # covariance-stage error; the standard errors follow the covariance.
  .sem_defined(parsed$constraints, fit$theta, NULL)
  vc <- tryCatch(.sem_vcov(fit$theta, ram, smp, information, cons, lb, ub, se_type), error = function(e) e)
  act_cons <- if (is.null(cons)) .sem_no_cons(ram$q) else cons
  act <- .sem_active_set(fit$theta, ram, smp, lb, ub, act_cons)
  .sem_product_warn(tab, modeltest, se_type)

  out <- c(
    fit,
    list(
      constraints = parsed$constraints,
      active_constraints = act$text[act$active_row], information = information, ram = ram, table = conv$table,
      par_map = conv$par_map, se_type = se_type, weights = smp$w, n_starts = n_starts, control = control,
      partable = .sem_to_partable(conv$table), data = x, n_obs = smp$n, n_dropped = n_dropped, df = df,
      eq_rank = eq_rank, branch = character(), fixed_x = fixed_set, factors = factors
    )
  )
  if (inherits(vc, "error")) {
    if (!inherits(vc, "medfit_sem_covariance_diagnostic")) {
      stop(structure(class = c("medfit_covariance_untyped", "error", "condition"),
                     list(message = conditionMessage(vc), call = NULL, original = vc)))
    }
    # Only an accepted likelihood is evidence. Anything else keeps the error it was, and the caller's ledger says the
    # likelihood is unavailable.
    if (!(isTRUE(fit$converged) && length(fit$f) == 1L && is.finite(fit$f))) {
      stop(vc)
    }
    stop(.sem_covariance_error(conditionMessage(vc), out,
                               post_fit = list(schema_version = 1L, stage = "covariance",
                                               condition = .sem_condition_record(vc))))
  }
  out$vcov <- vc
  out$defined <- .sem_defined(parsed$constraints, fit$theta, vc)
  out
}

# Fit-time policy for a product term (0.10.0 plan U6, F4). `modeltest` is the verdict of `.sem_product_modeltest()`.
#  * expected information is refused when a product has an endogenous factor: the expected information assumes the
#    model's implied moments, which the product violates, so its SEs are wrong (the sandwich built on it included);
#    observed information with the sandwich is the safe route (amendment section 2a);
#  * one warning when the model test is unavailable, and one when a product is fitted without `se_type = "sandwich"`.
.sem_product_refuse <- function(modeltest, information) {
  if (length(modeltest$endogenous) && identical(information, "expected")) {
    stop("`information = \"expected\"` is not available for a model with a product of an endogenous variable (",
         paste(modeltest$endogenous, collapse = "; "), "): the expected information assumes the product is not a ",
         "function of the other variables, so its standard errors are wrong, the sandwich ones included. Use ",
         "`information = \"observed\"` (the default) with `se_type = \"sandwich\"`.", call. = FALSE)
  }
  invisible(NULL)
}

# The warnings are raised after the fit succeeds, so a call that then errors (a missing column, no convergence)
# reports only its error.
.sem_product_warn <- function(tab, modeltest, se_type) {
  prods <- unique(tab$rhs[tab$op == "~" & grepl(":", tab$rhs, fixed = TRUE)])
  if (!length(prods)) {
    return(invisible(NULL))
  }
  reasons <- .sem_modeltest_text(modeltest)
  if (!is.null(reasons)) {
    warning("the model test is not valid for this model: ", reasons,
            ". `glance()` and `summary()` report the chi-square, df and p-value as NA, and `anova()` and `mbco_sem()` ",
            "refuse. The coefficients equal equation-wise OLS, and the sandwich standard errors (observed ",
            "information) are unaffected.", call. = FALSE)
  }
  if (!identical(se_type, "sandwich")) {
    warning("the model has a product term (", paste(prods, collapse = ", "), ") and `se_type = \"", se_type,
            "\"`: model-based standard errors assume normality, which a product violates. ",
            "`se_type = \"sandwich\"` is recommended.", call. = FALSE)
  }
  invisible(NULL)
}

# Whether the fit can run on mean-centered data: a mean structure whose intercepts are all free, unbounded,
# unshared and absent from every constraint and from the user's starting values, with a centering map to
# undo (a free intercept on a variable that has a path entry). Anything else keeps the plain coordinates.
.sem_shift_ok <- function(ram, smp, constraints, lb, ub, given) {
  if (!isTRUE(ram$has_mean) || is.null(.sem_center_map(ram, smp))) {
    return(FALSE)
  }
  if (length(unique(ram$k_m)) != length(ram$k_m) || any(ram$k_m %in% which(given)) ||
        any(is.finite(c(lb[ram$k_m], ub[ram$k_m])))) {
    return(FALSE)
  }
  if (!all(ram$obs_idx %in% c(ram$pos_m, ram$fixed_x_mean)) || any(ram$k_m %in% ram$k_a)) {
    return(FALSE)
  }
  # The back-mapping carries the shift through the free paths of variables with a free intercept. A fixed nonzero
  # path, or a path into a latent variable (whose mean is fixed at 0 and cannot absorb the shift), breaks it.
  nv <- ram$nv
  row_of <- (ram$pos_a - 1L) %% nv + 1L
  if (any(ram$a0 != 0) || any(!(row_of %in% ram$obs_idx))) {
    return(FALSE)
  }
  used <- if (is.null(constraints)) character() else unlist(lapply(c(constraints$lhs, constraints$rhs), function(e) {
    tryCatch(all.vars(str2lang(e)), error = function(err) character())
  }))
  !any(ram$par_names[ram$k_m] %in% used)
}

# A model with zero-product constraints (`a*b == 0`, `b1*b2*b3 == 0`): one fit per way of setting a factor of
# each product to zero, every branch a linear model fitted from the default start (never from another
# branch's or the full model's estimates, so a branch cannot inherit an infeasible point), and the branch
# with the smallest discrepancy wins. A branch that fails the acceptance gate is skipped; when none succeeds
# the error lists each. Every branch's notices and condition are kept in its ledger node; only the winner's notices
# are passed on. The returned fit keeps the user's constraints; `branch` names the lines the winner used. A skipped
# branch while another wins leaves a minimum over the surviving branches only, which can look valid and need not
# be the constrained optimum: that is an error too (`medfit_error_no_convergence`), never a fit, and `mbco_sem()`
# and `compare_lr()` report an unresolved result for it. The error carries the ledger of every required branch as
# `$ledger` (ADR D-12). A failed branch is unknown, never certified infeasible.
.sem_fit_branches <- function(parsed, products, data, information, n_starts, control, weights, se_type,
                              meanstructure = NULL, fixed_x = FALSE, factors = NULL) {
  context <- .sem_outcome_context(NULL, parsed, data, information, weights, meanstructure, fixed_x,
                                  n_starts, control, se_type, factors)
  # the cap is on the raw count (duplicates included), checked before the grid is allocated (D3). An over-cap model is
  # refused on that count alone: no literal certificate is tried, since nothing is enumerated.
  raw_count <- .sem_raw_count(vapply(products, function(p) length(p$factors), 0L))
  if (raw_count > 64L) {
    reason <- sprintf("the zero-product constraints give %s branches to fit; at most 64 are supported",
                      .sem_raw_count_text(raw_count))
    err <- simpleError(reason)
    err$ledger <- .sem_outcome(context, parsed$constraints, error = err)
    # nothing was enumerated: the count is the requirement, not a completed enumeration
    err$ledger$enumeration <- list(state = "not_enumerated", required = raw_count)
    stop(err)
  }
  grid <- .sem_branch_grid(products)
  fits <- vector("list", nrow(grid))
  outcomes <- vector("list", nrow(grid))
  fail <- character(nrow(grid))
  excluded <- logical(nrow(grid))
  for (b in seq_len(nrow(grid))) {
    cons <- parsed$constraints
    lines <- character()
    for (j in seq_along(products)) {
      i <- products[[j]]$row
      lines <- c(lines, paste(grid[b, j], "== 0"))
      cons$lhs[i] <- grid[b, j]
      cons$rhs[i] <- "0"
    }
    # a branch whose restrictions contradict by literal syntax is certified empty and not optimized (D2); only that
    # proof excludes a branch, a failure to converge is unknown
    certificate <- .sem_literal_zero_certificate(parsed$parameters, cons)
    if (!is.null(certificate)) {
      excluded[b] <- TRUE
      fail[b] <- sprintf("%s: %s", paste(lines, collapse = ", "), "literal zero/nonzero contradiction")
      outcomes[[b]] <- .sem_rebase_outcome(.sem_excluded_outcome(context, cons, certificate),
                                           paste0("fit/branch:", b), "fit")
      next
    }
    captured <- .sem_capture_outcome({
      # a covariance-stage failure of one branch keeps that branch's likelihood and evidence (D4): the union decides
      res <- tryCatch(.sem_fit_syntax(NULL, data, information, n_starts, control, weights, se_type,
                                      parsed = list(parameters = parsed$parameters, constraints = cons),
                                      meanstructure = meanstructure, fixed_x = fixed_x, factors = factors,
                                      covariance_transport = TRUE),
                      medfit_sem_covariance_error = .sem_retain_covariance)
      .sem_require_outcome(res, partial = !is.null(res$ledger$post_fit))
      if (!identical(res$constraints, cons)) {
        .sem_abort_ledger("branch outcome has mismatched constraints", NULL)
      }
      res
    })
    res <- captured$value
    err <- captured$error
    if (inherits(err, "medfit_covariance_untyped") || inherits(err, "medfit_error_ledger")) stop(err)
    ledger <- if (is.null(err)) res$ledger else err$ledger
    if (is.null(err) && !is.null(ledger$post_fit)) {
      # the retention notice was raised after the branch's own ledger was built
      ledger$notices$warnings <- c(ledger$notices$warnings, lapply(captured$notices$warnings, .sem_condition_record))
      ledger$notices$messages <- c(ledger$notices$messages, lapply(captured$notices$messages, .sem_condition_record))
    }
    if (is.null(ledger)) {
      ledger <- .sem_outcome(context, cons, error = err, notices = captured$notices)
    }
    outcomes[[b]] <- .sem_rebase_outcome(ledger, paste0("fit/branch:", b), "fit")
    if (!is.null(err)) {
      fail[b] <- sprintf("%s: %s", paste(lines, collapse = ", "), conditionMessage(err))
    } else {
      res$branch <- lines
      fits[[b]] <- list(fit = res, held = captured$notices)
    }
  }
  ok <- which(!vapply(fits, is.null, TRUE))
  win <- if (length(ok)) ok[which.min(vapply(ok, function(b) fits[[b]]$fit$f, numeric(1)))] else integer()
  if (length(win)) {
    # a certified-empty branch is compared on the winner's sample and domain: same rows, same likelihood
    context <- fits[[win]]$fit$ledger$context
    for (b in which(excluded)) {
      outcomes[[b]]$context <- context
    }
  }
  ledger <- .sem_outcome(context, parsed$constraints, result = if (length(win)) fits[[win]]$fit,
                         children = outcomes, union = TRUE)
  if (!length(ok)) {
    .sem_abort_outcome(paste0("no branch of the zero-product constraints converged:\n  ",
                              paste(fail, collapse = "\n  ")), ledger)
  }
  skipped <- setdiff(seq_along(fits), c(ok, which(excluded)))
  if (length(skipped)) {
    # A minimum over the surviving branches can look valid and need not be the constrained optimum, so no fit is
    # returned: the best survivor's discrepancy goes in the message for diagnosis only.
    best <- min(vapply(ok, function(b) fits[[b]]$fit$f, numeric(1)))
    msg <- sprintf(
      paste0("%d of %d zero-product branches did not converge, so the constrained optimum is not certified ",
             "(the best of the other branches has discrepancy %s):\n  %s"),
      length(skipped), length(fits), format(best, digits = 8), paste(fail[skipped], collapse = "\n  ")
    )
    .sem_abort_outcome(msg, ledger, best_survivor = list(id = outcomes[[win]]$id, f = best))
  }
  out <- fits[[win]]$fit
  out$constraints <- parsed$constraints
  out$ledger <- ledger
  failed <- which(vapply(outcomes, function(x) !is.null(x$post_fit), TRUE))
  if (length(failed)) {
    # Every branch has a likelihood and the union is complete, but a covariance stage failed: no fit is returned. The
    # root reports the first failing branch's evidence, in branch order, even when another branch is the minimum;
    # the branch IDs say exactly which one failed.
    out$vcov <- out$defined <- NULL
    out$ledger$covariance <- "failed"
    out$ledger$post_fit <- outcomes[[failed[1L]]]$post_fit
    stop(.sem_covariance_error(outcomes[[failed[1L]]]$post_fit$condition$message, out))
  }
  .sem_replay_notices(fits[[win]]$held)
  out
}

# Product materialization (amendment rule 7, plan U3). Every `a:b` term in the completed table is an observed
# exogenous variable whose column is `a * b`, named by the canonical `.sem_product_name()`. A column already in
# `data` under either spelling is used only if it equals the product on the rows the fit keeps (checked after
# listwise deletion, where the comparison is NA-free). Returns the data with the canonical column and the
# user-supplied columns to check. A factor absent from `data` is left alone: the fit reports the absent column.
.sem_materialize_products <- function(tab, data) {
  prods <- unique(tab$rhs[tab$op == "~" & grepl(":", tab$rhs, fixed = TRUE)])
  checks <- list()
  for (nm in prods) {
    f <- strsplit(nm, ":", fixed = TRUE)[[1L]]
    if (!all(f %in% names(data))) {
      next
    }
    bad <- f[!vapply(data[f], is.numeric, TRUE)]
    if (length(bad)) {
      stop("the product '", nm, "' needs numeric variables, but ", paste(bad, collapse = ", "),
           " is not numeric", call. = FALSE)
    }
    built <- as.numeric(data[[f[1L]]]) * as.numeric(data[[f[2L]]]) # numeric: integer columns cannot overflow to NA
    for (alt in intersect(unique(c(nm, paste(f, collapse = ":"), paste(rev(f), collapse = ":"))), names(data))) {
      checks[[length(checks) + 1L]] <- list(column = alt, product = nm, given = data[[alt]], built = built)
    }
    data[[.sem_product_name(f[1L], f[2L])]] <- built
  }
  list(data = data, checks = checks)
}

.sem_check_product_columns <- function(checks, keep) {
  for (ck in checks) {
    given <- ck$given[keep]
    built <- ck$built[keep]
    if (!(is.numeric(given) && isTRUE(all(given == built)))) {
      stop("the column `", ck$column, "` in `data` is not the product of ", gsub(":", " and ", ck$product),
           " on the rows used: rename it, or drop it so medfit builds the product", call. = FALSE)
    }
  }
  invisible(TRUE)
}
