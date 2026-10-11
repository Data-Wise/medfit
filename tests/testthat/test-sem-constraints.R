# Native SEM engine: linear constraints in the optimizer (S13).
# Oracles: lavaan::sem() with the same constraint line, and an independent
# null-space reparameterization minimized with optim() (no constraint machinery
# shared with nloptr). Planted defect: a nonlinear constraint misclassified as
# linear is solved with a constant Jacobian and violates the true constraint.

cons_data <- function(n = 500, seed = 11) {
  set.seed(seed)
  d <- data.frame(X = stats::rnorm(n))
  d$M <- 0.5 * d$X + stats::rnorm(n)
  d$Y <- 0.4 * d$M + 0.2 * d$X + stats::rnorm(n)
  d
}

cons_model <- "M ~ a*X\nY ~ b*M + cp*X"

cons_setup <- function(extra, data = cons_data(), model = cons_model) {
  parsed <- .sem_parse(paste0(model, "\n", extra))
  conv <- .sem_to_ram(.sem_complete(parsed$parameters))
  smp <- .sem_sample(data[, conv$ram$obs], conv$ram)
  list(
    ram = conv$ram, smp = smp, parsed = parsed, data = data,
    cons = .sem_constraint_rows(parsed$constraints, conv$ram), start = .sem_default_start(conv$ram, smp)
  )
}

cons_solve <- function(s, cons = s$cons) {
  opts <- list(algorithm = "NLOPT_LD_SLSQP", xtol_rel = 1e-10, ftol_rel = 1e-12, maxeval = 10000L)
  res <- .sem_solve_one(s$start, s$ram, s$smp, rep(-Inf, s$ram$q), rep(Inf, s$ram$q), opts, cons = cons)
  stats::setNames(res$solution, s$ram$par_names)
}

lav_estimates <- function(extra, data = cons_data()) {
  fit <- lavaan::sem(paste0(cons_model, "\n", extra), data = data, fixed.x = FALSE)
  pe <- lavaan::parameterEstimates(fit)
  stats::setNames(
    pe$est[match(c("M ~ X", "Y ~ M", "Y ~ X"), paste(pe$lhs, pe$op, pe$rhs))],
    c("a", "b", "cp")
  )
}

test_that("a linear constraint becomes a unit-length row, negated for >", {
  s <- cons_setup("a + b == 0.5\na + 2*b < 1\nb > 2*cp")
  cons <- s$cons
  expect_identical(cons$eq$text, "a + b == 0.5")
  expect_identical(cons$ineq$text, c("a + 2*b < 1", "b > 2*cp"))
  ia <- match("a", s$ram$par_names)
  ib <- match("b", s$ram$par_names)
  icp <- match("cp", s$ram$par_names)
  expect_equal(cons$eq$A[1L, c(ia, ib)], rep(1 / sqrt(2), 2L))
  expect_equal(cons$eq$b, -0.5 / sqrt(2))
  expect_equal(cons$ineq$A[1L, c(ia, ib)], c(1, 2) / sqrt(5))
  expect_equal(cons$ineq$b[1L], -1 / sqrt(5))
  # b > 2*cp  is  2*cp - b <= 0
  expect_equal(cons$ineq$A[2L, c(ib, icp)], c(-1, 2) / sqrt(5))
  expect_equal(unname(rowSums(cons$eq$A^2)), 1)
  expect_equal(unname(rowSums(cons$ineq$A^2)), c(1, 1))
  # the row reproduces the expression at random points, up to the normalization
  set.seed(3)
  for (i in 1:5) {
    th <- stats::rnorm(s$ram$q)
    names(th) <- s$ram$par_names
    expect_equal(sum(cons$ineq$A[1L, ] * th) + cons$ineq$b[1L], (th[["a"]] + 2 * th[["b"]] - 1) / sqrt(5))
  }
  expect_null(.sem_constraint_rows(.sem_parse(paste0(cons_model, "\nab := a*b"))$constraints, s$ram))
})

test_that("defined parameters are substituted before the linearity walk", {
  s <- cons_setup("s := a + b\ns == 0.5")
  expect_equal(s$cons$eq$A[1L, match(c("a", "b"), s$ram$par_names)], rep(1 / sqrt(2), 2L))
  expect_identical(nrow(s$cons$ineq$A), 0L)
  chained <- cons_setup("s := a + b\nt := 2*s\nt < 1")
  expect_equal(chained$cons$ineq$A[1L, match(c("a", "b"), chained$ram$par_names)], rep(1 / sqrt(2), 2L))
})

test_that("nonlinear, parameter-free and unprovable constraints error by name", {
  for (extra in c("a*b == 0.1", "exp(a) == 1", "a*b - a*b + a == 1", "ab := a*b\nab > 0", "a/b < 1", "min(a, b) > 0")) {
    expect_error(cons_setup(extra), "nonlinear constraints are not supported in this version", info = extra)
  }
  expect_error(cons_setup("1 == 2"), "constraint contains no parameters: '1 == 2'")
  expect_error(cons_setup("1 < 2"), "constraint contains no parameters")
  expect_error(cons_setup("a - a == 0"), "constraint contains no parameters")
  expect_error(cons_setup("0*a == 1"), "constraint contains no parameters")
})

