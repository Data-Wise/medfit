# Native SEM engine: constraints.
#
# Internal. A constraint line (`==`, `<`, `>` from the parser's constraint table)
# that is provably linear in the parameter labels becomes one row `a'theta + b`,
# normalized to unit length: equalities `a'theta + b = 0` and inequalities
# `a'theta + b <= 0` (a `>` constraint is negated). Rows are constant, so the
# solver gets constant Jacobians and one solve suffices (spec 4.5a, 4.5b). A
# nonlinear equality (`a*b == c`) becomes a closure over the validated call tree: its value is
# `lhs - rhs` and its Jacobian a central difference, both recomputed at every point (`$nl`). A nonlinear
# inequality (`a*b > 0.1`, `ab > 0` with `ab := a*b`) is the same closure with the sign chosen so that the
# row reads `c(theta) <= 0` (`$nli`). Defined parameters (`:=`) are substituted before the linearity walk.

# Rows for the constraints in `constraints` (the parser's table, `:=` rows
# included as definitions). Returns NULL when there is nothing to enforce.
.sem_constraint_rows <- function(constraints, ram) {
  defs <- constraints[constraints$op == ":=", , drop = FALSE]
  cons <- constraints[constraints$op %in% c("==", "<", ">"), , drop = FALSE]
  if (!nrow(cons)) {
    return(NULL)
  }
  defs <- .sem_defs(stats::setNames(defs$rhs, defs$lhs))
  rows <- vector("list", nrow(cons))
  nl <- list()
  nli <- list()
  for (i in seq_len(nrow(cons))) {
    text <- paste(cons$lhs[i], cons$op[i], cons$rhs[i])
    tree <- .sem_expr_subst(.sem_expr_parse(paste0("(", cons$lhs[i], ") - (", cons$rhs[i], ")")), defs)
    labels <- all.vars(tree)
    if (!length(labels)) {
      stop("constraint contains no parameters: '", text, "'", call. = FALSE)
    }
    nonlinear <- !.sem_tree_linear(tree)
    idx <- match(labels, ram$par_names)
    if (anyNA(idx)) {
      stop("constraint '", text, "' refers to '", labels[is.na(idx)][1L], "', which is not a free parameter",
           call. = FALSE)
    }
    if (nonlinear) {
      # `lhs - rhs`: an equality as it is, `<` as it is (<= 0), `>` negated (the row reads c <= 0)
      row <- list(tree = tree, labels = labels, idx = idx, text = text, sign = if (cons$op[i] == ">") -1 else 1)
      if (cons$op[i] == "==") nl[[length(nl) + 1L]] <- row else nli[[length(nli) + 1L]] <- row
      next
    }
    zero <- stats::setNames(numeric(length(labels)), labels)
    b <- .sem_expr_value(tree, zero, text)
    a <- numeric(ram$q)
    for (k in seq_along(labels)) {
      unit <- zero
      unit[[k]] <- 1
      a[idx[k]] <- .sem_expr_value(tree, unit, text) - b
    }
    if (cons$op[i] == ">") {
      a <- -a
      b <- -b
    }
    len <- sqrt(sum(a^2))
    if (len < 1e-12) {
      stop("constraint contains no parameters: '", text, "'", call. = FALSE)
    }
    rows[[i]] <- list(a = a / len, b = b / len, op = cons$op[i], text = text)
  }
  rows <- Filter(Negate(is.null), rows)
  pick <- function(eq) {
    keep <- Filter(function(r) (r$op == "==") == eq, rows)
    list(
      A = if (length(keep)) do.call(rbind, lapply(keep, `[[`, "a")) else matrix(0, 0L, ram$q),
      b = vapply(keep, `[[`, 1, "b"),
      text = vapply(keep, `[[`, "", "text")
    )
  }
  list(eq = pick(TRUE), ineq = pick(FALSE), nl = .sem_nl_rows(nl, ram$q), nli = .sem_nl_rows(nli, ram$q))
}

# Nonlinear rows (equalities, or inequalities in the form c <= 0) as one object: `text`, `value(theta)` (the
# vector of c), `jac(theta, u)` (a row per constraint, a column per parameter, by central differences with
# step eps^(1/3) * max(|theta_k|, u_k), u_k the parameter's natural unit; only the labels a row uses are
# perturbed) and `hess(theta, u)` (the list of the rows' second-derivative matrices, central differences of
# the Jacobian, used for the curvature of the Lagrangian in the acceptance gate). Evaluation goes through the
# guarded evaluator, so a value that is not one finite real number is an error naming the point, not a NaN
# inside the solver. `idx` lists the parameters the rows use. NULL when there are none.
.sem_nl_rows <- function(nl, q) {
  if (!length(nl)) {
    return(NULL)
  }
  value_one <- function(row, theta) {
    row$sign * .sem_expr_value(row$tree, stats::setNames(theta[row$idx], row$labels), row$text)
  }
  step <- function(theta, u, k) .Machine$double.eps^(1 / 3) * max(abs(theta[k]), u[k])
  jac_one <- function(row, theta, u) {
    out <- numeric(q)
    for (k in row$idx) {
      h <- step(theta, u, k)
      up <- dn <- theta
      up[k] <- theta[k] + h
      dn[k] <- theta[k] - h
      out[k] <- (value_one(row, up) - value_one(row, dn)) / (2 * h)
    }
    out
  }
  list(
    text = vapply(nl, `[[`, "", "text"),
    # the parameters (indices) the rows use: the solver floors the variances among them (#213)
    idx = sort(unique(unlist(lapply(nl, `[[`, "idx")))),
    value = function(theta) vapply(nl, value_one, numeric(1), theta = theta),
    jac = function(theta, u) {
      out <- matrix(0, length(nl), q)
      for (i in seq_along(nl)) {
        out[i, ] <- jac_one(nl[[i]], theta, u)
      }
      out
    },
    hess = function(theta, u) {
      lapply(nl, function(row) {
        h2 <- matrix(0, q, q)
        for (k in row$idx) {
          h <- step(theta, u, k)
          up <- dn <- theta
          up[k] <- theta[k] + h
          dn[k] <- theta[k] - h
          h2[, k] <- (jac_one(row, up, u) - jac_one(row, dn, u)) / (2 * h)
        }
        (h2 + t(h2)) / 2
      })
    }
  )
}

