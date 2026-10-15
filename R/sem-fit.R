# Native SEM engine: syntax to fit.
#
# Internal. `.sem_fit_syntax()` runs the whole pipeline for model syntax and
# raw data: parse, complete, check the scale and the degrees of freedom, drop
# incomplete rows once, fit by maximum likelihood, and compute the covariance of
# the estimates. It returns a plain list; the exported fit object arrives with
# `fit_mediation(engine = "native")` (plan N4).

.sem_fit_syntax <- function(model, data, information = c("observed", "expected"), n_starts = 5L,
                            control = list(), weights = NULL, se_type = c("model", "sandwich"), parsed = NULL,
                            meanstructure = NULL, fixed_x = FALSE, factors = NULL) {
  checkmate::assert_data_frame(data, min.rows = 1L, .var.name = "data")
  information <- match.arg(information)
  se_type <- match.arg(se_type)
  if (!is.null(weights)) {
    weights <- .sem_check_weights(weights, nrow(data))
  }
  if (is.null(parsed)) {
    parsed <- .sem_parse(model)
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
      vars <- intersect(unique(sides), names(data))
      rows <- stats::complete.cases(data[, vars, drop = FALSE])
      .sem_check_dummy_support(factors, data, data[rows, vars, drop = FALSE],
                               if (!is.null(weights)) weights[rows])
      out <- .sem_fit_branches(parsed, products, data, information, n_starts, control, weights, se_type,
                               meanstructure, fixed_x)
      out$factors <- factors
      return(out)
    }
  }
  if (any(parsed$parameters$level != 1L)) {
    stop("two-level estimation is not implemented: the model uses `level:` blocks", call. = FALSE)
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
  .sem_check_dummy_support(factors, data, x, weights[keep])
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
  vc <- .sem_vcov(fit$theta, ram, smp, information, cons, lb, ub, se_type)
  defined <- .sem_defined(parsed$constraints, fit$theta, vc)
  act_cons <- if (is.null(cons)) .sem_no_cons(ram$q) else cons
  act <- .sem_active_set(fit$theta, ram, smp, lb, ub, act_cons)
  .sem_product_warn(tab, modeltest, se_type)

  c(
    fit,
    list(
      vcov = vc, defined = defined, constraints = parsed$constraints,
      active_constraints = act$text[act$active_row], information = information, ram = ram, table = conv$table,
      par_map = conv$par_map, se_type = se_type, weights = smp$w, n_starts = n_starts, control = control,
      partable = .sem_to_partable(conv$table), data = x, n_obs = smp$n, n_dropped = n_dropped, df = df,
      eq_rank = eq_rank, branch = character(), fixed_x = fixed_set, factors = factors
    )
  )
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
# the error lists each. Messages and warnings of the losing branches are dropped, those of the winner are
# passed on. The returned fit keeps the user's constraints; `branch` names the lines the winner used.
.sem_fit_branches <- function(parsed, products, data, information, n_starts, control, weights, se_type,
                              meanstructure = NULL, fixed_x = FALSE) {
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
                        meanstructure = meanstructure, fixed_x = fixed_x),
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