test_that("constrained solutions match lavaan, on equalities and active inequalities", {
  skip_if_not_installed("lavaan")
  # tolerance: SLSQP and lavaan's own optimizer each stop near 1e-8; pinned at 1e-5 (plan review note 5)
  cases <- c("a + b == 0.5", "a == b", "a + b < 0.5", "a - b > 0.2", "2*a + b == 0.9\ncp == a")
  for (extra in cases) {
    s <- cons_setup(extra)
    ours <- cons_solve(s)[c("a", "b", "cp")]
    expect_equal(unname(ours), unname(lav_estimates(extra)), tolerance = 1e-5, info = extra)
    expect_lt(max(.sem_constraint_residual(cons_solve(s), s$cons)), 1e-6)
  }
})

test_that("an inactive inequality leaves the unconstrained solution unchanged", {
  s <- cons_setup("a + b < 5")
  free <- cons_solve(s, cons = NULL)
  expect_equal(cons_solve(s), free, tolerance = 1e-6)
  expect_equal(max(.sem_constraint_residual(cons_solve(s), s$cons)), 0)
})

test_that("an independent null-space reparameterization reaches the same optimum", {
  s <- cons_setup("a + b == 0.5\ncp == 2*a")
  ours <- cons_solve(s)
  a_eq <- s$cons$eq$A
  b_eq <- s$cons$eq$b
  theta0 <- as.vector(MASS::ginv(a_eq) %*% (-b_eq))
  z <- svd(a_eq, nu = 0, nv = ncol(a_eq))$v[, (nrow(a_eq) + 1L):ncol(a_eq), drop = FALSE]
  obj <- .sem_objective(s$ram, s$smp)
  start_phi <- as.vector(crossprod(z, ours - theta0)) + 0.3
  red <- stats::optim(start_phi, function(p) obj$f(theta0 + as.vector(z %*% p)),
                      function(p) as.vector(crossprod(z, obj$g(theta0 + as.vector(z %*% p)))),
                      method = "BFGS", control = list(reltol = 1e-14, maxit = 1000L))
  ref <- theta0 + as.vector(z %*% red$par)
  expect_equal(unname(ours), ref, tolerance = 1e-5)
  expect_equal(obj$f(unname(ours)), red$value, tolerance = 1e-9)
})

test_that("a constraint on an equal-label pair and on variances is enforced too", {
  s <- cons_setup("a == b", model = "M ~ a*X\nY ~ b*M + cp*X\nM ~~ v1*M\nY ~~ v2*Y")
  expect_equal(unname(cons_solve(s)[c("a")]), unname(cons_solve(s)[c("b")]), tolerance = 1e-6)
  v <- cons_setup("v1 == v2", model = "M ~ a*X\nY ~ b*M + cp*X\nM ~~ v1*M\nY ~~ v2*Y")
  th <- cons_solve(v)
  expect_equal(th[["v1"]], th[["v2"]], tolerance = 1e-6)
})

test_that("planted defect: a nonlinear constraint called linear is solved with a constant Jacobian", {
  expect_error(cons_setup("a*b + a == 0.2"), "nonlinear constraints are not supported")
  testthat::local_mocked_bindings(.sem_tree_linear = function(e) TRUE)
  s <- cons_setup("a*b + a == 0.2")
  th <- cons_solve(s)
  # the row is a == 0.2 (the value at zero and the unit steps), so the true constraint is violated
  expect_gt(abs(th[["a"]] * th[["b"]] + th[["a"]] - 0.2), 1e-3)
})

test_that("planted defect: dropping the inequality negation flips a > constraint", {
  s <- cons_setup("a - b > 0.2")
  good <- cons_solve(s)
  bad_cons <- s$cons
  bad_cons$ineq$A <- -bad_cons$ineq$A
  bad_cons$ineq$b <- -bad_cons$ineq$b
  bad <- cons_solve(s, bad_cons)
  expect_gte(good[["a"]] - good[["b"]], 0.2 - 1e-6)
  expect_lt(bad[["a"]] - bad[["b"]], 0.2 - 1e-3)
})

# --- Mixed equality and inequality constraints -------------------------------------
# One equality beside one inequality was never tested, and both Jacobians used to share one binding, so the
# equality callbacks read the inequality rows (the native fit then errored with the equality violated).

mixed_cases <- c("a == 0\nb + cp < 1", "a == 0\nb + cp < 0.3", "a == 0\nb + cp < 1\ncp > -5",
                 "a == 0\ncp == 0.1\nb + cp < 1")

# TRUE when each callback pair of `fn(cons, u)` reproduces its own rows: the Jacobian is the row scaled by u and
# the value is A (u * x) + b (computed independently of the sweep the engine uses).
callbacks_follow_rows <- function(fn, cons, u, q) {
  nl <- fn(cons, u)
  x <- seq_len(q) / 10
  ok <- TRUE
  for (kind in c("eq", "ineq")) {
    a <- cons[[kind]]$A
    if (!nrow(a)) next
    jac <- nl[[paste0("eval_jac_g_", kind)]](x)
    val <- nl[[paste0("eval_g_", kind)]](x)
    ok <- ok && isTRUE(all.equal(unname(jac), unname(sweep(a, 2L, u, "*")))) &&
      isTRUE(all.equal(as.vector(val), as.vector(a %*% (u * x)) + cons[[kind]]$b))
  }
  ok
}

test_that("with both kinds of constraint, each callback pair uses its own rows", {
  for (extra in mixed_cases) {
    s <- cons_setup(extra)
    q <- s$ram$q
    for (u in list(rep(1, q), seq_len(q) * 0.7 + 0.2)) {
      expect_true(callbacks_follow_rows(.sem_nlopt_constraints, s$cons, u, q), info = extra)
    }
  }
})