# Zero products (T14). `a*b == 0` is true exactly when `a == 0` or `b == 0`, so a product of labels set to
# zero is solved as one linear refit per factor and the smallest discrepancy wins: no nonlinear solve, whose
# Jacobian (b, a) vanishes at the solution and whose local optimum can be the larger branch (OpenMx lands at
# 221.05 on `memory_exp` where the minimum is 0.083). A row qualifies when it is an equality with a literal 0
# on one side and, on the other side (defined names substituted), a product of labels and constants that is
# not already linear: `a*b`, `b1*b2*b3`, `-2*a*b`, `(a*b)*c`, `a*b/2`. Returns, per qualifying row of
# `constraints`, its index and the distinct labels of the product, or an empty list.
.sem_product_factors <- function(e) {
  if (is.numeric(e) && length(e) == 1L) {
    return(if (e == 0) NULL else character())
  }
  if (is.symbol(e)) {
    return(as.character(e))
  }
  if (!is.call(e)) {
    return(NULL)
  }
  a <- as.list(e)[-1L]
  fac <- switch(as.character(e[[1L]]),
    `(` = .sem_product_factors(a[[1L]]),
    `-` = if (length(a) == 1L) .sem_product_factors(a[[1L]]),
    `*` = {
      parts <- lapply(a, .sem_product_factors)
      if (!any(vapply(parts, is.null, TRUE))) unlist(parts)
    },
    `/` = if (length(all.vars(a[[2L]])) == 0L && .sem_product_nonzero(a[[2L]])) .sem_product_factors(a[[1L]])
  )
  if (is.null(fac)) NULL else as.character(fac)
}

# The value of a constant expression (no labels), or NA when it is not one finite number.
.sem_constant_value <- function(e) {
  if (length(all.vars(e))) {
    return(NA_real_)
  }
  tryCatch(.sem_expr_value(e, numeric()), error = function(err) NA_real_)
}

.sem_product_nonzero <- function(e) {
  v <- .sem_constant_value(e)
  !is.na(v) && v != 0
}

.sem_zero_product_rows <- function(constraints) {
  defs <- constraints[constraints$op == ":=", , drop = FALSE]
  defs <- .sem_defs(stats::setNames(defs$rhs, defs$lhs))
  out <- list()
  for (i in which(constraints$op == "==")) {
    zero <- function(x) identical(.sem_constant_value(.sem_expr_parse(x)), 0)
    side <- if (zero(constraints$rhs[i])) constraints$lhs[i] else if (zero(constraints$lhs[i])) constraints$rhs[i]
    if (is.null(side)) {
      next
    }
    tree <- .sem_expr_subst(.sem_expr_parse(side), defs)
    if (!is.call(tree) || .sem_tree_linear(tree)) {
      next
    }
    fac <- .sem_product_factors(tree)
    if (length(fac)) {
      out[[length(out) + 1L]] <- list(row = i, factors = unique(fac))
    }
  }
  out
}

# The empty constraint set, for code that always wants a `cons` list.
.sem_no_cons <- function(q) {
  none <- list(A = matrix(0, 0L, q), b = numeric(), text = character())
  list(eq = none, ineq = none, nl = NULL, nli = NULL)
}

# Residual of the constraints at `theta`: equalities in absolute value, inequalities
# by how far they are violated (zero when satisfied). Linear rows are unit length, so
# their residual is in parameter units; a nonlinear row's is the raw value of `lhs - rhs`.
.sem_constraint_residual <- function(theta, cons) {
  if (is.null(cons)) {
    return(numeric())
  }
  c(
    if (nrow(cons$eq$A)) abs(as.vector(cons$eq$A %*% theta) + cons$eq$b),
    if (!is.null(cons$nl)) abs(cons$nl$value(theta)),
    if (nrow(cons$ineq$A)) pmax(0, as.vector(cons$ineq$A %*% theta) + cons$ineq$b),
    if (!is.null(cons$nli)) pmax(0, cons$nli$value(theta))
  )
}

# Rank of the equality rows: how many free parameters the equalities remove. A dependent row (a duplicate,
# `a == b` with `b == a`) removes none, so this is not the row count.
.sem_rank_tol <- 1e-8
.sem_eq_rank <- function(eq) {
  if (is.null(eq) || nrow(eq$A) == 0L) {
    return(0L)
  }
  qr(t(eq$A), tol = .sem_rank_tol)$rank
}

# The same count with the nonlinear equalities included: the rank of the stacked equality gradients at
# `theta`, each row of unit length in the solver's natural units (a nonlinear row's gradient is that of the
# linearization there, so its rank is the number of parameters the equalities remove locally). A start
# or solution where a Jacobian vanishes (`a*b == c` at a = b = 0 still has the -1 for c; `a*b == 0` does not)
# counts that row as removing nothing.
.sem_eq_rank_at <- function(cons, theta, u) {
  if (is.null(cons)) {
    return(0L)
  }
  rows <- rbind(sweep(cons$eq$A, 2L, u, "*"),
                if (!is.null(cons$nl)) sweep(cons$nl$jac(theta, u), 2L, u, "*"))
  len <- sqrt(rowSums(rows^2))
  rows <- rows[len > 1e-12, , drop = FALSE] / len[len > 1e-12]
  if (!nrow(rows)) {
    return(0L)
  }
  qr(t(rows), tol = .sem_rank_tol)$rank
}

