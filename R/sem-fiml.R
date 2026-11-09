# Bounded three-variable Gaussian FIML numerical kernel.
# Pattern summaries use ML divisors; all-empty rows contribute no likelihood.
.sem_fiml_diagnostic <- function(reason) {
  stop(structure(list(message = reason, call = NULL),
    class = c("medfit_sem_fiml_error", "error", "condition")
  ))
}
# j mediators in parallel (FI-G2, j = 1 or 2): X -> M_i -> Y with an optional direct path, independent disturbances
# (no residual covariance). Variable order X, M1, ..., Mj, Y; the single mediator keeps the names M, a, b, vm, im.
# Labels: a1..aj, b1..bj, cp, vx, vm1..vmj, vy, ix, im1..imj, iy for j = 2.
.sem_fiml_med_names <- function(j) {
  if (!is.numeric(j) || length(j) != 1L || !j %in% 1:2) .sem_fiml_diagnostic("unsupported number of FIML mediators")
  if (j == 1L) "M" else paste0("M", seq_len(j))
}
# `residual_covariance = TRUE` (FI-G2 slice 2, j = 2 only) adds one free covariance between the two mediator
# disturbances (label cm12) after the variances; FALSE keeps the independent-disturbance tables exactly.
# `k` (FI-G2 slices 3 and 4, j = 2 only) adds k observed covariates: see `.sem_fiml_tables_parcov()`.
.sem_fiml_tables_med <- function(j, direct, residual_covariance = FALSE, k = 0L) {
  if (!is.logical(residual_covariance) || length(residual_covariance) != 1L || is.na(residual_covariance) ||
        (residual_covariance && j != 2L)) {
    .sem_fiml_diagnostic("unsupported FIML residual covariance")
  }
  if (!is.numeric(k) || length(k) != 1L || is.na(k) || k < 0L || (k > 0L && j != 2L)) {
    .sem_fiml_diagnostic("unsupported number of FIML covariates")
  }
  if (k > 0L) return(.sem_fiml_tables_parcov(k, direct, residual_covariance))
  m <- .sem_fiml_med_names(j)
  sfx <- if (j == 1L) "" else as.character(seq_len(j))
  a <- data.frame(
    row = c(m, rep("Y", j), "Y"), col = c(rep("X", j), m, "X"),
    label = c(paste0("a", sfx), paste0("b", sfx), "cp"), value = c(rep(NA, 2L * j), if (direct) NA else 0)
  )
  vars <- c("X", m, "Y")
  s <- data.frame(
    row = vars, col = vars, label = c("vx", paste0("vm", sfx), "vy"), value = NA_real_
  )
  if (residual_covariance) {
    s <- rbind(s, data.frame(row = m[1L], col = m[2L], label = "cm12", value = NA_real_))
  }
  mu <- data.frame(row = vars, label = c("ix", paste0("im", sfx), "iy"), value = NA_real_)
  list(vars = vars, a = a, s = s, m = mu)
}
# Two parallel mediators with k observed covariates (k = 1 or 2): X and the covariates are jointly Gaussian exogenous
# variables (free covariance for every pair); every one of them has a path to M1, to M2 and to Y, with the X -> Y path
# free or fixed exactly at zero; independent mediator disturbances, or one free covariance cm12 between them. Kernel
# order X, Z, M1, M2, Y for k = 1 and X, Z1, ..., Zk, M1, M2, Y otherwise. Labels: a1 a2 (X -> M_j), gm<j>z<i>
# (covariate i -> M_j), b1 b2, cp, gy (gy1, gy2 for k = 2: covariate i -> Y), vx, vz, vm1, vm2, vy, the exogenous
# covariances cxz (cxz1, cxz2, cz1z2), cm12, then the intercepts ix, iz, im1, im2, iy; the covariate labels carry the
# index for k = 2 (vz1, iz2).
.sem_fiml_tables_parcov <- function(k, direct, residual_covariance) {
  nm <- .sem_fiml_cov_names(k)
  z <- nm$z
  m <- c("M1", "M2")
  a <- data.frame(
    row = c(m, rep(m, k), "Y", "Y", "Y", rep("Y", k)), col = c(rep("X", 2L), rep(z, each = 2L), m, "X", z),
    label = c(
      "a1", "a2", paste0("gm", rep(1:2, k), "z", rep(seq_len(k), each = 2L)), "b1", "b2", "cp", paste0("gy", nm$sfx)
    ),
    value = c(rep(NA, 2L + 2L * k + 2L), if (direct) NA else 0, rep(NA, k))
  )
  vars <- c("X", z, m, "Y")
  e <- c("X", z)
  pairs <- utils::combn(e, 2L)
  s <- data.frame(
    row = c(vars, pairs[1L, ]), col = c(vars, pairs[2L, ]),
    label = c("vx", paste0("vz", nm$sfx), "vm1", "vm2", "vy", paste0("c", tolower(pairs[1L, ]), tolower(pairs[2L, ]))),
    value = NA_real_
  )
  if (residual_covariance) s <- rbind(s, data.frame(row = "M1", col = "M2", label = "cm12", value = NA_real_))
  mu <- data.frame(row = vars, label = c("ix", paste0("iz", nm$sfx), "im1", "im2", "iy"), value = NA_real_)
  list(vars = vars, a = a, s = s, m = mu)
}
# Two serial mediators (FI-G3): X -> M1 -> M2 -> Y with independent disturbances and k = 0, 1 or 2 observed covariates.
# `shortcuts = TRUE` is the saturated forward graph (the rows M2 <- X, label a2, and Y <- M1, label b1, are free);
# `shortcuts = FALSE` is the pure chain: those two rows are absent, not fixed at zero. `direct` frees or fixes at
# exactly zero the Y <- X row. Every covariate has a path to M1, M2 and Y, and the exogenous variables are jointly
# Gaussian with a free covariance for every pair. There is no free residual covariance among M1, M2 and Y. Kernel
# order X, [Z], M1, M2, Y. Labels: a, a2, d1, b1, b, cp, gm1z<i> and gm2z<i> (covariate i -> M1, M2), gy (gy1, gy2)
# for the covariate Y paths, vx, vz, vm1, vm2, vy, the exogenous covariances cxz (cxz1, cxz2, cz1z2), ix, iz, im1, im2,
# iy. The parameter count is 13 + 5k + choose(k + 1, 2) + direct for the saturated graph and
# 11 + 5k + choose(k + 1, 2) + direct for the chain.
.sem_fiml_tables_ser <- function(direct, k, shortcuts) {
  if (!is.logical(direct) || length(direct) != 1L || is.na(direct) ||
        !is.logical(shortcuts) || length(shortcuts) != 1L || is.na(shortcuts)) {
    .sem_fiml_diagnostic("unsupported FIML serial setting")
  }
  if (!is.numeric(k) || length(k) != 1L || is.na(k) || !k %in% 0:2) {
    .sem_fiml_diagnostic("unsupported number of FIML covariates")
  }
  nm <- if (k > 0L) .sem_fiml_cov_names(k) else list(z = character(), sfx = character())
  z <- nm$z
  path <- function(row, col, label, value = NA_real_) data.frame(row = row, col = col, label = label, value = value)
  a <- rbind(
    path("M1", "X", "a"),
    if (shortcuts) path("M2", "X", "a2"),
    if (k > 0L) {
      path(rep(c("M1", "M2"), k), rep(z, each = 2L), paste0("gm", rep(1:2, k), "z", rep(seq_len(k), each = 2L)))
    },
    path("M2", "M1", "d1"),
    if (shortcuts) path("Y", "M1", "b1"),
    path("Y", "M2", "b"),
    path("Y", "X", "cp", if (direct) NA_real_ else 0),
    if (k > 0L) path("Y", z, paste0("gy", nm$sfx))
  )
  vars <- c("X", z, "M1", "M2", "Y")
  e <- c("X", z)
  if (k > 0L) pairs <- utils::combn(e, 2L)
  s <- data.frame(
    row = c(vars, if (k > 0L) pairs[1L, ]), col = c(vars, if (k > 0L) pairs[2L, ]),
    label = c(
      "vx", if (k > 0L) paste0("vz", nm$sfx), "vm1", "vm2", "vy",
      if (k > 0L) paste0("c", tolower(pairs[1L, ]), tolower(pairs[2L, ]))
    ),
    value = NA_real_
  )
  m <- data.frame(row = vars, label = c("ix", if (k > 0L) paste0("iz", nm$sfx), "im1", "im2", "iy"), value = NA_real_)
  list(vars = vars, a = a, s = s, m = m)
}
.sem_fiml_tables <- function(direct) .sem_fiml_tables_med(1L, direct)
# k observed covariates (FI-G1, k = 1 or 2): X and the covariates are jointly Gaussian exogenous variables (free
# covariance for every pair); every one of them has a path to M and to Y, with the X -> Y path free or fixed exactly at
# zero. Variable order X, Z, M, Y for k = 1 and X, Z1, ..., Zk, M, Y otherwise. Labels: a, gm, b, cp, gy, vx, vz, vm,
# vy, cxz, ix, iz, im, iy for k = 1; the covariate labels carry the index (gm1, gy2, vz1, cxz1, cz1z2, iz2) for k = 2.
.sem_fiml_cov_names <- function(k) {
  if (!is.numeric(k) || length(k) != 1L || !k %in% 1:2) .sem_fiml_diagnostic("unsupported number of FIML covariates")
  list(z = if (k == 1L) "Z" else paste0("Z", seq_len(k)), sfx = if (k == 1L) "" else as.character(seq_len(k)))
}
.sem_fiml_tables_cov <- function(k, direct) {
  nm <- .sem_fiml_cov_names(k)
  z <- nm$z
  sfx <- nm$sfx
  a <- data.frame(
    row = c("M", rep("M", k), "Y", "Y", rep("Y", k)), col = c("X", z, "M", "X", z),
    label = c("a", paste0("gm", sfx), "b", "cp", paste0("gy", sfx)),
    value = c(NA, rep(NA, k), NA, if (direct) NA else 0, rep(NA, k))
  )
  vars <- c("X", z, "M", "Y")
  e <- c("X", z)
  pairs <- utils::combn(e, 2L)
  s <- data.frame(
    row = c(vars, pairs[1L, ]), col = c(vars, pairs[2L, ]),
    label = c("vx", paste0("vz", sfx), "vm", "vy", paste0("c", tolower(pairs[1L, ]), tolower(pairs[2L, ]))),
    value = NA_real_
  )
  m <- data.frame(row = vars, label = c("ix", paste0("iz", sfx), "im", "iy"), value = NA_real_)
  list(vars = vars, a = a, s = s, m = m)
}
.sem_fiml_tables_cov1 <- function(direct) .sem_fiml_tables_cov(1L, direct)
.sem_fiml_ram <- function(direct) {
  t <- .sem_fiml_tables(direct)
  .sem_ram(t$vars, t$vars, t$a, t$s, t$m)
}
# Parameter layout read off the RAM tables: which free parameter is a path (response, predictor), a variance or
# an intercept; a free off-diagonal (co)variance is a covariance. Free entries must carry unique non-empty labels,
# which are then the parameter names.
.sem_fiml_layout <- function(tables) {
  free <- function(x) x[is.na(x$value), , drop = FALSE]
  a <- free(tables$a)
  s <- free(tables$s)
  m <- free(tables$m)
  stopifnot(all(nzchar(c(a$label, s$label, m$label))), !anyDuplicated(c(a$label, s$label, m$label)))
  diagonal <- s$row == s$col
  list(
    vars = tables$vars,
    paths = data.frame(par = a$label, response = a$row, predictor = a$col),
    variances = data.frame(par = s$label[diagonal], var = s$row[diagonal]),
    covariances = data.frame(par = s$label[!diagonal], row = s$row[!diagonal], col = s$col[!diagonal]),
    intercepts = data.frame(par = m$label, var = m$row)
  )
}
# Linear affine transport from standardized structural coordinates: original = offset + transport %*% theta.
# A path scales by scale_response / scale_predictor, a variance by scale^2, a covariance by the product of the two
# scales, an intercept by scale; an intercept
# also absorbs -center_predictor times the scaled path of every free path into its response.
.sem_fiml_transport <- function(layout, par_names, center, scale) {
  offset <- stats::setNames(rep(0, length(par_names)), par_names)
  units <- stats::setNames(rep(1, length(par_names)), par_names)
  i <- layout$intercepts
  v <- layout$variances
  a <- layout$paths
  cv <- layout$covariances
  offset[i$par] <- center[i$var]
  units[i$par] <- scale[i$var]
  units[v$par] <- scale[v$var]^2
  units[cv$par] <- scale[cv$row] * scale[cv$col]
  units[a$par] <- scale[a$response] / scale[a$predictor]
  transport <- diag(unname(units))
  dimnames(transport) <- list(par_names, par_names)
  for (k in seq_len(nrow(layout$paths))) {
    path <- layout$paths[k, ]
    r <- match(path$response, layout$intercepts$var)
    if (is.na(r)) next
    transport[layout$intercepts$par[r], path$par] <- -center[path$predictor] * units[path$par]
  }
  list(units = units, offset = offset, transport = transport)
}
# The bounded public entry: only the X -> M -> Y tables (direct path free or fixed at zero) are ever passed on.
.sem_fiml_prepare <- function(data, direct = TRUE, fixed_x = FALSE,
                              row_id = seq_len(nrow(data)), ...) {
  if (length(list(...)) || !identical(fixed_x, FALSE) ||
        !is.logical(direct) || length(direct) != 1L || is.na(direct)) {
    .sem_fiml_diagnostic("unsupported FIML setting")
  }
  .sem_fiml_prepare_core(data, .sem_fiml_tables(direct), row_id, direct)
}
# Dimension-generic preparation: the observed variables, parameters and transport come from `tables`.
.sem_fiml_prepare_core <- function(data, tables, row_id = seq_len(nrow(data)), direct = NA) {
  if (!is.matrix(data) || !is.numeric(data) || ncol(data) != length(tables$vars) ||
        !identical(colnames(data), tables$vars) ||
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
  ram <- .sem_ram(tables$vars, tables$vars, tables$a, tables$s, tables$m)
  layout <- .sem_fiml_layout(tables)
  names0 <- ram$par_names
  tr <- .sem_fiml_transport(layout, names0, center, scale)
  units <- tr$units
  offset <- tr$offset
  transport <- tr$transport
  retained <- rowSums(!is.na(data)) > 0L
  list(
    ram = ram, layout = layout, groups = groups, standardized = z, direct = direct,
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
  v <- .sem_fiml_variance_index(p$layout, p$ram$par_names)
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
# Positions of the variance parameters, the only parameters with a positive lower bound and a capped Hessian step.
.sem_fiml_variance_index <- function(layout, par_names) match(layout$variances$par, par_names)
# Three fixed starts: zeros with unit variances, then two deterministic perturbations of it.
.sem_fiml_starts <- function(layout, par_names) {
  initial <- stats::setNames(rep(0, length(par_names)), par_names)
  initial[layout$variances$par] <- 1
  list(
    initial, initial + .12 * sin(seq_along(initial)),
    initial - .15 * cos(seq_along(initial))
  )
}
.sem_fiml_lower <- function(layout, par_names) {
  lower <- rep(-Inf, length(par_names))
  lower[.sem_fiml_variance_index(layout, par_names)] <- 1e-10
  lower
}
.sem_fiml_fit <- function(data, direct = TRUE, fixed_x = FALSE,
                          row_id = seq_len(nrow(data)), ...) {
  .sem_fiml_solve(.sem_fiml_prepare(data, direct, fixed_x, row_id, ...))
}
# Dimension-generic solve, acceptance gates, transport of the estimate and covariance for a prepared object.
.sem_fiml_solve <- function(p) {
  ram <- p$ram
  starts <- .sem_fiml_starts(p$layout, ram$par_names)
  lower <- .sem_fiml_lower(p$layout, ram$par_names)
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
                list(s = diag(length(p$layout$vars))), lower, rep(Inf, ram$q),
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