test_that("planted defect: one Jacobian binding shared by both callback pairs fails the callback check", {
  # the original construction: `jac` is rebound by the inequality block, and the closures see the last value
  shared <- function(cons, u) {
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
  s <- cons_setup("a == 0\nb + cp < 1")
  u <- rep(1, s$ram$q)
  expect_false(callbacks_follow_rows(shared, s$cons, u, s$ram$q))
  # a single kind of constraint cannot show it, which is how it went unseen
  expect_true(callbacks_follow_rows(shared, cons_setup("a == 0")$cons, u, s$ram$q))
})

# lavaan's default stopping rule leaves the active-inequality case about 3e-6 from its own tightly converged
# solution (b = 0.299433 default, 0.2994357 at rel.tol 1e-12; ours 0.2994353), so the oracle here is tightened.
lav_estimates_tight <- function(extra, data = cons_data()) {
  fit <- lavaan::sem(paste0(cons_model, "\n", extra), data = data, fixed.x = FALSE,
                     control = list(rel.tol = 1e-12, eval.max = 10000))
  pe <- lavaan::parameterEstimates(fit)
  pe$est[match(c("M ~ X", "Y ~ M", "Y ~ X"), paste(pe$lhs, pe$op, pe$rhs))]
}

test_that("mixed constraints match lavaan: an inactive and an active inequality, and two equalities", {
  skip_if_not_installed("lavaan")
  for (extra in mixed_cases) {
    s <- cons_setup(extra)
    ours <- cons_solve(s)
    expect_equal(unname(ours[c("a", "b", "cp")]), lav_estimates_tight(extra), tolerance = 1e-5, info = extra)
    expect_equal(ours[["a"]], 0, tolerance = 1e-6, info = extra)
    expect_lt(max(.sem_constraint_residual(ours, s$cons)), 1e-6)
  }
})

test_that("fit_sem() accepts an equality beside an inequality", {
  fit <- fit_sem(paste0(cons_model, "\na == 0\nb + cp < 0.3"), cons_data())
  expect_true(fit@converged)
  expect_equal(unname(fit@theta[["a"]]), 0, tolerance = 1e-6)
  expect_lte(unname(fit@theta[["b"]] + fit@theta[["cp"]]), 0.3 + 1e-6)
})

# --- Redundant equalities --------------------------------------------------------------
# Linearly dependent equality rows (a duplicate, `a == b` with `b == a`, a transitive triple) made SLSQP stop
# with status -4, so the fit failed although the constraints are consistent. The solver now gets an
# independent subset of the equality rows; the acceptance gate and the covariance keep every row.

redundant_cases <- c("a == b\na == b", "a == b\nb == a", "a == b\na - b == 0", "a == b\nb == cp\na == cp",
                     "a == 0\nb == 0\na + b == 0")

test_that("the independent subset keeps the first independent rows and drops the dependent ones", {
  q <- 3L
  eq <- function(...) {
    rows <- list(...)
    a <- do.call(rbind, lapply(rows, function(r) r / sqrt(sum(r^2))))
    list(A = a, b = rep(0, length(rows)), text = paste0("row", seq_along(rows)))
  }
  keep <- function(e) .sem_independent_rows(e)$text
  expect_identical(keep(eq(c(1, -1, 0))), "row1")
  expect_identical(keep(eq(c(1, -1, 0), c(-1, 1, 0))), "row1")
  expect_identical(keep(eq(c(1, -1, 0), c(0, 1, -1), c(1, 0, -1))), c("row1", "row2"))
  expect_identical(keep(eq(c(1, 0, 0), c(0, 1, 0), c(1, 1, 0))), c("row1", "row2"))
  # independent rows pass through unchanged, and so does the empty set
  indep <- eq(c(1, 0, 0), c(0, 1, 0), c(0, 0, 1))
  expect_identical(.sem_independent_rows(indep), indep)
  none <- list(A = matrix(0, 0L, q), b = numeric(), text = character())
  expect_identical(.sem_independent_rows(none), none)
})

test_that("the solver is handed one Jacobian row per independent equality", {
  for (extra in redundant_cases) {
    s <- cons_setup(extra)
    nl <- .sem_nlopt_constraints(s$cons, rep(1, s$ram$q))
    rank <- qr(t(s$cons$eq$A), tol = 1e-8)$rank
    expect_identical(nrow(nl$eval_jac_g_eq(numeric(s$ram$q))), rank, info = extra)
    expect_lt(rank, nrow(s$cons$eq$A))
  }
})

test_that("a redundant set reaches the optimum of the equivalent independent set", {
  # Same feasible region, so the same optimum. lavaan is not used as the oracle here: 0.7-2 does not converge
  # on several of these shapes (for `a == 0, b == 0, a + b == 0` it returns its starting values), and 0.7-3
  # reaches the same estimates but warns that the optimizer has not found a solution on four of the five.
  same <- list(
    c("a == b\na == b", "a == b"), c("a == b\nb == a", "a == b"), c("a == b\na - b == 0", "a == b"),
    c("a == b\nb == cp\na == cp", "a == b\nb == cp"), c("a == 0\nb == 0\na + b == 0", "a == 0\nb == 0")
  )
  for (pair in same) {
    redundant <- cons_solve(cons_setup(pair[1L]))
    independent <- cons_solve(cons_setup(pair[2L]))
    expect_equal(redundant, independent, tolerance = 1e-6, info = pair[1L])
    expect_lt(max(.sem_constraint_residual(redundant, cons_setup(pair[1L])$cons)), 1e-6)
  }
})

test_that("fit_sem() converges with a redundant pair of equalities", {
  fit <- fit_sem(paste0(cons_model, "\na == b\nb == a"), cons_data())
  expect_true(fit@converged)
  expect_equal(unname(fit@theta[["a"]]), unname(fit@theta[["b"]]), tolerance = 1e-6)
})

test_that("contradictory dependent equalities still error naming the violated constraint", {
  for (extra in c("a == 1\na == 2", "a == 0\nb == 0\na + b == 1")) {
    s <- cons_setup(extra)
    expect_error(.sem_optimize(s$ram, s$smp, s$start, constraints = s$cons),
                 "no start converged.*constraint '[^']+' is violated by", info = extra)
  }
})

test_that("planted defect: handing the solver every dependent row reproduces the status -4 failure", {
  testthat::local_mocked_bindings(.sem_independent_rows = function(eq) eq)
  s <- cons_setup("a == b\nb == a")
  expect_error(.sem_optimize(s$ram, s$smp, s$start, constraints = s$cons), "status -4")
})

test_that("rows scale to the solver's coordinates when preconditioned", {
  s <- cons_setup("a + b == 0.5")
  scaled <- cons_data()
  scaled[] <- lapply(scaled, `*`, 1000)
  big <- cons_setup("a + b == 0.5", data = scaled)
  # coefficients are scale free, so the same constraint gives the same solution at x1000 data
  expect_equal(cons_solve(big)[c("a", "b", "cp")], cons_solve(s)[c("a", "b", "cp")], tolerance = 1e-5)
})

# --- S14: acceptance of constrained fits ----------------------------------------

empty_cons <- function(q) {
  none <- list(A = matrix(0, 0L, q), b = numeric(), text = character())
  list(eq = none, ineq = none)
}

# Optimum of the model with `k` pinned at `value` (the others free), the point a stalled solver at a
# bound would report.
pin_at <- function(mod, smp, theta, k, value) {
  q <- mod$ram$q
  obj <- .sem_objective(mod$ram, smp)
  fr <- setdiff(seq_len(q), k)
  x <- theta
  x[k] <- value
  o <- stats::nlminb(x[fr], function(z) {
    y <- x
    y[fr] <- z
    obj$f(y)
  }, function(z) {
    y <- x
    y[fr] <- z
    obj$g(y)[fr]
  }, control = list(rel.tol = 1e-14))
  x[fr] <- o$par
  x
}

test_that("the projected gate accepts the constrained optimum, an active inequality, and reports the bound", {
  s <- cons_setup("a + b == 0.5")
  fit <- .sem_optimize(s$ram, s$smp, s$start, constraints = s$cons)
  expect_true(fit$converged)
  expect_lt(fit$decrement, .sem_stat_tol)
  expect_equal(fit$theta[["a"]] + fit$theta[["b"]], 0.5, tolerance = 1e-8)
  expect_identical(fit$sign_check, "ok")
  # a real active <= : unconstrained a + b is 0.93, so a cap of 0.5 binds with a correct-sign multiplier
  expect_no_warning(le <- .sem_optimize(cons_setup("a + b < 0.5")$ram, s$smp, s$start,
                                        constraints = cons_setup("a + b < 0.5")$cons))
  expect_gt(le$multipliers$lambda, 0)
  expect_true(le$multipliers$signed)
  # a real active >= : a - b is 0.128 unconstrained, so a floor of 0.2 binds with a correct-sign multiplier
  ge_s <- cons_setup("a - b > 0.2")
  expect_no_warning(ge <- .sem_optimize(ge_s$ram, ge_s$smp, ge_s$start, constraints = ge_s$cons))
  expect_gt(ge$multipliers$lambda, 0)
  expect_equal(ge$theta[["a"]] - ge$theta[["b"]], 0.2, tolerance = 1e-8)
  # an inactive inequality is not in the multiplier table
  inact <- cons_setup("a + b < 5")
  expect_null(.sem_optimize(inact$ram, inact$smp, inact$start, constraints = inact$cons)$multipliers)
})

test_that("wrong-sign multiplier: the equality solution judged against the other side warns, not rejects", {
  eq <- cons_setup("a + b == 0.5")
  th <- .sem_optimize(eq$ram, eq$smp, eq$start, constraints = eq$cons)$theta
  # a + b >= 0.5 is active at this point, but F falls toward the unconstrained optimum a + b = 0.93, which
  # is feasible: moving into the feasible region lowers the objective.
  ge <- cons_setup("a + b > 0.5")
  g <- .sem_gate(th, 1L, ge$ram, ge$smp, rep(-Inf, ge$ram$q), rep(Inf, ge$ram$q), ge$cons)
  expect_true(g$accepted)
  expect_length(g$sign_warnings, 1L)
  expect_match(
    g$sign_warnings,
    "constraint a \\+ b > 0.5 is active, but moving into the feasible region would lower the objective"
  )
  expect_lt(g$multipliers$scaled, .sem_sign_tol)
  # through the optimizer the fit is kept and the warning is raised once
  u <- .sem_step_floor(ge$ram, ge$smp)
  testthat::local_mocked_bindings(
    .sem_nlopt = function(x0, eval_f, eval_grad_f, lb, ub, opts, constraints = NULL) {
      list(solution = unname(th) / u, status = 3L, objective = 0)
    }
  )
  expect_warning(fit <- .sem_optimize(ge$ram, ge$smp, ge$start, constraints = ge$cons, n_starts = 1L),
                 "moving into the feasible region would lower the objective")
  expect_true(fit$converged)
})

test_that("planted defect: a flipped sign convention warns on a correct active inequality", {
  s <- cons_setup("a + b < 0.5")
  orig <- .sem_sign_check
  testthat::local_mocked_bindings(
    .sem_sign_check = function(out, ax, ...) orig(out, -ax, ...)
  )
  expect_warning(.sem_optimize(s$ram, s$smp, s$start, constraints = s$cons), "moving into the feasible region")
})

test_that("a rank-deficient active set gets a computed sign verdict, with no warning and no error", {
  s <- cons_setup("a + b < 0.2\n2*a + 2*b < 0.4")
  expect_no_warning(fit <- .sem_optimize(s$ram, s$smp, s$start, constraints = s$cons))
  expect_identical(fit$sign_check, "ok")
  expect_false(is.null(fit$multipliers))
  expect_lte(fit$theta[["a"]] + fit$theta[["b"]], 0.2 + 1e-8)
})

test_that("stubbed solver results get exact verdicts", {
  s <- cons_setup("a + b == 0.5")
  th <- .sem_optimize(s$ram, s$smp, s$start, constraints = s$cons)$theta
  inf <- rep(Inf, s$ram$q)
  gate <- function(theta, status = 1L) .sem_gate(theta, status, s$ram, s$smp, -inf, inf, s$cons)
  for (st in c(1L, 3L, 4L)) expect_true(gate(th, st)$accepted, info = st)
  five <- gate(th, 5L)
  expect_false(five$accepted)
  expect_match(five$reason, "nloptr status 5 is not a success code")
  # a point 1e-3 off the constraint is rejected, naming the constraint
  off <- th
  off[["a"]] <- off[["a"]] + 1e-3
  expect_match(gate(off)$reason, "constraint 'a \\+ b == 0.5' is violated by")
  # feasible but not stationary: moved along the constraint
  along <- th
  along[["a"]] <- along[["a"]] + 0.05
  along[["b"]] <- along[["b"]] - 0.05
  moved <- gate(along)
  expect_false(moved$accepted)
  expect_match(moved$reason, "stationarity")
  # an infeasible stall (status -4) names the constraint too
  expect_match(gate(off, -4L)$reason, "status -4 is not a success code; constraint 'a \\+ b == 0.5' is violated")
})

test_that("planted defect: dropping the status test admits a status-5 result", {
  s <- cons_setup("a + b == 0.5")
  th <- .sem_optimize(s$ram, s$smp, s$start, constraints = s$cons)$theta
  inf <- rep(Inf, s$ram$q)
  expect_false(.sem_gate(th, 5L, s$ram, s$smp, -inf, inf, s$cons)$accepted)
  testthat::local_mocked_bindings(.sem_ok_status = c(1L, 3L, 4L, 5L))
  expect_true(.sem_gate(th, 5L, s$ram, s$smp, -inf, inf, s$cons)$accepted)
})

test_that("planted defect: testing the unprojected gradient rejects the correct constrained fit", {
  s <- cons_setup("a + b == 0.5")
  th <- .sem_optimize(s$ram, s$smp, s$start, constraints = s$cons)$theta
  u <- .sem_step_floor(s$ram, s$smp)
  r <- .sem_eval(th, s$ram, s$smp, deriv = TRUE)
  hx <- .sem_hess_f(th, s$ram, s$smp) * outer(u, u)
  plain <- .sem_reduced_stationarity(hx, r$g * u)
  expect_false(plain$accepted)
  expect_gt(plain$decrement, 100 * .sem_stat_tol)
  expect_lt(.sem_optimize(s$ram, s$smp, s$start, constraints = s$cons)$decrement, .sem_stat_tol)
})

test_that("a bounded fit is accepted, its bound reported active, and the projected gate agrees with the plain gate", {
  mod <- sem_model_heywood()
  smp <- .sem_sample(sem_sim(mod, 50, 10), mod$ram)
  q <- mod$ram$q
  is_var <- vapply(strsplit(mod$ram$par_names, " ~~ ", fixed = TRUE),
                   function(p) length(p) == 2 && p[1] == p[2], logical(1))
  lb <- ifelse(is_var, 0, -Inf)
  ub <- rep(Inf, q)
  fit <- .sem_optimize(mod$ram, smp, pmax(sem_start(mod$ram), lb), lb = lb)
  plain <- .sem_gate(fit$theta, 1L, mod$ram, smp, lb, ub)
  proj <- .sem_gate(fit$theta, 1L, mod$ram, smp, lb, ub, empty_cons(q))
  expect_true(plain$accepted && proj$accepted)
  expect_identical(proj$active, plain$active)
  expect_equal(proj$decrement, plain$decrement, tolerance = 1e-8)
  expect_equal(proj$min_eig, plain$min_eig, tolerance = 1e-8)
  expect_gt(sum(proj$active), 0)
  expect_identical(proj$sign_check, "ok")
  expect_length(proj$sign_warnings, 0L)
})

test_that("a wrong-side active bound is rejected by both gates, with or without an inactive constraint line", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  k <- match("Y ~ M", mod$ram$par_names)
  lb_down <- rep(-Inf, q)
  lb_down[k] <- fit$theta[k] - 0.3
  ub <- rep(Inf, q)
  pt <- pin_at(mod, smp, fit$theta, k, lb_down[k])
  # a constraint line that never binds (M ~ X below 100) must not change the verdict (T8, audit F4)
  inactive <- empty_cons(q)
  e <- numeric(q)
  e[match("M ~ X", mod$ram$par_names)] <- 1
  inactive$ineq <- list(A = matrix(e, 1L), b = -100, text = "M ~ X < 100")
  plain <- .sem_gate(pt, 3L, mod$ram, smp, lb_down, ub)
  expect_false(plain$accepted)
  expect_match(plain$reason, "active bound points into the interior (Y ~ M)", fixed = TRUE)
  for (cons in list(empty_cons(q), inactive)) {
    g <- .sem_gate(pt, 3L, mod$ram, smp, lb_down, ub, cons)
    expect_false(g$accepted)
    expect_identical(g$reason, plain$reason)
    expect_length(g$sign_warnings, 0L)
  }
  # the true constrained optimum (bound above the unconstrained optimum) has the right sign: accepted, no warning
  lb_up <- rep(-Inf, q)
  lb_up[k] <- fit$theta[k] + 0.3
  pt_up <- pin_at(mod, smp, fit$theta, k, lb_up[k])
  expect_true(.sem_gate(pt_up, 3L, mod$ram, smp, lb_up, ub)$accepted)
  for (cons in list(empty_cons(q), inactive)) {
    ok <- .sem_gate(pt_up, 3L, mod$ram, smp, lb_up, ub, cons)
    expect_true(ok$accepted)
    expect_length(ok$sign_warnings, 0L)
  }
})

