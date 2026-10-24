# Native SEM engine: nonlinear inequalities, the Lagrangian-Hessian gate and best-of-n starts (T15).
# `a*b > k` is feasible on two disjoint pieces (both paths positive or both negative), so a fit has a
# global branch and a worse local one. Oracles: the two branch fits with the signs fixed by bounds and the
# product held at k by an equality (single-valued problems), and the unconstrained fit when the constraint
# is inactive. Planted defect: the gate's Hessian of the Lagrangian replaced by the objective's Hessian.

ni_base <- "M ~ a*X\nY ~ b*M + cp*X"

ni_data <- function(n = 300, seed = 3, a = 0.5, b = 0.4, cp = 0.2) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- a * x + stats::rnorm(n, sd = 0.8)
  y <- b * m + cp * x + stats::rnorm(n, sd = 0.7)
  data.frame(X = x, M = m, Y = y)
}

ni_fit <- function(extra, d, ...) {
  suppressWarnings(fit_sem(paste0(ni_base, "\n", extra), d, ..., fixed_x = FALSE, meanstructure = NULL))
}

# Best objective over the two feasible pieces of `a*b = k`, each a single-valued problem.
ni_branch_f <- function(k, d, op = "==") {
  pos <- ni_fit(paste0("a > 0\nb > 0\na*b ", op, " ", k), d)@f
  neg <- ni_fit(paste0("a < 0\nb < 0\na*b ", op, " ", k), d)@f
  min(pos, neg)
}

test_that("an active a*b > k lands on the product's boundary at the best branch", {
  d <- ni_data()
  fit <- ni_fit("a*b > 0.4", d)
  th <- coef(fit)
  expect_lt(abs(th[["a"]] * th[["b"]] - 0.4), 1e-6)
  expect_identical(fit@diagnostics$active_constraints, "a*b > 0.4")
  expect_lt(abs(fit@f - ni_branch_f(0.4, d)), 1e-8)
})

test_that("a*b < k is the same row with the other sign, and a defined name gives the same fit", {
  d <- ni_data()
  up <- ni_fit("a*b < 0.1", d)
  expect_lt(abs(coef(up)[["a"]] * coef(up)[["b"]] - 0.1), 1e-6)
  expect_lt(abs(up@f - ni_branch_f(0.1, d)), 1e-8)
  via_def <- ni_fit("ab := a*b\nab > 0.4", d)
  direct <- ni_fit("a*b > 0.4", d)
  expect_equal(via_def@f, direct@f, tolerance = 1e-9)
  expect_equal(unname(coef(via_def)), unname(coef(direct)), tolerance = 1e-5)
})

test_that("an inactive nonlinear inequality leaves the unconstrained fit unchanged and silent", {
  d <- ni_data()
  free <- fit_sem(ni_base, d, fixed_x = FALSE, meanstructure = NULL)
  fit <- expect_no_warning(fit_sem(paste0(ni_base, "\na*b > 0.01"), d, fixed_x = FALSE, meanstructure = NULL))
  expect_equal(fit@f, free@f, tolerance = 1e-9)
  expect_length(fit@diagnostics$active_constraints, 0L)
})

test_that("the spread warning fires when the starts reach different optima and not when they agree", {
  d <- ni_data()
  expect_warning(fit_sem(paste0(ni_base, "\na*b > 0.4"), d,
                         fixed_x = FALSE, meanstructure = NULL), "the starts disagree")
  # the equality cp == a*b has one optimum: every start reaches it
  expect_no_warning(fit_sem(paste0(ni_base, "\ncp == a*b"), d, fixed_x = FALSE, meanstructure = NULL))
})

test_that("a*b > k reaches the best branch in at least 90% of fits with 5 starts", {
  hit <- vapply(1:20, function(seed) {
    d <- ni_data(seed = seed)
    fit <- ni_fit("a*b > 0.4", d)
    abs(fit@f - ni_branch_f(0.4, d)) < 1e-7
  }, TRUE)
  expect_gte(mean(hit), 0.9)
})

# Fit internals for a mocked gate: the model of ni_base with cp == a*b-style rows built by hand.
ni_gate <- function(h, lambda, constraint = "a*b == 1") {
  fit <- ni_fit(constraint, ni_data())
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  cons <- .sem_constraint_rows(fit@internals$constraints, ram)
  nm <- names(coef(fit))
  th <- stats::setNames(rep(1, ram$q), nm)
  th[["cp"]] <- 0.1
  q <- ram$q
  # KKT point of a synthetic objective: g = -lambda * grad c, with grad c = (b, a) = (1, 1) on (a, b)
  g <- numeric(q)
  g[match(c("a", "b"), nm)] <- -lambda
  hess <- diag(1, q)
  hess[cbind(match(c("a", "b"), nm), match(c("a", "b"), nm))] <- h
  testthat::local_mocked_bindings(
    .sem_eval = function(theta, ram, smp, deriv = FALSE) list(f = 0, g = g),
    .sem_hess_f = function(theta, ram, smp) hess
  )
  .sem_gate_projected(unname(th), 4L, ram, smp, rep(-Inf, q), rep(Inf, q), cons)
}

test_that("the gate judges the reduced Hessian of the Lagrangian: a saddle of the restricted problem is rejected", {
  # h = 1 on a and b, multiplier 3: the tangent curvature is (1 + 1)/2 - 3 < 0, although the objective's
  # Hessian alone gives +1
  bad <- ni_gate(h = 1, lambda = 3)
  expect_false(bad$accepted)
  expect_match(bad$reason, "reduced Hessian is not positive definite")
})

test_that("the gate accepts a minimum of the restricted problem whose objective Hessian is indefinite on the tangent", {
  # h = -0.2 on a and b, multiplier -1: the tangent curvature is -0.2 + 1 > 0
  ok <- ni_gate(h = -0.2, lambda = -1)
  expect_true(ok$accepted)
})

test_that("planted defect: the Hessian of the Lagrangian replaced by the objective's Hessian flips both verdicts", {
  testthat::local_mocked_bindings(.sem_lagrangian_hessian = function(hx, ...) hx)
  expect_true(ni_gate(h = 1, lambda = 3)$accepted)
  expect_false(ni_gate(h = -0.2, lambda = -1)$accepted)
})