# The equality rows the solver can be given: an independent subset, in the original order. A linearly
# dependent set (a duplicate, `a == b` with `b == a`, a transitive triple) gives SLSQP a rank-deficient
# Jacobian and it stops with status -4, although the constraints are consistent. A dependent row dropped here
# is still checked by the acceptance gate, which uses every row, so contradictory constraints (`a == 1` with
# `a == 2`) are still reported as violated. Rows are unit length, so the rank tolerance is in angle terms
# and matches the one the sign check uses.
.sem_independent_rows <- function(eq) {
  if (nrow(eq$A) < 2L) {
    return(eq)
  }
  dec <- qr(t(eq$A), tol = .sem_rank_tol)
  if (dec$rank == nrow(eq$A)) {
    return(eq)
  }
  keep <- sort(dec$pivot[seq_len(dec$rank)])
  list(A = eq$A[keep, , drop = FALSE], b = eq$b[keep], text = eq$text[keep])
}

# An inequality row is implied by the equalities when its gradient lies in the span of the independent equality
# gradients: the residual after projection onto that span is below `.sem_implied_tol`. Its value on the equality
# set is then a constant. A row that holds there (constant at most `.sem_implied_slack`) is active at every
# feasible point, so it hands SLSQP a rank-deficient active Jacobian (`a == b` with `a - b < 0`), the same
# degeneracy `.sem_independent_rows()` removes for equality rows; it is dropped from the solver's rows and the
# acceptance gate, which uses every row, still checks it. A row the equalities violate is KEPT: the solve
# proceeds and the gate reports it, because near-dependence is not proof of infeasibility (`a - b + 1e-9*cp >
# 1e-7` with `a == b` is feasible at large `cp`, so an up-front error could reject a feasible model). The
# tolerance is far tighter than the 1e-8 equality rank tolerance, at the level of floating-point noise, so only
# rows that are dependent to rounding (`2*a + 2*b`) are dropped. Rows are unit length; `eq` is the independent
# subset from `.sem_independent_rows()`.
.sem_implied_tol <- 1e-12
.sem_implied_slack <- 1e-8
.sem_drop_implied_ineq <- function(ineq, eq) {
  if (!nrow(ineq$A) || !nrow(eq$A)) {
    return(ineq)
  }
  dec <- qr(t(eq$A), tol = .sem_rank_tol)
  r <- dec$rank
  q_eq <- qr.Q(dec)[, seq_len(r), drop = FALSE]
  resid <- ineq$A - (ineq$A %*% q_eq) %*% t(q_eq)
  implied <- sqrt(rowSums(resid^2)) < .sem_implied_tol
  if (!any(implied)) {
    return(ineq)
  }
  # The minimum-norm point of the equality set, from the QR factors (t(A)[, piv] = Q R, so A[piv, ] = R' Q'):
  # no normal equations, which would square the condition number of nearly dependent rows.
  piv <- dec$pivot[seq_len(r)]
  theta0 <- as.vector(q_eq %*% forwardsolve(t(qr.R(dec)[seq_len(r), seq_len(r), drop = FALSE]), -eq$b[piv]))
  drop <- implied & (as.vector(ineq$A %*% theta0) + ineq$b <= .sem_implied_slack)
  if (!any(drop)) {
    return(ineq)
  }
  list(A = ineq$A[!drop, , drop = FALSE], b = ineq$b[!drop], text = ineq$text[!drop])
}

# nloptr arguments for the rows in the solver's coordinates x = theta / u: the
# Jacobian of a linear row is the row scaled by u, constant; a nonlinear equality's is recomputed
# at every point.
.sem_nlopt_constraints <- function(cons, u) {
  if (is.null(cons)) {
    return(NULL)
  }
  out <- list()
  eq <- .sem_independent_rows(cons$eq)
  ineq <- .sem_drop_implied_ineq(cons$ineq, eq)
  # One binding per block: the closures capture this environment, so a shared name would let the
  # inequality rows replace the equality Jacobian.
  nl <- cons$nl
  if (nrow(eq$A) || !is.null(nl)) {
    jac_eq <- sweep(eq$A, 2L, u, "*")
    # the linear rows first, then the nonlinear ones, in the solver's coordinates x = theta / u
    out$eval_g_eq <- function(x) c(as.vector(jac_eq %*% x) + eq$b, if (!is.null(nl)) nl$value(x * u))
    out$eval_jac_g_eq <- function(x) rbind(jac_eq, if (!is.null(nl)) sweep(nl$jac(x * u, u), 2L, u, "*"))
  }
  nli <- cons$nli
  if (nrow(ineq$A) || !is.null(nli)) {
    jac_ineq <- sweep(ineq$A, 2L, u, "*")
    out$eval_g_ineq <- function(x) c(as.vector(jac_ineq %*% x) + ineq$b, if (!is.null(nli)) nli$value(x * u))
    out$eval_jac_g_ineq <- function(x) rbind(jac_ineq, if (!is.null(nli)) sweep(nli$jac(x * u, u), 2L, u, "*"))
  }
  out
}

# Acceptance of a constrained solution (plan S14, Q14), in the solver's natural
# units x = theta / u so that nothing depends on the units of the data:
#   1. nloptr status 1, 3 or 4;
#   2. every constraint holds to .sem_constraint_tol, measured as the distance to
#      the constraint in natural units (|c| / ||a * u||);
#   3. the Newton decrement on the reduced Hessian of the active-constraint null
#      space is at most .sem_stat_tol, the reduced Hessian is positive definite and
#      its Jacobi-scaled smallest eigenvalue is at least .sem_singular_tol.
# Active equalities, active inequalities (as equalities) and active bounds
# define the null space; bound-active coordinates are eliminated first, so a fit
# with bounds only reduces to the coordinate subset the unconstrained gate uses.
# The sign of each active inequality's and each active bound's multiplier gets a
# warn-only check: the fit is never rejected for it (grill-8, D8, D14).
.sem_constraint_tol <- 1e-6
.sem_sign_tol <- -1e-3
# A bound multiplier slope below this fraction of the natural-unit gradient norm is roundoff, not a wrong sign (#238).
.sem_slope_tol_rel <- 1e-10

