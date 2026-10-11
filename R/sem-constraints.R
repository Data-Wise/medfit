# Native SEM engine: linear constraints.
#
# Internal. A constraint line (`==`, `<`, `>` from the parser's constraint table)
# that is provably linear in the parameter labels becomes one row `a'theta + b`,
# normalized to unit length: equalities `a'theta + b = 0` and inequalities
# `a'theta + b <= 0` (a `>` constraint is negated). Rows are constant, so the
# solver gets constant Jacobians and one solve suffices (spec 4.5a, 4.5b). A
# nonlinear constraint errors by name; nonlinear constraints arrive in a later
# version. Defined parameters (`:=`) are substituted before the linearity walk.

.sem_nonlinear_msg <- "nonlinear constraints are not supported in this version"

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
  for (i in seq_len(nrow(cons))) {
    text <- paste(cons$lhs[i], cons$op[i], cons$rhs[i])
    tree <- .sem_expr_subst(.sem_expr_parse(paste0("(", cons$lhs[i], ") - (", cons$rhs[i], ")")), defs)
    labels <- all.vars(tree)
    if (!length(labels)) {
      stop("constraint contains no parameters: '", text, "'", call. = FALSE)
    }
    if (!.sem_tree_linear(tree)) {
      stop(.sem_nonlinear_msg, ": '", text, "'", call. = FALSE)
    }
    idx <- match(labels, ram$par_names)
    if (anyNA(idx)) {
      stop("constraint '", text, "' refers to '", labels[is.na(idx)][1L], "', which is not a free parameter",
           call. = FALSE)
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
  pick <- function(eq) {
    keep <- Filter(function(r) (r$op == "==") == eq, rows)
    list(
      A = if (length(keep)) do.call(rbind, lapply(keep, `[[`, "a")) else matrix(0, 0L, ram$q),
      b = vapply(keep, `[[`, 1, "b"),
      text = vapply(keep, `[[`, "", "text")
    )
  }
  list(eq = pick(TRUE), ineq = pick(FALSE))
}

# The empty constraint set, for code that always wants a `cons` list.
.sem_no_cons <- function(q) {
  none <- list(A = matrix(0, 0L, q), b = numeric(), text = character())
  list(eq = none, ineq = none)
}

# Residual of the constraints at `theta`: equalities in absolute value, inequalities
# by how far they are violated (zero when satisfied). Rows are unit length, so the
# residual is in parameter units.
.sem_constraint_residual <- function(theta, cons) {
  if (is.null(cons)) {
    return(numeric())
  }
  c(
    if (nrow(cons$eq$A)) abs(as.vector(cons$eq$A %*% theta) + cons$eq$b),
    if (nrow(cons$ineq$A)) pmax(0, as.vector(cons$ineq$A %*% theta) + cons$ineq$b)
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
# Jacobian is the row scaled by u, constant.
.sem_nlopt_constraints <- function(cons, u) {
  if (is.null(cons)) {
    return(NULL)
  }
  out <- list()
  eq <- .sem_independent_rows(cons$eq)
  ineq <- .sem_drop_implied_ineq(cons$ineq, eq)
  # One binding per block: the closures capture this environment, so a shared name would let the
  # inequality rows replace the equality Jacobian.
  if (nrow(eq$A)) {
    jac_eq <- sweep(eq$A, 2L, u, "*")
    out$eval_g_eq <- function(x) as.vector(jac_eq %*% x) + eq$b
    out$eval_jac_g_eq <- function(x) jac_eq
  }
  if (nrow(ineq$A)) {
    jac_ineq <- sweep(ineq$A, 2L, u, "*")
    out$eval_g_ineq <- function(x) as.vector(jac_ineq %*% x) + ineq$b
    out$eval_jac_g_ineq <- function(x) jac_ineq
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

# Everything the gate and the covariance need about the active set at `theta`,
# in the solver's natural units x = theta / u. `z` is an orthonormal basis (in x
# coordinates, over the coordinates not at a bound) of the directions that keep
# every active constraint and bound; `z_theta` is the same basis embedded in the
# full parameter vector and mapped back to theta units (zero rows for coordinates
# at a bound). Bound-active coordinates are eliminated first, so a fit with
# bounds only reduces to the coordinate subset the unconstrained gate uses.
.sem_active_set <- function(theta, ram, smp, lb, ub, cons) {
  u <- .sem_step_floor(ram, smp)
  rows <- rbind(cons$eq$A, cons$ineq$A)
  bvec <- c(cons$eq$b, cons$ineq$b)
  is_eq <- c(rep(TRUE, nrow(cons$eq$A)), rep(FALSE, nrow(cons$ineq$A)))
  text <- c(cons$eq$text, cons$ineq$text)
  ax <- sweep(rows, 2L, u, "*")
  len <- sqrt(rowSums(ax^2))
  cval <- as.vector(rows %*% theta) + bvec
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
       active_row = active_row, z = z, z_theta = z_theta)
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
  hx <- .sem_hess_f(theta, ram, smp) * outer(act$u, act$u)
  gx <- r$g * act$u
  if (!all(is.finite(hx))) {
    out$reason <- "the Hessian is not finite"
    return(out)
  }
  if (ncol(act$z) == 0L) {
    out$decrement <- 0
    out$accepted <- TRUE
  } else {
    free <- act$free
    red <- .sem_reduced_stationarity(crossprod(act$z, hx[free, free, drop = FALSE] %*% act$z),
                                     crossprod(act$z, gx[free]))
    out$min_eig <- red$min_eig
    out$decrement <- red$decrement
    out$reason <- red$reason
    out$accepted <- red$accepted
  }
  if (out$accepted) {
    out <- .sem_sign_check(out, act$ax, act$active_row, act$is_eq, act$text, act$at_lb, act$at_ub, ram, hx, gx)
  }
  out
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
# unique ones, judged by lambda * sqrt(m' H^-1 m). Never rejects a fit (D8).
.sem_sign_check <- function(out, ax, active_row, is_eq, text, at_lb, at_ub, ram, hx, gx) {
  q <- length(gx)
  bound_rows <- NULL
  bound_names <- character()
  for (i in which(at_lb & !at_ub)) {
    e <- numeric(q)
    e[i] <- -1
    bound_rows <- rbind(bound_rows, e)
    bound_names <- c(bound_names, paste0("lower bound of ", ram$par_names[i]))
  }
  for (i in which(at_ub & !at_lb)) {
    e <- numeric(q)
    e[i] <- 1
    bound_rows <- rbind(bound_rows, e)
    bound_names <- c(bound_names, paste0("upper bound of ", ram$par_names[i]))
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
    out$sign_warnings <- sprintf(
      paste0("%s is active, but moving into the feasible region would lower the objective; ",
             "the solution may not be a local minimum"),
      ifelse(grepl("bound of", names_all[bad], fixed = TRUE), names_all[bad], paste0("constraint ", names_all[bad]))
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
