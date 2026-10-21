# Native SEM engine: fit driver for unconstrained models with optional bounds.
#
# Internal. nloptr SLSQP on the analytic gradient, an acceptance gate on every
# solution (plan Q9, Q10, Q14), and retries from perturbed valid starts. The
# gate is scale free: stationarity is the Newton decrement sqrt(g' H^-1 g) on
# the Hessian of the coordinates that are not at an active bound, so it does
# not depend on the units of the data. The model itself stays in original units.

# Both thresholds were calibrated in S6 (tests/sim/sem-reliability.R, 100 datasets per cell, four
# structures, scales x0.01 to x1000, preconditioned solver) and fixed at checkpoint A (2026-10-09):
# the decrement of converged fits is at most 3.2e-7 and of accepted stalls at least 0.0905 (1e-3 sits
# 3100x above and 90x below). The Jacobi-scaled smallest eigenvalue is at least 0.026 for converged fits
# and at most 1.7e-5 at the degenerate F = 0.680 points; the author chose 1e-4 (260x below the converged
# minimum but only 5.9x above the degenerate points, short of the 10x rule; S6 recommended 1e-3).
.sem_stat_tol <- 1e-3
.sem_singular_tol <- 1e-4
.sem_bound_window <- 1e-6
.sem_ok_status <- c(1L, 3L, 4L)
# Accepted starts whose discrepancies differ by more than this reached different optima (the discrepancy is
# scale free: it does not depend on the units of the data).
.sem_spread_tol <- 1e-6

# Thin wrapper so tests can stub the solver.
.sem_nlopt <- function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
  do.call(nloptr::nloptr, c(
    list(x0 = x0, eval_f = eval_f, eval_grad_f = eval_grad_f, lb = lb, ub = ub, opts = opts),
    constraints
  ))
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
.sem_solve_one <- function(start, ram, smp, lb, ub, opts, precondition = TRUE, obj = .sem_objective(ram, smp),
                           cons = NULL) {
  u <- if (precondition) .sem_step_floor(ram, smp) else rep(1, ram$q)
  args <- list(start / u, function(x) obj$f(x * u), function(x) obj$g(x * u) * u, lb / u, ub / u, opts)
  if (!is.null(cons)) args$constraints <- .sem_nlopt_constraints(cons, u)
  res <- do.call(.sem_nlopt, args)
  res$solution <- res$solution * u
  res
}

# A start is valid when its implied covariance is positive definite, never by
# the objective value (the sentinel is finite and large values can be valid).
.sem_start_valid <- function(theta, ram) {
  sigma <- tryCatch(.sem_implied(ram, theta), error = function(e) NULL)
  !is.null(sigma) && all(is.finite(sigma)) && .sem_sigma_pd(sigma)
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
  # A saved seed encodes the generator kind, but with no seed yet the caller's chosen kind lives only in
  # RNGkind(), which set.seed(kind = ) below would overwrite.
  kind <- RNGkind()
  on.exit({
    suppressWarnings(RNGkind(kind[1L], kind[2L], kind[3L]))
    if (had) {
      assign(".Random.seed", old, envir = globalenv()) # nolint: object_name_linter.
    } else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
      rm(".Random.seed", envir = globalenv())
    }
  })
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  expr
}

# Perturbed starts x0 + N(0, (0.5 * max(|x0|, u))^2), each clamped into the box
# before the validity test (the spec's perturbation ignores bounds), redrawn up
# to 20 times, otherwise the user's start is reused. The floor u is the
# parameter's natural unit (the spec's fixed floor of 1 made the step 9700x the
# start at data scale 0.01).
.sem_perturbed_starts <- function(start, ram, smp, lb, ub, n) {
  u <- .sem_step_floor(ram, smp)
  .sem_with_seed(.sem_seed(ram), lapply(seq_len(n), function(i) {
    for (try in seq_len(20L)) {
      cand <- .sem_clamp(start + stats::rnorm(length(start), 0, 0.5 * pmax(abs(start), u)), lb, ub)
      if (.sem_start_valid(cand, ram)) return(cand)
    }
    start
  }))
}