# Everything the gate and the covariance need about the active set at `theta`,
# in the solver's natural units x = theta / u. `z` is an orthonormal basis (in x
# coordinates, over the coordinates not at a bound) of the directions that keep
# every active constraint and bound; `z_theta` is the same basis embedded in the
# full parameter vector and mapped back to theta units (zero rows for coordinates
# at a bound). Bound-active coordinates are eliminated first, so a fit with
# bounds only reduces to the coordinate subset the unconstrained gate uses.
.sem_active_set <- function(theta, ram, smp, lb, ub, cons) {
  u <- .sem_step_floor(ram, smp)
  # Linear equalities, then nonlinear equalities (their Jacobian and value at `theta`, so the null space
  # is that of the linearization at the point judged, the solution), then linear inequalities.
  nl <- cons$nl
  nli <- cons$nli
  rows <- rbind(cons$eq$A, if (!is.null(nl)) nl$jac(theta, u), cons$ineq$A, if (!is.null(nli)) nli$jac(theta, u))
  cval <- c(as.vector(cons$eq$A %*% theta) + cons$eq$b, if (!is.null(nl)) nl$value(theta),
            as.vector(cons$ineq$A %*% theta) + cons$ineq$b, if (!is.null(nli)) nli$value(theta))
  is_eq <- c(rep(TRUE, nrow(cons$eq$A) + length(nl$text)), rep(FALSE, nrow(cons$ineq$A) + length(nli$text)))
  text <- c(cons$eq$text, nl$text, cons$ineq$text, nli$text)
  # positions of the nonlinear rows among `rows`, for the curvature of the Lagrangian
  nl_pos <- c(nrow(cons$eq$A) + seq_along(nl$text), nrow(cons$eq$A) + length(nl$text) + nrow(cons$ineq$A) +
                seq_along(nli$text))
  ax <- sweep(rows, 2L, u, "*")
  len <- sqrt(rowSums(ax^2))
  dist <- ifelse(is_eq, abs(cval), pmax(0, cval)) / len
  at_lb <- (theta - lb) / u <= .sem_bound_window
  at_ub <- (ub - theta) / u <= .sem_bound_window
  free <- !(at_lb | at_ub)
  active_row <- is_eq | (cval / len >= -.sem_bound_window)

  g_act <- ax[active_row, free, drop = FALSE]
  g_act <- g_act[sqrt(rowSums(g_act^2)) > 1e-12, , drop = FALSE]
  g_act <- g_act / sqrt(rowSums(g_act^2))
  nf <- sum(free)
  if (nrow(g_act) == 0L) {
    z <- diag(nf)
  } else {
    sv <- svd(g_act, nu = 0L, nv = nf)
    z <- sv$v[, seq_len(nf)[-seq_len(sum(sv$d > 1e-8))], drop = FALSE]
  }
  z_theta <- matrix(0, length(theta), ncol(z))
  z_theta[free, ] <- z * u[free]
  list(u = u, ax = ax, is_eq = is_eq, text = text, dist = dist, at_lb = at_lb, at_ub = at_ub, free = free,
       active_row = active_row, z = z, z_theta = z_theta, nl_pos = nl_pos, cval = cval)
}

.sem_gate_projected <- function(theta, status, ram, smp, lb, ub, cons) {
  out <- list(accepted = FALSE, status = status, decrement = NA_real_, min_eig = NA_real_,
              active = rep(FALSE, length(theta)), reason = "", multipliers = NULL, sign_check = "ok",
              sign_warnings = character())
  act <- .sem_active_set(theta, ram, smp, lb, ub, cons)
  violated <- if (length(act$dist) && any(act$dist > .sem_constraint_tol)) {
    j <- which.max(act$dist)
    sprintf("constraint '%s' is violated by %.2e in natural units", act$text[j], act$dist[j])
  }
  if (!isTRUE(status %in% .sem_ok_status)) {
    out$reason <- paste(c(sprintf("nloptr status %s is not a success code", status), violated), collapse = "; ")
    return(out)
  }
  if (!is.null(violated)) {
    out$reason <- violated
    return(out)
  }
  r <- .sem_eval(theta, ram, smp, deriv = TRUE)
  if (is.null(r)) {
    out$reason <- "implied covariance is not positive definite"
    return(out)
  }
  out$active <- !act$free
  ctr <- .sem_center_map(ram, smp)
  gx <- r$g * act$u
  if (is.null(ctr)) {
    hx <- .sem_hess_f(theta, ram, smp) * outer(act$u, act$u)
  } else {
    # With a mean structure the curvature is built in the centered coordinates phi (see `.sem_center_map()`),
    # where x = Tx xphi + const in the solver's natural units; the plain Hessian is only formed for the sign check.
    tx <- (ctr$t * outer(1 / act$u, act$u))
    hphi <- .sem_hess_f_phi(theta, ram, smp, ctr) * outer(act$u, act$u)
    txi <- solve(tx)
    hx <- crossprod(txi, hphi %*% txi)
  }
  if (!all(is.finite(hx))) {
    out$reason <- "the Hessian is not finite"
    return(out)
  }
  if (ncol(act$z) == 0L) {
    out$decrement <- 0
    out$accepted <- TRUE
  } else {
    free <- act$free
    if (is.null(ctr)) {
      hl <- .sem_lagrangian_hessian(hx, gx, act, cons, theta)
      red <- .sem_reduced_stationarity(crossprod(act$z, hl[free, free, drop = FALSE] %*% act$z),
                                       crossprod(act$z, gx[free]))
    } else {
      hc <- .sem_lagrangian_hessian(matrix(0, length(theta), length(theta)), gx, act, cons, theta)
      hl <- hphi + crossprod(tx, hc %*% tx)
      zf <- matrix(0, length(theta), ncol(act$z))
      zf[free, ] <- act$z
      zq <- qr.Q(qr(solve(tx, zf)))[, seq_len(ncol(zf)), drop = FALSE]
      red <- .sem_reduced_stationarity(crossprod(zq, hl %*% zq), crossprod(zq, crossprod(tx, gx)))
    }
    out$min_eig <- red$min_eig
    out$decrement <- red$decrement
    out$reason <- red$reason
    out$accepted <- red$accepted
  }
  if (out$accepted) {
    out <- .sem_sign_check(out, act$ax, act$active_row, act$is_eq, act$text, act$at_lb, act$at_ub, ram, hx, gx)
    if (length(out$sign_bound)) {
      # same verdict and wording as the unconstrained gate: the gradient at an active bound points inward
      out$accepted <- FALSE
      out$reason <- sprintf("the gradient at an active bound points into the interior (%s)",
                            paste(out$sign_bound, collapse = ", "))
    }
  }
  out
}