test_that("a wrong-side bound beside an active constraint is rejected; a wrong-sign constraint alone still warns", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  k <- match("Y ~ M", mod$ram$par_names)
  lb_down <- rep(-Inf, q)
  lb_down[k] <- fit$theta[k] - 0.3
  pt <- pin_at(mod, smp, fit$theta, k, lb_down[k])
  # the unconstrained optimum of M ~ X is about 0.4: the line M ~ X >= its pinned value is active and right-signed
  j <- match("M ~ X", mod$ram$par_names)
  e <- numeric(q)
  e[j] <- -1
  act <- empty_cons(q)
  act$ineq <- list(A = matrix(e, 1L), b = pt[j], text = "M ~ X > pinned")
  g <- .sem_gate(pt, 3L, mod$ram, smp, lb_down, rep(Inf, q), act)
  expect_false(g$accepted)
  expect_match(g$reason, "active bound points into the interior (Y ~ M)", fixed = TRUE)
})

# T8b (ledger G14, T9 defects 1, 2 and 5): a bound is judged by its own statistic |g_k| / sqrt(H_kk), the
# unconstrained gate's measure, so the verdict does not depend on the constraint lines.

inactive_line <- function(mod, par = "M ~ X") {
  cons <- empty_cons(mod$ram$q)
  e <- numeric(mod$ram$q)
  e[match(par, mod$ram$par_names)] <- 1
  cons$ineq <- list(A = matrix(e, 1L), b = -100, text = paste(par, "< 100"))
  cons
}

