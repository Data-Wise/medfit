# Native SEM engine: fit driver for unconstrained models with optional bounds.
#
# Internal. nloptr SLSQP on the analytic gradient, an acceptance gate on every
# solution (plan Q9, Q10, Q14), and retries from perturbed valid starts. The
# gate is scale free: stationarity is the Newton decrement sqrt(g' H^-1 g) on
# the Hessian of the coordinates that are not at an active bound, so it does
# not depend on the units of the data. The model itself stays in original units.

# Both thresholds were calibrated in S6 (tests/sim/sem-reliability.R, 100 datasets per cell, four
# structures, scales x0.01 to x1000, preconditioned solver) and wait for the author's checkpoint A:
# the decrement of converged fits is at most 3.6e-7 and of accepted stalls at least 0.089 (1e-3 sits
# 2800x above and 89x below); the Jacobi-scaled smallest eigenvalue is at least 0.024 for converged fits
# and at most 1.7e-5 at the degenerate F = 0.680 points (1e-3 sits 24x below and 59x above).
.sem_stat_tol <- 1e-3
.sem_singular_tol <- 1e-3
.sem_bound_window <- 1e-6
.sem_ok_status <- c(1L, 3L, 4L)

# Thin wrapper so tests can stub the solver.
.sem_nlopt <- function(x0, eval_f, eval_grad_f, lb, ub, opts) {
  nloptr::nloptr(x0 = x0, eval_f = eval_f, eval_grad_f = eval_grad_f, lb = lb, ub = ub, opts = opts)
}

# Objective and gradient closures sharing one evaluation per parameter vector
# (nloptr asks for them separately); the sentinel and a zero gradient where the
# implied covariance is unusable.
.sem_objective <- function(ram, smp) {
  last_x <- NULL
  last <- NULL
  get_eval <- function(x) {
    if (is.null(last_x) || !identical(x, last_x)) {
      last <<- .sem_eval(x, ram, smp, deriv = TRUE)
      last_x <<- x
    }
    last
  }
  list(
    f = function(x) {
      r <- get_eval(x)
      if (is.null(r)) .sem_sentinel else r$f
    },
    g = function(x) {
      r <- get_eval(x)
      if (is.null(r)) numeric(ram$q) else r$g
    }
  )
}

.sem_clamp <- function(x, lb, ub) pmin(pmax(x, lb), ub)

# One nloptr run from `start`. With `precondition`, the solver works in units of
# each parameter's natural scale (theta / u, u from .sem_step_floor()): the
# objective, gradient and bounds are mapped in and the solution mapped back, so
# the model, the start, the bounds and the acceptance gate stay in original
# units. SLSQP stalls when parameters differ by orders of magnitude (variances
# 1e6 beside paths of 1 when the data are in large units).
.sem_solve_one <- function(start, ram, smp, lb, ub, opts, precondition = TRUE, obj = .sem_objective(ram, smp)) {
  u <- if (precondition) .sem_step_floor(ram, smp) else rep(1, ram$q)
  res <- .sem_nlopt(start / u, function(x) obj$f(x * u), function(x) obj$g(x * u) * u, lb / u, ub / u, opts)
  res$solution <- res$solution * u
  res
}

# A start is valid when its implied covariance is positive definite, never by
# the objective value (the sentinel is finite and large values can be valid).
.sem_start_valid <- function(theta, ram) {
  sigma <- tryCatch(.sem_implied(ram, theta), error = function(e) NULL)
  !is.null(sigma) && all(is.finite(sigma)) &&
    min(eigen(sigma, symmetric = TRUE, only.values = TRUE)$values) > .sem_pd_floor
}

# Seed from the model's own text (base-R hash, no dependency), so reruns agree.
.sem_seed <- function(ram) {
  txt <- paste(c(ram$par_names, ram$vars, as.character(ram$a0), as.character(ram$s0)), collapse = "|")
  h <- 5381
  for (ch in utf8ToInt(txt)) h <- (h * 33 + ch) %% 2147483647
  as.integer(h)
}