# Newton polish of an accepted solution that has an active nonlinear row. SLSQP stops along a flat
# constraint tangent, where the objective moves by less than its `ftol_rel`, so an accepted point can sit
# 1e-5 from the optimum (the stationarity gate allows a decrement of 1e-3). The polish takes full Newton
# steps on the KKT system of the active set, fixed at the accepted point (active rows as equalities,
# coordinates at a bound held),
#   [H_L  M'] [dx]   [-g]
#   [M    0 ] [mu] = [-c],
# in the solver's natural units, with H_L the Lagrangian Hessian (`.sem_lagrangian_hessian()`): on a curved
# row the Hessian of the objective alone is the wrong curvature. An iterate is kept only while the KKT
# merit (the norm of the gradient projected onto the null space of the active rows plus the distance to the
# active rows) falls. Returns the polished `theta`, or NULL when there is nothing to polish or the polish is
# not trustworthy: no active nonlinear row, a vanishing or dependent active row (`a*b == 0` at a = b = 0), a
# singular KKT matrix, an active set that changes, an iterate outside the bounds or a step longer than
# `.sem_polish_reach`. The caller re-runs the acceptance gate on the result.
.sem_polish_maxit <- 8L
.sem_polish_reach <- 1e-2
.sem_polish_rcond <- 1e-13
.sem_polish <- function(theta, ram, smp, lb, ub, cons, reach = .sem_polish_reach) {
  act0 <- .sem_active_set(theta, ram, smp, lb, ub, cons)
  if (!any(act0$active_row[act0$nl_pos])) {
    return(NULL)
  }
  kkt <- function(th) {
    act <- .sem_active_set(th, ram, smp, lb, ub, cons)
    r <- .sem_eval(th, ram, smp, deriv = TRUE)
    if (is.null(r) || !identical(act$active_row, act0$active_row) || !identical(act$free, act0$free)) {
      return(NULL)
    }
    free <- act$free
    m <- act$ax[act$active_row, free, drop = FALSE]
    cval <- act$cval[act$active_row]
    hx <- .sem_hess_f(th, ram, smp) * outer(act$u, act$u)
    gx <- r$g * act$u
    if (!nrow(m) || any(sqrt(rowSums(m^2)) <= 1e-12) || !all(is.finite(c(m, cval, hx, gx)))) {
      return(NULL)
    }
    hl <- .sem_lagrangian_hessian(hx, gx, act, cons, th)[free, free, drop = FALSE]
    k <- nrow(m)
    mat <- rbind(cbind(hl, t(m)), cbind(m, matrix(0, k, k)))
    rc <- tryCatch(rcond(mat), error = function(e) 0)
    if (!is.finite(rc) || rc < .sem_polish_rcond) {
      return(NULL)
    }
    sol <- solve(mat, c(-gx[free], -cval))
    qrm <- qr(t(m))
    proj <- gx[free] - qr.fitted(qrm, gx[free])
    list(step = sol[seq_len(sum(free))], free = free, u = act$u,
         merit = sqrt(sum(proj^2)) + sqrt(sum((cval / sqrt(rowSums(m^2)))^2)))
  }
  cur <- kkt(theta)
  if (is.null(cur)) {
    return(NULL)
  }
  th <- theta
  for (it in seq_len(.sem_polish_maxit)) {
    cand <- th
    cand[cur$free] <- th[cur$free] + cur$step * cur$u[cur$free]
    if (any(cand < lb | cand > ub)) {
      break
    }
    nxt <- kkt(cand)
    if (is.null(nxt) || nxt$merit >= cur$merit) {
      break
    }
    th <- cand
    cur <- nxt
  }
  if (identical(th, theta) || max(abs(th - theta) / cur$u) > reach) {
    return(NULL)
  }
  th
}