test_that("a wrong-side bound is rejected when the full Hessian is indefinite", {
  mod <- sem_model_latent()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  u <- .sem_step_floor(mod$ram, smp)
  k <- match("m1 ~~ m1", mod$ram$par_names)
  lb <- rep(-Inf, q)
  lb[k] <- fit$theta[k] - 10^-0.5 * u[k]
  pt <- pin_at(mod, smp, fit$theta, k, lb[k])
  # the precondition that made the 0.8.0 review's repro bite: the clamp on a negative (H^-1)_kk hid the violation
  hess <- .sem_hess_f(pt, mod$ram, smp)
  expect_lt(min(eigen(hess, symmetric = TRUE, only.values = TRUE)$values), 0)
  expect_lt(solve(hess)[k, k], 0)
  plain <- .sem_gate(pt, 3L, mod$ram, smp, lb, rep(Inf, q))
  expect_false(plain$accepted)
  for (cons in list(empty_cons(q), inactive_line(mod, "eta ~ X"))) {
    g <- .sem_gate(pt, 3L, mod$ram, smp, lb, rep(Inf, q), cons)
    expect_false(g$accepted)
    expect_identical(g$reason, plain$reason)
  }
})

test_that("the bound verdict agrees with the unconstrained gate across the stationarity threshold", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  u <- .sem_step_floor(mod$ram, smp)
  ub <- rep(Inf, q)
  inactive <- inactive_line(mod)
  seen <- c(accepted = 0L, rejected = 0L)
  for (par in c("Y ~ M", "Y ~ X", "M ~ X")) {
    k <- match(par, mod$ram$par_names)
    for (delta in 10^seq(-3.6, -1.6, length.out = 21)) {
      lb <- rep(-Inf, q)
      lb[k] <- fit$theta[k] - delta * u[k]
      pt <- pin_at(mod, smp, fit$theta, k, lb[k])
      want <- .sem_gate(pt, 3L, mod$ram, smp, lb, ub)$accepted
      seen[if (want) "accepted" else "rejected"] <- seen[if (want) "accepted" else "rejected"] + 1L
      for (cons in list(empty_cons(q), inactive)) {
        expect_identical(.sem_gate(pt, 3L, mod$ram, smp, lb, ub, cons)$accepted, want,
                         info = sprintf("%s, delta %.3g", par, delta))
      }
    }
  }
  # the grid straddles the threshold: both verdicts occur, so agreement is not vacuous
  expect_gt(seen[["accepted"]], 0L)
  expect_gt(seen[["rejected"]], 0L)
})

