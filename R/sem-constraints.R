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

# nloptr arguments for the rows in the solver's coordinates x = theta / u: the
# Jacobian is the row scaled by u, constant.
.sem_nlopt_constraints <- function(cons, u) {
  if (is.null(cons)) {
    return(NULL)
  }
  out <- list()
  if (nrow(cons$eq$A)) {
    jac <- sweep(cons$eq$A, 2L, u, "*")
    out$eval_g_eq <- function(x) as.vector(jac %*% x) + cons$eq$b
    out$eval_jac_g_eq <- function(x) jac
  }
  if (nrow(cons$ineq$A)) {
    jac <- sweep(cons$ineq$A, 2L, u, "*")
    out$eval_g_ineq <- function(x) as.vector(jac %*% x) + cons$ineq$b
    out$eval_jac_g_ineq <- function(x) jac
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

# Warn-only multiplier sign check. Least-squares multipliers of the active rows
# (constraints as c(x) <= 0, bounds as the Q10 rows: a lower bound is -e_i, an
# upper bound +e_i); a multiplier of an inequality or a bound is judged by
# lambda * sqrt(m' H^-1 m), the multiplier times the row's length in the Hessian
# metric. Skipped, and said so, when the active rows are linearly dependent.
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
  if (qr(m / sqrt(rowSums(m^2)), tol = 1e-8)$rank < nrow(m)) {
    out$sign_check <- "skipped: the active constraints are linearly dependent"
    return(out)
  }
  lambda <- tryCatch(as.vector(solve(m %*% t(m), -m %*% gx)), error = function(e) NULL)
  hinv_m <- tryCatch(solve(hx, t(m)), error = function(e) NULL)
  if (is.null(lambda) || is.null(hinv_m)) {
    out$sign_check <- "skipped: the multipliers could not be computed"
    return(out)
  }
  z <- lambda * sqrt(pmax(0, colSums(t(m) * hinv_m)))
  out$multipliers <- data.frame(constraint = names_all, lambda = lambda, scaled = z, signed = signed,
                                stringsAsFactors = FALSE)
  bad <- signed & z < .sem_sign_tol
  if (any(bad)) {
    out$sign_warnings <- sprintf(
      paste0("%s is active, but moving into the feasible region would lower the objective; ",
             "the solution may not be a local minimum"),
      ifelse(grepl("bound of", names_all[bad], fixed = TRUE), names_all[bad], paste0("constraint ", names_all[bad]))
    )
  }
  out
}