# The polished solution replaces the accepted one only if the acceptance gate accepts it again and the
# discrepancy has not risen by more than `.sem_polish_f_slack` (the point it leaves may sit a little off the
# constraint, which lowers the discrepancy by about the multiplier times the violation, so a small rise is
# the polish removing that).
.sem_polish_f_slack <- 1e-8
# Restoring feasibility from a roundoff-limited stall (status -4) may need a long step along a flat direction and
# raises the discrepancy by about the multiplier times the violation, so the reach is wider (#276). The rise is capped
# by the first-order cost of the restoration, `.sem_restore_allowance()`, times `.sem_restore_k`: without a cap the
# acceptance gate (feasibility, stationarity, curvature) alone decided, and a restoration into a feasible, stationary
# but worse point was accepted.
.sem_restore_reach <- 1
# The safety factor on the allowance. Measured: every kept restoration on the #276 fixtures rises by 0.995 to 0.9998
# of the allowance (two OpenBLAS builds), and the ratio is at most about 1 by construction, so 4 leaves a margin well
# above the largest legitimate ratio and well below the gap to an inferior basin (>= 0.25 against `4 * allow` <= 0.06).
# tests/sim/gates.csv (row `restoration`) carries the same number; run-gates.R --fast checks they agree.
.sem_restore_k <- 4
# The allowance of a restoration from a stalled point `theta`: the objective's rise along the minimum-norm step
# `delta = -M^+ c` back onto the linearized active rows, in the quadratic model,
#   |g' delta| + 0.5 |delta' H_L delta|,
# with `M` the active rows' Jacobian on the free coordinates and `c` their values, all in the solver's natural units
# (`.sem_polish()` works there too). With least-squares multipliers `lambda' c = g' delta`, so this is the multipliers
# times the violation without computing them (none exist at a rejected stall). The step is feasible for the Newton
# step's own quadratic problem, so a legitimate restoration cannot cost more than this to second order. Rescaling a row
# rescales `M` and `c` together, a duplicated row leaves the pseudo-inverse step unchanged, and a bound-active
# coordinate is not in `M`. NA when there is nothing to restore onto (no active row), the rows have rank zero or an
# input is not finite: the caller then rejects the restoration (it never accepts on NA).
.sem_restore_allowance <- function(theta, ram, smp, lb, ub, cons) {
  act <- .sem_active_set(theta, ram, smp, lb, ub, cons)
  r <- .sem_eval(theta, ram, smp, deriv = TRUE)
  free <- act$free
  m <- act$ax[act$active_row, free, drop = FALSE]
  cval <- act$cval[act$active_row]
  if (is.null(r) || !nrow(m)) {
    return(NA_real_)
  }
  hx <- .sem_hess_f(theta, ram, smp) * outer(act$u, act$u)
  gx <- r$g * act$u
  if (!all(is.finite(c(m, cval, hx, gx)))) {
    return(NA_real_)
  }
  sv <- svd(m)
  keep <- sv$d > 1e-8 * max(sv$d)
  if (!any(keep)) {
    return(NA_real_)
  }
  delta <- -drop(sv$v[, keep, drop = FALSE] %*% (crossprod(sv$u[, keep, drop = FALSE], cval) / sv$d[keep]))
  hl <- .sem_lagrangian_hessian(hx, gx, act, cons, theta)[free, free, drop = FALSE]
  curv <- 0.5 * abs(drop(crossprod(delta, hl %*% delta)))
  abs(sum(gx[free] * delta)) + curv
}
.sem_polish_accept <- function(res, gate, ram, smp, lb, ub, cons, restore = FALSE) {
  pol <- .sem_polish(res$solution, ram, smp, lb, ub, cons,
                     reach = if (restore) .sem_restore_reach else .sem_polish_reach)
  if (is.null(pol)) {
    return(list(res = res, gate = gate))
  }
  slack <- .sem_polish_f_slack
  if (restore) {
    allow <- .sem_restore_allowance(res$solution, ram, smp, lb, ub, cons)
    if (is.na(allow)) {
      return(list(res = res, gate = gate))
    }
    slack <- .sem_restore_k * allow + .sem_polish_f_slack
  }
  r <- .sem_eval(pol, ram, smp, deriv = FALSE)
  g2 <- .sem_gate(pol, res$status, ram, smp, lb, ub, cons)
  if (is.null(r) || !g2$accepted || r$f > res$objective + slack) {
    return(list(res = res, gate = gate))
  }
  res$solution <- pol
  res$objective <- r$f
  list(res = res, gate = g2)
}

# The Hessian of the Lagrangian in the solver's natural units: the objective's Hessian plus, for each active
# nonlinear row c_i, lambda_i times its curvature (a linear row has none). On a curved constraint the
# reduced Hessian of the objective alone is not the second derivative of the objective along the constraint
# (`a*b == c` bends away from its tangent plane), so it can call a saddle of the restricted problem a minimum
# or a minimum a saddle. The multipliers solve g_free + M_free' lambda = 0 over the active rows (minimum-norm
# least squares, as the sign check does; the bound-active coordinates carry their own multipliers and are left
# out). With no active nonlinear row `hx` is returned unchanged.
.sem_lagrangian_hessian <- function(hx, gx, act, cons, theta) {
  hess <- c(if (!is.null(cons$nl)) cons$nl$hess(theta, act$u), if (!is.null(cons$nli)) cons$nli$hess(theta, act$u))
  if (!length(hess)) {
    return(hx)
  }
  rows <- which(act$active_row)
  m <- act$ax[rows, act$free, drop = FALSE]
  use <- sqrt(rowSums(m^2)) > 1e-12
  if (!any(use) || !all(is.finite(m)) || !all(is.finite(gx))) {
    return(hx)
  }
  sv <- svd(t(m[use, , drop = FALSE]))
  keep <- sv$d > 1e-8 * max(sv$d)
  lambda <- numeric(length(rows))
  coef <- crossprod(sv$u[, keep, drop = FALSE], -gx[act$free]) / sv$d[keep]
  lambda[use] <- as.vector(sv$v[, keep, drop = FALSE] %*% coef)
  uu <- outer(act$u, act$u)
  for (j in seq_along(hess)) {
    lam <- lambda[match(act$nl_pos[j], rows)]
    if (!is.na(lam) && lam != 0) {
      hx <- hx + lam * hess[[j]] * uu
    }
  }
  hx
}