test_that("a negligible bound is not blamed for a wrong-sign inequality constraint", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  u <- .sem_step_floor(mod$ram, smp)
  k <- match("Y ~ M", mod$ram$par_names)
  j <- match("M ~ X", mod$ram$par_names)
  # M ~ X < v with v above the optimum: active at the pinned point with a wrong-sign multiplier
  e <- numeric(q)
  e[j] <- 1
  cons <- empty_cons(q)
  v <- fit$theta[j] + 0.3
  cons$ineq <- list(A = matrix(e, 1L), b = -v, text = "M ~ X < v")
  for (eps in c(1e-9, 1e-7, 1e-6, 1e-5)) {
    lb <- rep(-Inf, q)
    lb[k] <- fit$theta[k] - eps * u[k]
    pt <- pin_at(mod, smp, fit$theta, c(k, j), c(lb[k], v))
    r <- .sem_eval(pt, mod$ram, smp, deriv = TRUE)
    # the bound's own statistic is far below the threshold, so the bound is neither rejected nor named
    expect_lt(abs(r$g[k]) / sqrt(.sem_hess_f(pt, mod$ram, smp)[k, k]), .sem_stat_tol / 10)
    g <- .sem_gate(pt, 3L, mod$ram, smp, lb, rep(Inf, q), cons)
    expect_true(g$accepted, info = sprintf("eps %.0e", eps))
    expect_length(g$sign_warnings, 1L)
    expect_match(g$sign_warnings, "constraint M ~ X < v")
  }
})

