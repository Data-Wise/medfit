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