# Newton polish in the centered coordinates (see `.sem_center_map()`) for a fit with a mean structure and no
# constraints. SLSQP works in (A, m) units and stalls where an intercept and its paths are tied by a distant
# mean (mean/sd of about 1e5); a few Newton steps on the well-conditioned centered Hessian finish the job. A
# step is kept only when it lowers F (halved up to four times) and stays inside the bounds; the polish stops
# at an active bound or an indefinite Hessian and leaves the verdict to the acceptance gate.
.sem_polish_centered_maxit <- 8L
.sem_polish_centered <- function(theta, ram, smp, lb, ub) {
  ctr <- .sem_center_map(ram, smp)
  if (is.null(ctr)) {
    return(theta)
  }
  u <- .sem_step_floor(ram, smp)
  for (it in seq_len(.sem_polish_centered_maxit)) {
    r <- .sem_eval(theta, ram, smp, deriv = TRUE)
    if (is.null(r) || any((theta - lb) / u <= .sem_bound_window | (ub - theta) / u <= .sem_bound_window)) {
      break
    }
    hess <- .sem_hess_f_phi(theta, ram, smp, ctr)
    g <- as.vector(crossprod(ctr$t, r$g))
    if (!all(is.finite(hess)) || any(diag(hess) <= 0)) {
      break
    }
    d <- 1 / sqrt(diag(hess))
    step <- tryCatch(-d * solve(hess * outer(d, d), g * d), error = function(e) NULL)
    if (is.null(step) || !all(is.finite(step))) {
      break
    }
    move <- as.vector(ctr$t %*% step)
    f0 <- r$f
    t_len <- 1
    moved <- FALSE
    for (half in 0:4) {
      cand <- theta + t_len * move
      if (all(cand >= lb & cand <= ub)) {
        fc <- .sem_fml(cand, ram, smp)
        if (is.finite(fc) && fc <= f0 + 1e-14 * max(1, abs(f0))) {
          theta <- cand
          moved <- TRUE
          break
        }
      }
      t_len <- t_len / 2
    }
    if (!moved || max(abs(t_len * move) / u) < 1e-12) {
      break
    }
  }
  theta
}