test_that("planted defect: a wrong bound-row sign rejects the correct bounded fit", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  k <- match("Y ~ M", mod$ram$par_names)
  lb_up <- rep(-Inf, q)
  lb_up[k] <- fit$theta[k] + 0.3
  pt <- pin_at(mod, smp, fit$theta, k, lb_up[k])
  good <- .sem_gate(pt, 3L, mod$ram, smp, lb_up, rep(Inf, q), empty_cons(q))
  expect_true(good$accepted)
  expect_length(good$sign_warnings, 0L)
  src <- paste(deparse(.sem_sign_check), collapse = "\n")
  mut <- sub("e[i] <- -1", "e[i] <- 1", src, fixed = TRUE)
  expect_false(identical(mut, src))
  testthat::local_mocked_bindings(.sem_sign_check = eval(parse(text = mut), environment(.sem_sign_check)))
  bad <- .sem_gate(pt, 3L, mod$ram, smp, lb_up, rep(Inf, q), empty_cons(q))
  expect_false(bad$accepted)
  expect_match(bad$reason, "active bound points into the interior (Y ~ M)", fixed = TRUE)
})

test_that("gate verdicts and decrement are identical across data scales for a constrained fit", {
  # a coefficient constraint (a + b == 0.5) is scale free; a homogeneous variance constraint (v1 == v2)
  # moves with the variances, so the same row serves every scale
  for (extra in c("a + b == 0.5", "v1 == v2")) {
    model <- "M ~ a*X\nY ~ b*M + cp*X\nM ~~ v1*M\nY ~~ v2*Y"
    s <- cons_setup(extra, model = model)
    fit <- .sem_optimize(s$ram, s$smp, s$start, constraints = s$cons)
    inf <- rep(Inf, s$ram$q)
    decr <- vapply(c(0.01, 1, 100, 1000), function(sc) {
      smp <- sem_scale_sample(s$smp, sc)
      th <- fit$theta
      th[s$ram$k_s] <- th[s$ram$k_s] * sc^2 # variances and covariances, by index (labels hide their names)
      g <- .sem_gate(th, 1L, s$ram, smp, -inf, inf, s$cons)
      expect_true(g$accepted, info = paste(extra, sc))
      g$decrement
    }, 0)
    expect_lt(max(abs(decr - decr[2L])), 1e-6)
  }
})

test_that("a constrained fit at x1000 data accepts and matches the unit-scale fit", {
  s1 <- cons_setup("a + b == 0.5")
  big <- cons_data()
  big[] <- lapply(big, `*`, 1000)
  sb <- cons_setup("a + b == 0.5", data = big)
  f1 <- .sem_optimize(s1$ram, s1$smp, s1$start, constraints = s1$cons)
  fb <- .sem_optimize(sb$ram, sb$smp, sb$start, constraints = sb$cons)
  expect_equal(fb$theta[c("a", "b", "cp")], f1$theta[c("a", "b", "cp")], tolerance = 1e-5)
})

test_that("an infeasible pair errors naming a constraint", {
  s <- cons_setup("a == 1\na == 2")
  expect_error(.sem_optimize(s$ram, s$smp, s$start, constraints = s$cons),
               "no start converged.*constraint 'a == [12]' is violated by")
})

# ---- Redundant inequality rows that the equalities imply (audit F1, plan T6) ---------------------------------------
# An inequality whose row lies in the span of the equality rows is constant on the equality set. When it holds there it
# is active at every feasible point and gave SLSQP a rank-deficient active Jacobian. The seeds below failed on the 0.7.0
# code (seeds 1, 2, 4, 6 and 8 fail for every coincident set; rows with code 0.7.0 in
# planning/specs/evidence/native-sem-2026-10-11/results/03-redundant-inequality-sets-0.7.0-baseline.csv).

redundant_data <- function(seed) {
  set.seed(seed)
  n <- 200
  X <- stats::rnorm(n)
  M <- 0.5 * X + stats::rnorm(n)
  Y <- 0.4 * M + 0.1 * X + stats::rnorm(n)
  data.frame(X, M, Y)
}

redundant_fit <- function(extra, seed) {
  suppressWarnings(.sem_fit_syntax(paste0(cons_model, "\n", extra), redundant_data(seed), "observed"))
}

# Number of inequality rows the solver is given for a constraint line.
solver_ineq_rows <- function(extra) {
  s <- cons_setup(extra)
  args <- .sem_nlopt_constraints(s$cons, rep(1, s$ram$q))
  if (is.null(args$eval_g_ineq)) 0L else length(args$eval_g_ineq(rep(0, s$ram$q)))
}

