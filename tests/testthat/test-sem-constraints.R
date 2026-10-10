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

test_that("a rank-deficient active set skips the sign check and says so, with no warning and no error", {
  s <- cons_setup("a + b < 0.2\n2*a + 2*b < 0.4")
  expect_no_warning(fit <- .sem_optimize(s$ram, s$smp, s$start, constraints = s$cons))
  expect_identical(fit$sign_check, "skipped: the active constraints are linearly dependent")
  expect_null(fit$multipliers)
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

test_that("a wrong-side active bound warns in the projected gate (and is rejected in the plain one)", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  k <- match("Y ~ M", mod$ram$par_names)
  lb_down <- rep(-Inf, q)
  lb_down[k] <- fit$theta[k] - 0.3
  pt <- pin_at(mod, smp, fit$theta, k, lb_down[k])
  expect_false(.sem_gate(pt, 3L, mod$ram, smp, lb_down, rep(Inf, q))$accepted)
  g <- .sem_gate(pt, 3L, mod$ram, smp, lb_down, rep(Inf, q), empty_cons(q))
  expect_true(g$accepted)
  expect_match(g$sign_warnings, "lower bound of Y ~ M is active")
  # the true constrained optimum (bound above the unconstrained optimum) has the right sign: no warning
  lb_up <- rep(-Inf, q)
  lb_up[k] <- fit$theta[k] + 0.3
  ok <- .sem_gate(pin_at(mod, smp, fit$theta, k, lb_up[k]), 3L, mod$ram, smp, lb_up, rep(Inf, q), empty_cons(q))
  expect_true(ok$accepted)
  expect_length(ok$sign_warnings, 0L)
})

test_that("planted defect: a wrong bound-row sign gives a false alarm on the correct bounded fit", {
  mod <- sem_model_observed()
  smp <- .sem_sample(sem_sim(mod, 200, 7), mod$ram)
  q <- mod$ram$q
  fit <- .sem_optimize(mod$ram, smp, sem_start(mod$ram))
  k <- match("Y ~ M", mod$ram$par_names)
  lb_up <- rep(-Inf, q)
  lb_up[k] <- fit$theta[k] + 0.3
  pt <- pin_at(mod, smp, fit$theta, k, lb_up[k])
  good <- .sem_gate(pt, 3L, mod$ram, smp, lb_up, rep(Inf, q), empty_cons(q))
  expect_length(good$sign_warnings, 0L)
  src <- paste(deparse(.sem_sign_check), collapse = "\n")
  mut <- sub("e[i] <- -1", "e[i] <- 1", src, fixed = TRUE)
  expect_false(identical(mut, src))
  testthat::local_mocked_bindings(.sem_sign_check = eval(parse(text = mut), environment(.sem_sign_check)))
  bad <- .sem_gate(pt, 3L, mod$ram, smp, lb_up, rep(Inf, q), empty_cons(q))
  expect_length(bad$sign_warnings, 1L)
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