# Run `expr` under a fixed seed and restore the caller's RNG state afterwards.
.sem_with_seed <- function(seed, expr) {
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (had) old <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit({
    if (had) {
      assign(".Random.seed", old, envir = globalenv()) # nolint: object_name_linter.
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  })
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  expr
}

# Perturbed starts x0 + N(0, (0.5 * max(|x0|, 1))^2), each clamped into the box
# before the validity test (the spec's perturbation ignores bounds), redrawn up
# to 20 times, otherwise the user's start is reused.
.sem_perturbed_starts <- function(start, ram, lb, ub, n) {
  .sem_with_seed(.sem_seed(ram), lapply(seq_len(n), function(i) {
    for (try in seq_len(20L)) {
      cand <- .sem_clamp(start + stats::rnorm(length(start), 0, 0.5 * pmax(abs(start), 1)), lb, ub)
      if (.sem_start_valid(cand, ram)) return(cand)
    }
    start
  }))
}

# The acceptance gate for one solution (unconstrained fits with bounds).
.sem_gate <- function(theta, status, ram, smp, lb, ub) {
  out <- list(accepted = FALSE, status = status, decrement = NA_real_, min_eig = NA_real_,
              active = rep(FALSE, length(theta)), reason = "")
  if (!isTRUE(status %in% .sem_ok_status)) {
    out$reason <- sprintf("nloptr status %s is not a success code", status)
    return(out)
  }
  r <- .sem_eval(theta, ram, smp, deriv = TRUE)
  if (is.null(r)) {
    out$reason <- "implied covariance is not positive definite"
    return(out)
  }
  out$active <- (theta - lb <= .sem_bound_window) | (ub - theta <= .sem_bound_window)
  free <- !out$active
  if (!any(free)) {
    out$decrement <- 0
    out$accepted <- TRUE
    return(out)
  }
  hess <- .sem_hess_f(theta, ram, smp)[free, free, drop = FALSE]
  # Definiteness is judged on the Jacobi-scaled matrix (the same verdict, but not blind to a small
  # negative diagonal entry beside entries of size 1e12, where raw eigenvalues are only accurate
  # to about 1e-4).
  dg <- diag(hess)
  if (!all(is.finite(hess)) || any(dg <= 0)) {
    out$reason <- "reduced Hessian is not positive definite"
    return(out)
  }
  d <- 1 / sqrt(dg)
  scaled <- hess * outer(d, d)
  ev <- eigen(scaled, symmetric = TRUE, only.values = TRUE)$values
  if (min(ev) <= 0) {
    out$reason <- "reduced Hessian is not positive definite"
    return(out)
  }
  out$min_eig <- min(ev)
  if (out$min_eig < .sem_singular_tol) {
    out$reason <- sprintf("Hessian is nearly singular (scaled smallest eigenvalue %.2e)", out$min_eig)
    return(out)
  }
  # The decrement is solved in the Jacobi-scaled coordinates (the same number, better conditioned).
  g <- r$g[free] * d
  out$decrement <- sqrt(sum(g * solve(scaled, g)))
  if (out$decrement > .sem_stat_tol) {
    out$reason <- sprintf("stationarity %.2e exceeds %.0e", out$decrement, .sem_stat_tol)
  } else {
    out$accepted <- TRUE
  }
  out
}

# Improper solutions: negative variances and non-positive-definite latent
# covariance blocks. Reported, never silently bounded.
.sem_improper <- function(theta, ram) {
  msgs <- character()
  var_k <- ram$k_s[ram$s_weight == 1]
  neg <- unique(var_k[theta[var_k] < 0])
  if (length(neg)) {
    msgs <- c(msgs, paste0("negative variance: ", paste(ram$par_names[neg], collapse = ", ")))
  }
  latent <- setdiff(ram$vars, ram$obs)
  if (length(latent) > 1L) {
    blk <- .sem_ram_mats(ram, theta)$s[match(latent, ram$vars), match(latent, ram$vars), drop = FALSE]
    if (min(eigen(blk, symmetric = TRUE, only.values = TRUE)$values) < -1e-8) {
      msgs <- c(msgs, "latent covariance matrix is not positive definite")
    }
  }
  msgs
}

# Fit by maximum likelihood. `start` is the user's start; `n_starts` is the
# total attempt budget (the first start plus up to n_starts - 1 perturbed
# retries, used only when the earlier ones are not accepted). `control` is
# merged into the nloptr options. Errors "no start converged" when no start is
# accepted, naming the best attempt's status and stationarity.
.sem_optimize <- function(ram, smp, start, lb = rep(-Inf, ram$q), ub = rep(Inf, ram$q),
                          n_starts = 5L, control = list(), precondition = TRUE) {
  checkmate::assert_numeric(start, len = ram$q, any.missing = FALSE, .var.name = "start")
  checkmate::assert_numeric(lb, len = ram$q, any.missing = FALSE, .var.name = "lb")
  checkmate::assert_numeric(ub, len = ram$q, any.missing = FALSE, .var.name = "ub")
  checkmate::assert_true(all(lb <= ub), .var.name = "lb <= ub")
  checkmate::assert_count(n_starts, positive = TRUE, .var.name = "n_starts")
  checkmate::assert_list(control, .var.name = "control")
  checkmate::assert_flag(precondition, .var.name = "precondition")
  opts <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = 10000L)
  opts[names(control)] <- control
  start0 <- .sem_clamp(start, lb, ub)
  starts <- c(list(start0), if (n_starts > 1L) .sem_perturbed_starts(start0, ram, lb, ub, n_starts - 1L))
  obj <- .sem_objective(ram, smp)

  attempts <- vector("list", length(starts))
  win <- NA_integer_
  for (i in seq_along(starts)) {
    res <- tryCatch(.sem_solve_one(starts[[i]], ram, smp, lb, ub, opts, precondition, obj), error = function(e) e)
    if (inherits(res, "error")) {
      attempts[[i]] <- list(accepted = FALSE, status = NA_integer_, decrement = NA_real_, f = Inf,
                            reason = paste("nloptr error:", conditionMessage(res)))
      next
    }
    gate <- .sem_gate(res$solution, res$status, ram, smp, lb, ub)
    gate$f <- res$objective
    gate$theta <- res$solution
    attempts[[i]] <- gate
    if (gate$accepted) {
      win <- i
      break
    }
  }
  if (is.na(win)) {
    best <- attempts[[which.min(vapply(attempts, function(a) a$f, numeric(1)))]]
    stop(sprintf(
      "no start converged (%d tried); best attempt: status %s, stationarity %s; %s",
      length(attempts), format(best$status), format(signif(best$decrement, 3)), best$reason
    ), call. = FALSE)
  }
  fit <- attempts[[win]]
  if (win > 1L) {
    warning(sprintf(
      "the first start was not accepted (%s); the fit used perturbed start %d of %d",
      attempts[[1]]$reason, win - 1L, length(starts) - 1L
    ), call. = FALSE)
  }
  improper <- .sem_improper(fit$theta, ram)
  if (length(improper)) {
    warning("improper solution: ", paste(improper, collapse = "; "), call. = FALSE)
  }
  list(
    theta = stats::setNames(fit$theta, ram$par_names), f = fit$f, status = fit$status,
    decrement = fit$decrement, converged = TRUE, retries = win - 1L,
    active_bounds = ram$par_names[fit$active], improper = improper, attempts = attempts
  )
}

# Moment-based start in the parameters' own units: paths 0.1 * sd(to) / sd(from),
# variances half the variable's variance (a latent variable's variance is half the
# mean observed variance), covariances zero. Equivariant: rescaling the data
# rescales the start exactly as it rescales the parameters.
.sem_default_start <- function(ram, smp) {
  u <- .sem_step_floor(ram, smp)
  start <- numeric(ram$q)
  start[ram$k_a] <- 0.1 * u[ram$k_a]
  var_k <- ram$k_s[ram$s_weight == 1]
  start[ram$k_s[ram$s_weight == 2]] <- 0
  start[var_k] <- 0.5 * u[var_k]
  stats::setNames(start, ram$par_names)
}