# The acceptance gate for one solution (unconstrained fits with bounds).
.sem_gate <- function(theta, status, ram, smp, lb, ub, cons = NULL) {
  if (!is.null(cons)) {
    return(.sem_gate_projected(theta, status, ram, smp, lb, ub, cons))
  }
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
  # The bound window is relative to the parameter's natural unit, so it does not depend on the data scale.
  u <- .sem_step_floor(ram, smp)
  at_lb <- (theta - lb) / u <= .sem_bound_window
  at_ub <- (ub - theta) / u <= .sem_bound_window
  out$active <- at_lb | at_ub
  free <- !out$active
  ctr <- .sem_center_map(ram, smp)
  hess_all <- if (is.null(ctr)) .sem_hess_f(theta, ram, smp) else .sem_hess_f_phi(theta, ram, smp, ctr)
  # the reduced Hessian and the decrement live in the centered coordinates when there is a mean structure
  g_all <- if (is.null(ctr)) r$g else as.vector(crossprod(ctr$t, r$g))
  # KKT sign at an active bound: moving into the interior must not lower F. The gradient is judged in
  # the unit-free scale g / sqrt(H_kk) against the stationarity threshold.
  push <- (at_lb & !at_ub & r$g < 0) | (at_ub & !at_lb & r$g > 0)
  # A bound is on a theta coordinate. In the centered coordinates the unit move of theta_k is the column of
  # T^-1 = I - C, so the multiplier is the theta gradient and the curvature along that column.
  tinv <- if (is.null(ctr)) NULL else diag(ram$q) - ctr$c
  if (any(push)) {
    hk <- if (is.null(tinv)) {
      diag(hess_all)[push]
    } else {
      vapply(which(push), function(k) drop(crossprod(tinv[, k], hess_all %*% tinv[, k])), numeric(1))
    }
    gk <- abs(r$g[push])
    bad <- !is.finite(hk) | hk <= 0 | gk / sqrt(pmax(hk, 0)) > .sem_stat_tol
    if (any(bad)) {
      out$reason <- sprintf("the gradient at an active bound points into the interior (%s)",
                            paste(ram$par_names[push][bad], collapse = ", "))
      return(out)
    }
  }
  if (!any(free)) {
    out$decrement <- 0
    out$accepted <- TRUE
    return(out)
  }
  if (is.null(tinv) || all(free)) {
    hess <- hess_all[free, free, drop = FALSE]
    g_red <- g_all[free]
  } else {
    # the free theta directions, as an orthonormal basis of their span in the centered coordinates
    zb <- qr.Q(qr(tinv[, free, drop = FALSE]))[, seq_len(sum(free)), drop = FALSE]
    hess <- crossprod(zb, hess_all %*% zb)
    g_red <- as.vector(crossprod(zb, g_all))
  }
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
  g <- g_red * d
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

# The floor for the variances in a nonlinear row (#213), relative to the parameter's natural unit so that it does not
# depend on the data scale (an absolute 1e-4 bound binds on data in units of 1e-3).
.sem_var_floor <- 1e-4

# Free variance parameters (diagonal S entries) among `idx` whose floor is below the upper bound.
.sem_floor_ids <- function(ram, smp, idx, ub) {
  ids <- intersect(idx, unique(ram$k_s[ram$s_weight == 1]))
  ids[.sem_var_floor * .sem_step_floor(ram, smp)[ids] < ub[ids]]
}

# The fit without the nonlinear rows (linear rows and the user's bounds kept, no floor), or NULL when it fails. Its
# objective is a lower bound for the constrained discrepancy, and its estimate satisfies the nonlinear rows whenever
# the constraint value is the one at the unconstrained optimum.
.sem_reference_fit <- function(ram, smp, start, lb, ub, n_starts, control, precondition, constraints) {
  constraints$nl <- NULL
  constraints$nli <- NULL
  # no linear rows left: the plain unconstrained path, as for a model written without constraints
  if (!nrow(constraints$eq$A) && !nrow(constraints$ineq$A)) {
    constraints <- NULL
  }
  tryCatch(
    suppressWarnings(.sem_optimize(ram, smp, start, lb, ub, n_starts, control, precondition, constraints)),
    error = function(e) NULL
  )
}

# Starts built from the reference estimate: itself, then copies with the signs of the regression paths in the
# nonlinear rows flipped (every nonempty subset for up to three paths, otherwise the joint flip). The sign of a
# product constraint cannot change along the constraint surface, so each sign pattern is a separate branch.
.sem_reference_starts <- function(theta, ram, idx, lb, ub) {
  paths <- intersect(idx, ram$k_a)
  subs <- if (length(paths) == 0L) {
    list()
  } else if (length(paths) <= 3L) {
    unlist(lapply(seq_along(paths), function(m) utils::combn(seq_along(paths), m, simplify = FALSE)),
           recursive = FALSE)
  } else {
    list(seq_along(paths))
  }
  out <- list(.sem_clamp(theta, lb, ub))
  for (sub in subs) {
    cand <- theta
    cand[paths[sub]] <- -cand[paths[sub]]
    cand <- .sem_clamp(cand, lb, ub)
    if (.sem_start_valid(cand, ram)) {
      out[[length(out) + 1L]] <- cand
    }
  }
  out
}

# Whether `theta` satisfies the nonlinear rows (within the constraint tolerance) and the box.
.sem_ref_feasible <- function(theta, cons, lb, ub) {
  if (any(theta < lb) || any(theta > ub)) {
    return(FALSE)
  }
  ok <- tryCatch({
    (is.null(cons$nl) || all(abs(cons$nl$value(theta)) <= .sem_constraint_tol)) &&
      (is.null(cons$nli) || all(cons$nli$value(theta) <= .sem_constraint_tol))
  }, error = function(e) FALSE)
  isTRUE(ok)
}

# Fit by maximum likelihood. `start` is the user's start; `n_starts` is the
# total attempt budget (the first start plus up to n_starts - 1 perturbed
# retries, used only when the earlier ones are not accepted). `control` is
# merged into the nloptr options. Errors "no start converged" when no start is
# accepted, naming the best attempt's status and stationarity.
.sem_optimize <- function(ram, smp, start, lb = rep(-Inf, ram$q), ub = rep(Inf, ram$q),
                          n_starts = 5L, control = list(), precondition = TRUE, constraints = NULL) {
  checkmate::assert_numeric(start, len = ram$q, any.missing = FALSE, .var.name = "start")
  checkmate::assert_numeric(lb, len = ram$q, any.missing = FALSE, .var.name = "lb")
  checkmate::assert_numeric(ub, len = ram$q, any.missing = FALSE, .var.name = "ub")
  if (any(lb > ub)) {
    j <- which(lb > ub)[1L]
    stop(sprintf(
      "parameter '%s' has infeasible bounds: the lower bound %s is above the upper bound %s",
      ram$par_names[j], format(lb[j]), format(ub[j])
    ), call. = FALSE)
  }
  checkmate::assert_count(n_starts, positive = TRUE, .var.name = "n_starts")
  checkmate::assert_list(control, .var.name = "control")
  checkmate::assert_flag(precondition, .var.name = "precondition")
  opts <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = 10000L)
  opts[names(control)] <- control
  # A model with a nonlinear constraint can have several local optima (`a*b > 0.1` is feasible on two
  # disjoint pieces), so every start is tried and the best accepted one is kept; otherwise the first accepted
  # start wins and the rest are retries.
  best_of <- !is.null(constraints$nl) || !is.null(constraints$nli)
  # Nonlinear rows only (#213): the variances in the rows get a floor relative to the data scale (the solver
  # may step to a negative variance, where the row is not defined), the model without the nonlinear rows is
  # fitted first (its estimate is an incumbent and a start), and its sign-flipped copies are extra starts.
  # Every other fit takes none of these steps.
  ref <- NULL
  floored <- integer()
  if (best_of) {
    nl_idx <- sort(unique(c(constraints$nl$idx, constraints$nli$idx)))
    floored <- .sem_floor_ids(ram, smp, nl_idx, ub)
    ref <- .sem_reference_fit(ram, smp, start, lb, ub, n_starts, control, precondition, constraints)
    lb[floored] <- pmax(lb[floored], .sem_var_floor * .sem_step_floor(ram, smp)[floored])
  }
  start0 <- .sem_clamp(start, lb, ub)
  # The perturbed retries are drawn around the supplied start, so a start in a bad basin gives only bad attempts.
  # Where the budget allows (n_starts >= 3) the last attempt is the model's own default start instead of one more
  # perturbation; it is reached only after every earlier attempt failed, and a model that tries every start
  # (nonlinear rows) keeps its starts as they were.
  dflt <- if (!best_of && n_starts >= 3L) .sem_clamp(.sem_default_start(ram, smp), lb, ub) else NULL
  if (!is.null(dflt) && (!.sem_start_valid(dflt, ram) || isTRUE(all.equal(dflt, start0, tolerance = 0)))) {
    dflt <- NULL
  }
  n_perturbed <- n_starts - 1L - !is.null(dflt)
  starts <- c(list(start0), if (n_perturbed > 0L) .sem_perturbed_starts(start0, ram, smp, lb, ub, n_perturbed),
              if (!is.null(dflt)) list(dflt))
  if (!is.null(ref)) {
    starts <- c(.sem_reference_starts(ref$theta, ram, nl_idx, lb, ub), starts)
  }
  obj <- .sem_objective(ram, smp)
  attempts <- vector("list", length(starts))
  win <- NA_integer_
  for (i in seq_along(starts)) {
    res <- tryCatch(.sem_solve_one(starts[[i]], ram, smp, lb, ub, opts, precondition, obj, constraints),
                    error = function(e) e)
    if (inherits(res, "error")) {
      attempts[[i]] <- list(accepted = FALSE, status = NA_integer_, decrement = NA_real_, f = Inf,
                            reason = paste("nloptr error:", conditionMessage(res)))
      next
    }
    if (is.null(constraints) && isTRUE(res$status %in% .sem_ok_status) && ram$has_mean) {
      res$solution <- .sem_polish_centered(res$solution, ram, smp, lb, ub)
      res$objective <- .sem_fml(res$solution, ram, smp)
    }
    gate <- .sem_gate(res$solution, res$status, ram, smp, lb, ub, constraints)
    if (gate$accepted && !is.null(constraints)) {
      pol <- .sem_polish_accept(res, gate, ram, smp, lb, ub, constraints)
      res <- pol$res
      gate <- pol$gate
    }
    gate$f <- res$objective
    gate$theta <- res$solution
    attempts[[i]] <- gate
    if (gate$accepted && !best_of) {
      win <- i
      break
    }
  }
  accepted <- which(vapply(attempts, function(a) isTRUE(a$accepted), TRUE))
  if (best_of && length(accepted)) {
    win <- accepted[which.min(vapply(attempts[accepted], function(a) a$f, numeric(1)))]
  }
  # Dominance (#213): a feasible reference estimate is never beaten by a worse accepted fit. When the constraint
  # already holds at the unconstrained estimate, that estimate is the constrained optimum.
  eps_f <- if (is.null(ref)) 0 else 1e-10 * max(1, abs(ref$f))
  ref_ok <- !is.null(ref) && .sem_ref_feasible(ref$theta, constraints, lb, ub)
  if (ref_ok && (is.na(win) || attempts[[win]]$f > ref$f + eps_f)) {
    g <- .sem_gate(ref$theta, ref$status, ram, smp, lb, ub, constraints)
    if (!g$accepted) {
      stop(sprintf(
        paste0("optimization incomplete: a feasible point with a lower discrepancy exists (the fit without the ",
               "nonlinear rows satisfies them), but it was not accepted (%s)"), g$reason
      ), call. = FALSE)
    }
    g$f <- ref$f
    g$theta <- ref$theta
    attempts <- c(attempts, list(g))
    win <- length(attempts)
    accepted <- c(accepted, win)
  }
  if (is.na(win)) {
    best <- attempts[[which.min(vapply(attempts, function(a) a$f, numeric(1)))]]
    stop(sprintf(
      "no start converged (%d tried); best attempt: status %s, stationarity %s; %s",
      length(attempts), format(best$status), format(signif(best$decrement, 3)), best$reason
    ), call. = FALSE)
  }
  fit <- attempts[[win]]
  # A fit that reaches a feasible reference estimate is the constrained optimum (the reference is a lower bound), so
  # worse optima on other branches are not worth a note.
  certified <- ref_ok && fit$f <= ref$f + .sem_spread_tol
  optimum_spread <- NA_real_
  if (best_of && length(accepted) > 1L) {
    optimum_spread <- diff(range(vapply(attempts[accepted], function(a) a$f, numeric(1))))
  }
  optimum_status <- "unique"
  if (best_of) {
    optimum_status <- if (certified) {
      "certified"
    } else if (length(accepted) == 1L) {
      "single"
    } else if (optimum_spread > .sem_spread_tol) {
      "disagreed"
    } else {
      "agreed"
    }
  }
  optimum <- list(
    n_starts = if (best_of) length(starts) else sum(!vapply(attempts, is.null, logical(1))),
    n_accepted = length(accepted), best_of = best_of, certified = certified,
    spread = optimum_spread, status = optimum_status
  )
  spread <- if (best_of && !certified && length(accepted) > 1L) {
    diff(range(vapply(attempts[accepted], function(a) a$f, numeric(1))))
  }
  if (!is.null(spread) && spread > .sem_spread_tol) {
    warning(sprintf(
      paste0("the starts disagree: %d of %d reached accepted solutions with discrepancies from %s to %s; the ",
             "lowest was kept, but the model may have a better optimum (more starts: `n_starts`)"),
      length(accepted), length(starts), format(signif(fit$f, 6)),
      format(signif(max(vapply(attempts[accepted], function(a) a$f, numeric(1))), 6))
    ), call. = FALSE)
  }
  # One accepted start gives the spread rule nothing to compare, so a fit that found a single optimum (every other
  # start failed or was rejected) used to be silent. The failing starts are often the sign-flipped ones that would
  # have found the other branch, so the fit is flagged. A fit certified by the feasible reference is the optimum.
  if (best_of && !certified && length(accepted) == 1L && length(starts) > 1L) {
    warning(sprintf(
      paste0("only %d of %d starts reached an accepted solution; the fit is the one optimum found, and the model may ",
             "have a better one on another branch (more starts: `n_starts`)"),
      length(accepted), length(starts)
    ), call. = FALSE)
  }
  if (win > 1L && !best_of) {
    used <- if (!is.null(dflt) && win == length(starts)) {
      "the default start"
    } else {
      sprintf("perturbed start %d of %d", win - 1L, n_perturbed)
    }
    warning(sprintf("the first start was not accepted (%s); the fit used %s", attempts[[1]]$reason, used),
            call. = FALSE)
  }
  if (!is.null(ref) && fit$f < ref$f - .sem_spread_tol) {
    warning(sprintf(
      paste0("the fit without the nonlinear rows (discrepancy %s) is not the global optimum: the constrained fit ",
             "found a lower one (%s), so a likelihood-ratio statistic against it is not certified"),
      format(signif(ref$f, 6)), format(signif(fit$f, 6))
    ), call. = FALSE)
  }
  floor_active <- ram$par_names[intersect(floored, which(fit$active))]
  if (length(floor_active)) {
    warning(sprintf(
      paste0("variance %s is at the solver floor (%s x its natural unit); the constrained optimum may be improper ",
             "or on the boundary, so the likelihood-ratio statistic and the standard errors treat it as a bound"),
      paste(floor_active, collapse = ", "), format(.sem_var_floor)
    ), call. = FALSE)
  }
  improper <- .sem_improper(fit$theta, ram)
  if (length(improper)) {
    warning("improper solution: ", paste(improper, collapse = "; "), call. = FALSE)
  }
  for (w in fit$sign_warnings) warning(w, call. = FALSE)
  list(
    theta = stats::setNames(fit$theta, ram$par_names), f = fit$f, status = fit$status,
    decrement = fit$decrement, converged = TRUE, retries = win - 1L,
    active_bounds = ram$par_names[fit$active], improper = improper, attempts = attempts,
    floor_active = floor_active, reference_f = if (is.null(ref)) NA_real_ else ref$f,
    multipliers = fit$multipliers, sign_check = if (is.null(fit$sign_check)) "ok" else fit$sign_check,
    optimum = optimum
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
  if (ram$has_mean && length(ram$k_m)) {
    # intercept starts match the sample means: m_v = xbar_v - (A xbar)_v with the start paths
    a <- ram$a0
    a[ram$pos_a] <- start[ram$k_a]
    ao <- a[ram$obs_idx, ram$obs_idx, drop = FALSE]
    mv <- numeric(ram$nv)
    mv[ram$obs_idx] <- smp$xbar - as.vector(ao %*% smp$xbar)
    start[ram$k_m] <- mv[ram$pos_m]
  }
  stats::setNames(start, ram$par_names)
}
