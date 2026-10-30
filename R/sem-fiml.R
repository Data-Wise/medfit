# Bounded three-variable Gaussian FIML numerical kernel.
# Pattern summaries use ML divisors; all-empty rows contribute no likelihood.
.sem_fiml_diagnostic <- function(reason) {
  stop(structure(list(message = reason, call = NULL),
    class = c("medfit_sem_fiml_error", "error", "condition")
  ))
}
.sem_fiml_ram <- function(direct) {
  a <- data.frame(
    row = c("M", "Y", "Y"), col = c("X", "M", "X"),
    label = c("a", "b", "cp"), value = c(NA, NA, if (direct) NA else 0)
  )
  s <- data.frame(
    row = c("X", "M", "Y"), col = c("X", "M", "Y"),
    label = c("vx", "vm", "vy"), value = NA_real_
  )
  m <- data.frame(row = c("X", "M", "Y"), label = c("ix", "im", "iy"), value = NA_real_)
  .sem_ram(c("X", "M", "Y"), c("X", "M", "Y"), a, s, m)
}
.sem_fiml_prepare <- function(data, direct = TRUE, fixed_x = FALSE,
                              row_id = seq_len(nrow(data)), ...) {
  if (length(list(...)) || !identical(fixed_x, FALSE) ||
        !is.logical(direct) || length(direct) != 1L || is.na(direct)) {
    .sem_fiml_diagnostic("unsupported FIML setting")
  }
  if (!is.matrix(data) || !is.numeric(data) || ncol(data) != 3L ||
        !identical(colnames(data), c("X", "M", "Y")) ||
        any(!is.finite(data) & !is.na(data)) || length(row_id) != nrow(data) ||
        anyNA(row_id) || anyDuplicated(row_id)) {
    .sem_fiml_diagnostic("invalid FIML input")
  }
  if (any(colSums(!is.na(data)) < 2L)) .sem_fiml_diagnostic("variable has insufficient observations")
  center <- colMeans(data, na.rm = TRUE)
  scale <- apply(data, 2, stats::sd, na.rm = TRUE)
  if (any(!is.finite(scale) | scale <= 0)) .sem_fiml_diagnostic("variable has no positive scale")
  z <- sweep(sweep(data, 2, center), 2, scale, `/`)
  keys <- apply(!is.na(z), 1, paste0, collapse = "")
  groups <- lapply(split(seq_len(nrow(z)), keys), function(ids) {
    cols <- which(!is.na(z[ids[1], ]))
    block <- z[ids, cols, drop = FALSE]
    mean <- colMeans(block)
    centered <- sweep(block, 2, mean)
    list(
      ids = ids, cols = cols, n = length(ids), mean = mean,
      covariance = crossprod(centered) / length(ids)
    )
  })
  ram <- .sem_fiml_ram(direct)
  names0 <- ram$par_names
  # Linear affine transport from standardized structural coordinates.
  offset <- stats::setNames(rep(0, ram$q), names0)
  offset[c("ix", "im", "iy")] <- center
  units <- stats::setNames(rep(1, ram$q), names0)
  units[c("ix", "im", "iy")] <- scale
  units[c("vx", "vm", "vy")] <- scale^2
  units["a"] <- scale[2] / scale[1]
  units["b"] <- scale[3] / scale[2]
  if (direct) units["cp"] <- scale[3] / scale[1]
  transport <- diag(unname(units))
  dimnames(transport) <- list(names0, names0)
  transport["im", "a"] <- -center[1] * units["a"]
  transport["iy", "b"] <- -center[2] * units["b"]
  if (direct) transport["iy", "cp"] <- -center[1] * units["cp"]
  retained <- rowSums(!is.na(data)) > 0L
  list(
    ram = ram, groups = groups, standardized = z, direct = direct,
    n = sum(retained), center = center, scale = scale, units = units,
    transport = transport, offset = offset,
    jacobian = sum(colSums(!is.na(data)) * log(scale)),
    rows = list(original = row_id, retained = row_id[retained], empty = row_id[!retained])
  )
}
.sem_fiml_eval <- function(theta, p, derivative = TRUE) {
  sigma <- .sem_implied(p$ram, theta)
  if (!.sem_sigma_pd(sigma)) {
    return(NULL)
  }
  mu <- .sem_implied_mean(p$ram, theta)
  if (derivative) {
    ds <- .sem_dsigma(theta, p$ram)
    dm <- .sem_dmu(theta, p$ram)
  }
  value <- 0
  gradient <- numeric(length(theta))
  for (g in p$groups) {
    j <- g$cols
    if (!length(j)) next
    U <- tryCatch(chol(sigma[j, j, drop = FALSE]), error = function(e) NULL)
    if (is.null(U)) {
      return(NULL)
    }
    W <- chol2inv(U)
    d <- g$mean - mu[j]
    transport <- g$covariance + tcrossprod(d)
    value <- value + g$n / 2 * (length(j) * log(2 * pi) +
                                  2 * sum(log(diag(U))) + sum(W * transport))
    if (derivative) {
      B <- W - W %*% transport %*% W
      for (k in seq_along(theta)) {
        gradient[k] <- gradient[k] + g$n *
          (sum(B * ds[[k]][j, j, drop = FALSE]) / 2 - sum(dm[j, k] * (W %*% d)))
      }
    }
  }
  list(value = value, gradient = gradient)
}
.sem_fiml_hessian <- function(theta, p, multiplier = 1) {
  h <- multiplier * .Machine$double.eps^(1 / 3) * pmax(abs(theta), 1)
  v <- match(c("vx", "vm", "vy"), p$ram$par_names)
  h[v] <- pmin(h[v], theta[v] / 10)
  central <- function(step) {
    H <- vapply(seq_along(theta), function(k) {
      delta <- numeric(length(theta))
      delta[k] <- step[k]
      up <- .sem_fiml_eval(theta + delta, p)
      down <- .sem_fiml_eval(theta - delta, p)
      if (is.null(up) || is.null(down)) .sem_fiml_diagnostic("invalid Hessian perturbation")
      (up$gradient - down$gradient) / (2 * step[k])
    }, numeric(length(theta)))
    (H + t(H)) / 2
  }
  (4 * central(h / 2) - central(h)) / 3
}
# Exact likelihood DIFFERENCE, computed without subtracting two large NLLs.
# Used only for same-nlminb refinement; its gradient is the unchanged score.
.sem_fiml_difference <- function(theta, anchor, p) {
  S <- .sem_implied(p$ram, theta)
  if (!.sem_sigma_pd(S)) {
    return(1e10)
  }
  S0 <- .sem_implied(p$ram, anchor)
  mu <- .sem_implied_mean(p$ram, theta)
  mu0 <- .sem_implied_mean(p$ram, anchor)
  sum(vapply(p$groups, function(g) {
    j <- g$cols
    if (!length(j)) {
      return(0)
    }
    U0 <- chol(S0[j, j, drop = FALSE])
    W0 <- chol2inv(U0)
    W <- chol2inv(chol(S[j, j, drop = FALSE]))
    delta <- S[j, j, drop = FALSE] - S0[j, j, drop = FALSE]
    E <- forwardsolve(t(U0), delta)
    E <- t(forwardsolve(t(U0), t(E)))
    logratio <- sum(log1p(eigen((E + t(E)) / 2, symmetric = TRUE)$values))
    d0 <- g$mean - mu0[j]
    dd <- mu0[j] - mu[j]
    T0 <- g$covariance + tcrossprod(d0)
    g$n / 2 * (logratio + sum((-W0 %*% delta %*% W) * T0) +
                 2 * sum(dd * (W %*% d0)) + sum(dd * (W %*% dd)))
  }, numeric(1)))
}
.sem_fiml_geometry <- function(theta, p) {
  S <- .sem_implied(p$ram, theta)
  dm <- .sem_dmu(theta, p$ram)
  ds <- .sem_dsigma(theta, p$ram)
  G <- matrix(0, length(theta), length(theta))
  for (g in p$groups) {
    j <- g$cols
    if (!length(j)) next
    W <- chol2inv(chol(S[j, j, drop = FALSE]))
    D <- lapply(ds, function(d) W %*% d[j, j, drop = FALSE])
    G <- G + g$n * crossprod(dm[j, , drop = FALSE], W %*% dm[j, , drop = FALSE])
    for (k in seq_along(theta)) {
      for (l in seq_along(theta)) {
        G[k, l] <- G[k, l] + g$n / 2 * sum(D[[k]] * t(D[[l]]))
      }
    }
  }
  G
}
.sem_fiml_fit <- function(data, direct = TRUE, fixed_x = FALSE,
                          row_id = seq_len(nrow(data)), ...) {
  p <- .sem_fiml_prepare(data, direct, fixed_x, row_id, ...)
  ram <- p$ram
  initial <- stats::setNames(rep(0, ram$q), ram$par_names)
  initial[c("vx", "vm", "vy")] <- 1
  starts <- list(
    initial, initial + .12 * sin(seq_along(initial)),
    initial - .15 * cos(seq_along(initial))
  )
  lower <- rep(-Inf, ram$q)
  lower[match(c("vx", "vm", "vy"), ram$par_names)] <- 1e-10
  last <- NULL
  cached <- NULL
  evaluate <- function(theta) {
    if (!identical(theta, last)) {
      last <<- theta
      cached <<- .sem_fiml_eval(theta, p)
    }
    cached
  }
  obj <- list(f = function(theta) {
    e <- evaluate(theta)
    if (is.null(e)) 1e10 else 2 * e$value / p$n
  }, g = function(theta) {
    e <- evaluate(theta)
    if (is.null(e)) numeric(ram$q) else 2 * e$gradient / p$n
  })
  attempts <- list()
  candidates <- list()
  call_log <- new.env(parent = emptyenv())
  call_log$calls <- list()
  # The post-return evaluation belongs to the solver attempt, too. Preserve the
  # actual calls and partial attempt if any later operation in that seam throws.
  tryCatch({
    for (solver in c("slsqp", "nlminb")) {
      for (i in seq_along(starts)) {
        attempt_recorded <- FALSE
        first_status <- NA_integer_
        run_solver <- function(expr, phase) {
          ans <- tryCatch(expr, error = identity)
          status <- if (inherits(ans, "error")) NA_integer_ else if (solver == "slsqp") ans$status else ans$convergence
          call_log$calls[[length(call_log$calls) + 1L]] <- list(
            solver = solver, start = i, phase = phase,
            status = status, condition = if (inherits(ans, "error")) ans else NULL
          )
          if (inherits(ans, "error")) stop(ans)
          ans
        }
        run <- tryCatch(
          {
            if (solver == "slsqp") {
              r <- run_solver(.sem_solve_one(starts[[i]], ram,
                list(s = diag(3)), lower, rep(Inf, ram$q),
                list(
                  algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-12, ftol_rel = 1e-14,
                  maxeval = 10000L
                ),
                obj = obj
              ), "initial")
              list(
                theta = r$solution, status = r$status,
                ok = r$status %in% .sem_ok_status
              )
            } else {
              r <- run_solver(stats::nlminb(starts[[i]], obj$f,
                gradient = obj$g, lower = lower,
                control = list(
                  rel.tol = 1e-10, x.tol = 1e-12,
                  iter.max = 3000, eval.max = 6000
                )
              ), "initial")
              first_status <- r$convergence
              # Restart the SAME optimizer against an accurately anchored objective.
              # This is not a cross-solver polish or an acceptance-tolerance change.
              anchor <- r$par
              objective <- function(theta) 1 + 2 * .sem_fiml_difference(theta, anchor, p) / p$n
              r <- run_solver(stats::nlminb(anchor, objective,
                                gradient = obj$g, hessian = function(theta) 2 * .sem_fiml_hessian(theta, p) / p$n,
                                lower = lower,
                                control = list(rel.tol = 1e-10, x.tol = 1e-12, iter.max = 3000, eval.max = 6000)
                              ), "refinement")
              list(
                theta = r$par, status = r$convergence, ok = r$convergence == 0L,
                first_status = first_status
              )
            }
          },
          error = identity
        )
        if (inherits(run, "error")) {
          attempts[[length(attempts) + 1L]] <- data.frame(
            solver = solver, start = i,
            first_status = first_status, status = NA_integer_, accepted = FALSE,
            nll = NA_real_, stationarity = NA_real_,
            reason = conditionMessage(run)
          )
          attempt_recorded <- TRUE
          next
        }
        e <- .sem_fiml_eval(run$theta, p)
        stationarity <- if (is.null(e)) {
          Inf
        } else {
          max(abs(p$units * as.vector(solve(t(p$transport), e$gradient / p$n))))
        }
        ok <- isTRUE(run$ok) && stationarity <= 1e-5
        reason <- if (ok) "" else "optimizer status or stationarity"
        attempts[[length(attempts) + 1L]] <- data.frame(
          solver = solver, start = i,
          first_status = if (is.null(run$first_status)) NA_integer_ else run$first_status,
          status = run$status, accepted = ok, nll = if (is.null(e)) NA_real_ else e$value,
          stationarity = stationarity, reason = reason
        )
        attempt_recorded <- TRUE
        if (ok) candidates[[length(candidates) + 1L]] <- list(theta = run$theta, value = e$value)
      }
    }
  }, error = function(error) {
    if (!attempt_recorded) {
      completed <- Filter(function(call) identical(call$solver, solver) && identical(call$start, i), call_log$calls)
      status <- if (length(completed)) completed[[length(completed)]]$status else NA_integer_
      attempts[[length(attempts) + 1L]] <- data.frame(
        solver = solver, start = i, first_status = first_status, status = status,
        accepted = FALSE, nll = NA_real_, stationarity = NA_real_, reason = conditionMessage(error)
      )
    }
    error$attempts <- if (length(attempts)) do.call(rbind, attempts) else NULL
    error$solver_calls <- call_log$calls
    stop(error)
  })
  attempts <- do.call(rbind, attempts)
  # Every post-solver rejection retains the completed attempt ledger, including
  # errors raised inside geometry, Hessian differentiation or matrix inversion.
  tryCatch(
    {
      if (!all(c("slsqp", "nlminb") %in% attempts$solver[attempts$accepted])) {
        error <- structure(list(
          message = "no accepted candidate for each optimizer", call = NULL,
          attempts = attempts
        ), class = c("medfit_sem_fiml_error", "error", "condition"))
        stop(error)
      }
      spread <- diff(range(attempts$nll[attempts$accepted])) / p$n
      if (spread > 1e-8) .sem_fiml_diagnostic("accepted optimizer likelihoods disagree")
      best <- candidates[[which.min(vapply(candidates, `[[`, numeric(1), "value"))]]
      theta <- stats::setNames(best$theta, ram$par_names)
      # Observable-moment geometry diagnoses local rank; this is NOT an
      # expected-information SE calculation or a global identification claim.
      geometry <- .sem_fiml_geometry(theta, p)
      geometry_scaled <- geometry / sqrt(outer(diag(geometry), diag(geometry)))
      if (any(diag(geometry) <= 0) || min(eigen(geometry_scaled, symmetric = TRUE)$values) < .sem_singular_tol) {
        .sem_fiml_diagnostic("observed-pattern moment Jacobian is rank deficient")
      }
      H <- .sem_fiml_hessian(theta, p)
      scaled <- H / sqrt(outer(diag(H), diag(H)))
      if (any(!is.finite(scaled)) || any(diag(H) <= 0) ||
            min(eigen(scaled, symmetric = TRUE)$values) < .sem_singular_tol) {
        .sem_fiml_diagnostic("unidentified or ill-conditioned observed information")
      }
      V <- p$transport %*% solve(H) %*% t(p$transport)
      estimate <- p$offset + as.vector(p$transport %*% theta)
      names(estimate) <- ram$par_names
      list(
        kind = "fiml_candidate", estimate = estimate, covariance = V,
        se = stats::setNames(sqrt(diag(V)), ram$par_names), theta = theta, H = H,
        nll = best$value + p$jacobian, attempts = attempts, calls = call_log$calls, spread = spread, prepared = p
      )
    },
    error = function(error) {
      error$attempts <- attempts
      error$solver_calls <- call_log$calls
      stop(error)
    }
  )
}