# Positive definiteness, definiteness margin and Newton decrement of a reduced
# Hessian, in Jacobi-scaled coordinates as the unconstrained gate does.
.sem_reduced_stationarity <- function(hr, gr) {
  res <- list(accepted = FALSE, reason = "", min_eig = NA_real_, decrement = NA_real_)
  dg <- diag(hr)
  if (!all(is.finite(hr)) || any(dg <= 0)) {
    res$reason <- "reduced Hessian is not positive definite"
    return(res)
  }
  d <- 1 / sqrt(dg)
  scaled <- hr * outer(d, d)
  ev <- eigen(scaled, symmetric = TRUE, only.values = TRUE)$values
  if (min(ev) <= 0) {
    res$reason <- "reduced Hessian is not positive definite"
    return(res)
  }
  res$min_eig <- min(ev)
  if (res$min_eig < .sem_singular_tol) {
    res$reason <- sprintf("Hessian is nearly singular (scaled smallest eigenvalue %.2e)", res$min_eig)
    return(res)
  }
  g <- as.vector(gr) * d
  res$decrement <- sqrt(sum(g * solve(scaled, g)))
  if (res$decrement > .sem_stat_tol) {
    res$reason <- sprintf("stationarity %.2e exceeds %.0e", res$decrement, .sem_stat_tol)
  } else {
    res$accepted <- TRUE
  }
  res
}

# Warn-only multiplier sign check. The active rows (constraints as c(x) <= 0, bounds as
# the Q10 rows: a lower bound is -e_i, an upper bound +e_i) must reproduce the negative
# gradient with non-negative multipliers on the inequalities and bounds and free-sign
# multipliers on the equalities. The verdict comes from a non-negative least squares fit
# (.sem_nnls(); each equality enters as two columns, one per sign), so linearly dependent
# active rows are judged like any others. The part of the residual that lies in the span of
# the active rows, measured in the Hessian metric sqrt(r' H^-1 r), is compared with
# -.sem_sign_tol: a larger residual means no admissible multipliers exist and the
# solution may not be a local minimum. The rows named in the warning are the inequality
# and bound rows held at zero whose sign, if flipped, would reduce that residual. The table
# reports the minimum-norm least-squares multipliers, which for independent rows are the
# unique ones, judged by lambda * sqrt(m' H^-1 m). An active bound with a wrong-sign multiplier is
# reported in `out$sign_bound` and rejects the fit in .sem_gate_projected(), the verdict the
# unconstrained gate (.sem_gate()) already gives (T8, G1); a wrong-sign inequality constraint only warns.
.sem_sign_check <- function(out, ax, active_row, is_eq, text, at_lb, at_ub, ram, hx, gx) {
  q <- length(gx)
  bound_rows <- NULL
  bound_names <- character()
  bound_par <- character()
  bound_idx <- integer()
  for (i in which(at_lb & !at_ub)) {
    e <- numeric(q)
    e[i] <- -1
    bound_rows <- rbind(bound_rows, e)
    bound_names <- c(bound_names, paste0("lower bound of ", ram$par_names[i]))
    bound_par <- c(bound_par, ram$par_names[i])
    bound_idx <- c(bound_idx, i)
  }
  for (i in which(at_ub & !at_lb)) {
    e <- numeric(q)
    e[i] <- 1
    bound_rows <- rbind(bound_rows, e)
    bound_names <- c(bound_names, paste0("upper bound of ", ram$par_names[i]))
    bound_par <- c(bound_par, ram$par_names[i])
    bound_idx <- c(bound_idx, i)
  }
  m <- rbind(ax[active_row, , drop = FALSE], bound_rows)
  if (!nrow(m)) {
    return(out)
  }
  signed <- c(!is_eq[active_row], rep(TRUE, length(bound_names)))
  names_all <- c(text[active_row], bound_names)
  skipped <- function() {
    out$sign_check <- "skipped: the multipliers could not be computed"
    out
  }
  if (!all(is.finite(m)) || !all(is.finite(gx))) {
    return(skipped())
  }
  hinv_m <- tryCatch(solve(hx, t(m)), error = function(e) NULL)
  # rank and minimum-norm multipliers on unit-length rows, so a row's length does not decide whether it counts
  row_len <- sqrt(rowSums(m^2))
  nz <- row_len > 0
  len <- ifelse(nz, row_len, 1)
  sv <- svd(t(m / len))
  keep <- sv$d > 1e-8 * max(sv$d)
  if (is.null(hinv_m) || !all(is.finite(hinv_m)) || !any(keep)) {
    return(skipped())
  }
  u_k <- sv$u[, keep, drop = FALSE]
  # minimum-norm least-squares multipliers, for the table (a zero row gets a zero multiplier)
  lambda <- as.vector(sv$v[, keep, drop = FALSE] %*% (crossprod(u_k, -gx) / sv$d[keep])) / len
  # admissible multipliers: one column per inequality or bound row, two (+/-) per equality row
  idx <- c(seq_len(nrow(m)), which(!signed))
  sgn <- c(rep(1, nrow(m)), rep(-1, sum(!signed)))
  nn <- .sem_nnls(sweep(t(m[idx, , drop = FALSE]), 2, sgn, "*"), -gx)
  if (!isTRUE(attr(nn, "converged"))) {
    return(skipped())
  }
  lam_nn <- numeric(nrow(m))
  for (k in seq_along(idx)) {
    lam_nn[idx[k]] <- lam_nn[idx[k]] + sgn[k] * nn[k]
  }
  r_span <- as.vector(u_k %*% crossprod(u_k, -gx - as.vector(crossprod(m, lam_nn))))
  n_con <- nrow(m) - length(bound_names)
  # A bound is judged by its own statistic, the unconstrained gate's measure |g_k| / sqrt(H_kk) (the slope by
  # which flipping the bound row would lower the objective, over the root of the Hessian diagonal), so a model
  # with a constraint line and one without it get the same verdict (T8b). It needs only H_kk, not H^-1, so an
  # indefinite Hessian cannot hide a wrong-side bound; like the unconstrained gate, a non-positive H_kk rejects.
  if (length(bound_names)) {
    rows <- n_con + seq_along(bound_names)
    slope <- -as.vector(m[rows, , drop = FALSE] %*% r_span) / len[rows]
    hk <- diag(hx)[bound_idx]
    # A slope that is only roundoff in the gradient it cancels against (the gradient norm sets the scale, as the
    # reference BLAS shows at extreme data scales, #238) is no evidence that the bound points inward.
    slope_floor <- max(1e-12, .sem_slope_tol_rel * sqrt(sum(gx^2)))
    wrong <- slope > slope_floor & (!is.finite(hk) | hk <= 0 | slope / sqrt(pmax(hk, 0)) > .sem_stat_tol)
    out$sign_bound <- bound_par[wrong]
  }
  hinv_r <- tryCatch(solve(hx, r_span), error = function(e) NULL)
  if (is.null(hinv_r) || !all(is.finite(hinv_r))) {
    return(skipped())
  }
  z <- lambda * sqrt(pmax(0, colSums(t(m) * hinv_m)))
  out$multipliers <- data.frame(constraint = names_all, lambda = lambda, scaled = z, signed = signed,
                                stringsAsFactors = FALSE)
  if (sqrt(max(0, sum(r_span * hinv_r))) > -.sem_sign_tol) {
    # an inequality or bound held at zero whose flipped sign would reduce the residual; when roundoff leaves
    # every one a tiny positive weight, any non-zero signed row may be the one
    held <- which(signed & nz & nn[seq_len(nrow(m))] <= 0)
    if (!length(held)) {
      held <- which(signed & nz)
    }
    cosine <- as.vector(m[held, , drop = FALSE] %*% r_span) / (len[held] * sqrt(sum(r_span^2)))
    bad <- held[which(cosine < -1e-6)]
    if (!length(bad) && length(held)) {
      bad <- held[which.min(cosine)]
    }
    # bound rows (after the active constraint rows) were judged above; only constraint rows are named here
    bad <- bad[bad <= n_con]
    out$sign_warnings <- sprintf(
      paste0("constraint %s is active, but moving into the feasible region would lower the objective; ",
             "the solution may not be a local minimum"),
      names_all[bad]
    )
  }
  out
}