test_that("a consistent inequality that repeats an equality fits and equals the independent set", {
  sets <- list(
    c("a == b\na - b < 0", "a == b"),
    c("a == b\na - b > 0", "a == b"),
    c("a + b == 0.8\na + b > 0.8", "a + b == 0.8"),
    c("a + b == 0.8\na + b < 0.8", "a + b == 0.8"),
    c("a + b == 0.2\na + b > 0.2", "a + b == 0.2")
  )
  for (set in sets) {
    for (seed in c(1L, 4L)) {
      fit <- redundant_fit(set[1L], seed)
      ref <- redundant_fit(set[2L], seed)
      expect_equal(fit$theta, ref$theta[names(fit$theta)], tolerance = 1e-6,
                   info = paste(gsub("\n", " ; ", set[1L]), "seed", seed))
    }
  }
})

test_that("the solver is not given an implied satisfied inequality, and the gate still checks it", {
  expect_equal(solver_ineq_rows("a == b\na - b < 0"), 0L)
  expect_equal(solver_ineq_rows("a + b == 0.8\n2*a + 2*b > 1.6"), 0L) # a parallel row implies the same constant
  s <- cons_setup("a == b\na - b < 0")
  expect_equal(nrow(s$cons$ineq$A), 1L) # the gate's rows keep it
  # an implied row that is strictly inactive on the equality set (constant -0.1) is also dropped: it never binds
  expect_equal(solver_ineq_rows("a + b == 0.8\na + b < 0.9"), 0L)
  # an inequality not in the span of the equalities stays with the solver
  expect_equal(solver_ineq_rows("a == b\na + cp < 2"), 1L)
  expect_equal(solver_ineq_rows("a + b == 0.8\na - b < 0.9"), 1L)
  # inequality-only duplicates and parallel rows are unchanged
  expect_equal(solver_ineq_rows("a + b < 0.2\na + b < 0.2"), 2L)
  expect_equal(solver_ineq_rows("a + b < 0.2\n2*a + 2*b < 0.4"), 2L)
})

test_that("an implied inequality the equalities violate is kept and the gate reports it by name", {
  expect_equal(solver_ineq_rows("a + b == 0.8\na + b < 0.5"), 1L)
  expect_error(redundant_fit("a + b == 0.8\na + b < 0.5", 1L),
               "no start converged.*constraint 'a \\+ b < 0.5' is violated")
})

test_that("the constant of an implied row is evaluated on a point of a multi-row equality set", {
  # a == b and a + b == 0.8 fix a = b = 0.4, so every row in a and b is implied with a constant
  two <- "a == b\na + b == 0.8"
  expect_equal(solver_ineq_rows(paste0(two, "\n2*a - b < 0.4")), 0L) # value 0.4: constant 0, satisfied, dropped
  expect_equal(solver_ineq_rows(paste0(two, "\n2*a - b < 0.5")), 0L) # constant -0.1, dropped
  expect_equal(solver_ineq_rows(paste0(two, "\n2*a - b < 0.3")), 1L) # constant 0.1: violated, kept for the gate
  expect_equal(solver_ineq_rows(paste0(two, "\n3*a + 2*b > 1.8")), 0L) # value 2.0 > 1.8: satisfied, dropped
  expect_equal(solver_ineq_rows(paste0(two, "\n3*a + 2*b > 2.2")), 1L) # value 2.0 < 2.2: violated, kept
})

test_that("near-dependent inequality rows are never dropped or rejected before the solve (ladder)", {
  for (k in c(1e-6, 1e-8, 1e-9, 1e-10, 1e-12, 1e-14)) {
    # feasible for large cp, so the set is consistent although the row is almost in the span of `a == b`; the
    # violated-constant form (a - b + k*cp > 1e-7) is always kept, and so is the satisfied-constant form (< 1e-7)
    # down to the floating-point level
    extra <- sprintf("a == b\na - b + %s*cp > 1e-7", format(k, scientific = TRUE))
    expect_equal(solver_ineq_rows(extra), 1L, info = extra)
    if (k >= 1e-10) {
      extra <- sprintf("a == b\na - b + %s*cp < 1e-7", format(k, scientific = TRUE))
      expect_equal(solver_ineq_rows(extra), 1L, info = extra)
    }
  }
  # the exactly dependent row (residual at the floating-point level) is dropped: the contrast that fixes the tolerance
  expect_equal(solver_ineq_rows("a == b\n2*a - 2*b < 0"), 0L)
  # k = 1e-6 is feasible at cp > 0.1: the fit is not rejected up front
  expect_no_error(redundant_fit("a == b\na - b + 1e-6*cp > 1e-7", 1L))
  expect_no_error(redundant_fit("a == b\na - b + 1e-9*cp < 1e-7", 1L))
})

test_that("planted defect: an implied tolerance of 1e-8 drops near-dependent rows and turns the ladder red", {
  extra <- "a == b\na - b + 1e-9*cp < 1e-7"
  expect_equal(solver_ineq_rows(extra), 1L)
  testthat::local_mocked_bindings(.sem_implied_tol = 1e-8)
  expect_equal(solver_ineq_rows(extra), 0L) # a feasible near-dependent row is now lost to the solver
})

test_that("planted defect: never dropping an implied row brings the 0.7.0 solver rows back", {
  extra <- "a == b\na - b < 0"
  expect_equal(solver_ineq_rows(extra), 0L)
  testthat::local_mocked_bindings(.sem_drop_implied_ineq = function(ineq, eq) ineq)
  expect_equal(solver_ineq_rows(extra), 1L) # the rank-deficient active set the solver failed on (seeds 1, 2, 4, 6, 8)
})