# Lawson-Hanson non-negative least squares: minimize ||A x - b|| subject to x >= 0, for any A,
# including rank-deficient ones (duplicated columns, a column that is a sum of others, an
# equality entered with both signs). The textbook loop with an absolute tolerance divides 0 by 0
# once data units make roundoff exceed the tolerance; here
#   - each column of A and b are first scaled to unit length (zero columns are dropped), so the
#     tolerance is relative: a weight counts only above tol * ||b|| of the scaled problem;
#   - the step length is never formed from a zero or non-finite denominator: a column whose step
#     cannot be taken (x and its least-squares value both zero) leaves the passive set;
#   - the iteration count is capped.
# Returns the non-negative, finite solution in the original units, with attributes `converged`
# (the loop reached the optimality test inside the cap) and `iterations`. Never errors; on an
# internal failure it returns zeros with converged = FALSE.
.sem_nnls <- function(A, b, tol = 1e-10, maxit = NULL) {
  A <- as.matrix(A)
  b <- as.vector(b)
  n <- ncol(A)
  it <- 0L
  fail <- function() structure(numeric(n), converged = FALSE, iterations = it)
  if (!n || nrow(A) != length(b) || !all(is.finite(A)) || !all(is.finite(b))) {
    return(fail())
  }
  tryCatch({
    bn <- sqrt(sum(b^2))
    cn <- sqrt(colSums(A^2))
    use <- which(cn > .Machine$double.eps * max(cn))
    if (!length(use) || bn == 0) {
      return(structure(numeric(n), converged = TRUE, iterations = it))
    }
    a_s <- sweep(A[, use, drop = FALSE], 2, cn[use], "/")
    b_s <- b / bn
    k <- length(use)
    if (is.null(maxit)) {
      maxit <- 10L * k + 50L
    }
    thr <- tol * sqrt(sum(b_s^2))
    x <- numeric(k)
    passive <- logical(k)
    weights <- function(x) as.vector(crossprod(a_s, b_s - a_s %*% x))
    lsq <- function(passive) {
      s <- numeric(k)
      cf <- stats::lm.fit(a_s[, passive, drop = FALSE], b_s, tol = tol)$coefficients
      cf[is.na(cf)] <- 0
      s[passive] <- cf
      s
    }
    w <- weights(x)
    converged <- FALSE
    while (it < maxit) {
      cand <- which(!passive)
      j <- cand[which.max(w[cand])]
      if (!length(cand) || !(w[j] > thr)) {
        converged <- TRUE
        break
      }
      it <- it + 1L
      passive[j] <- TRUE
      for (inner in seq_len(k + 5L)) {
        s <- lsq(passive)
        if (all(s[passive] > 0)) {
          x <- s
          break
        }
        neg <- passive & s <= 0
        den <- x - s
        steppable <- neg & is.finite(den) & den > 0
        before <- passive
        if (any(steppable)) {
          ratio <- x[steppable] / den[steppable]
          alpha <- min(max(min(ratio), 0), 1)
          x <- x + alpha * (s - x)
          passive[which(steppable)[which.min(ratio)]] <- FALSE
        }
        passive <- passive & x > tol & !(neg & !steppable)
        if (identical(before, passive)) {
          passive[which(neg)[1L]] <- FALSE
        }
        x[!passive] <- 0
        if (!any(passive)) {
          break
        }
      }
      w <- weights(x)
    }
    x <- pmax(x, 0)
    out <- numeric(n)
    out[use] <- x * bn / cn[use]
    if (!all(is.finite(out))) {
      return(fail())
    }
    structure(out, converged = converged, iterations = it)
  }, error = function(e) fail())
}
