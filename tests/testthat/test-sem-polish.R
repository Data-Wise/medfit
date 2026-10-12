# Native SEM engine: Newton polish of a solution with an active nonlinear row (`.sem_polish()`).
# SLSQP stops along a flat constraint tangent, so an accepted `cp == a*b` fit can sit 1e-5 from the optimum;
# the polish takes Newton steps on the KKT system and the acceptance gate re-checks the result. Oracle: a fit
# with cp replaced by a*b, solved by BFGS on the analytic gradient (the exact optimum). Planted defects: the
# polish switched off, a step in the wrong direction, and a polished point that violates the constraint.

pol_syntax <- "M ~ a*X\nY ~ b*M + cp*X\ncp == a*b"

# Seed 17 at n = 100 leaves the unpolished fit 1.8e-5 from the optimum (measured over seeds 1 to 25).
pol_data <- function(n = 100, seed = 17) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n, sd = 0.8)
  data.frame(X = x, M = m, Y = 0.4 * m + 0.2 * x + stats::rnorm(n, sd = 0.7))
}

pol_exact <- function(fit) {
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  nm <- gsub(" ", "", ram$par_names, fixed = TRUE)
  ic <- match("cp", nm)
  ia <- match("a", nm)
  ib <- match("b", nm)
  free <- setdiff(seq_along(nm), ic)
  pa <- match(ia, free)
  pb <- match(ib, free)
  to_theta <- function(phi) {
    th <- numeric(length(nm))
    th[free] <- phi
    th[ic] <- th[ia] * th[ib]
    th
  }
  grad <- function(phi) {
    g <- .sem_eval(to_theta(phi), ram, smp, deriv = TRUE)$g
    out <- g[free]
    out[pa] <- out[pa] + g[ic] * phi[pb]
    out[pb] <- out[pb] + g[ic] * phi[pa]
    out
  }
  opt <- stats::optim(
    unname(fit@theta)[free], function(p) .sem_eval(to_theta(p), ram, smp, deriv = FALSE)$f, grad,
    method = "BFGS", control = list(reltol = 1e-15, maxit = 5000)
  )
  to_theta(opt$par)
}

pol_gap <- function(fit, exact) max(abs(unname(fit@theta) - exact))

test_that("the polish lands a nonlinear-equality fit on the exact optimum", {
  d <- pol_data()
  fit <- fit_sem(pol_syntax, d)
  exact <- pol_exact(fit)
  expect_lt(pol_gap(fit, exact), 1e-9)
  th <- stats::setNames(unname(fit@theta), gsub(" ", "", names(fit@theta), fixed = TRUE))
  expect_lt(abs(th[["cp"]] - th[["a"]] * th[["b"]]), 1e-12)
  # without the polish the same fit is 1.8e-5 away: the test can fail
  off <- testthat::with_mocked_bindings(fit_sem(pol_syntax, d), .sem_polish = function(...) NULL)
  expect_gt(pol_gap(off, exact), 1e-5)
})

test_that("the polish returns to the optimum from a point 3e-5 along the constraint tangent", {
  fit <- fit_sem(pol_syntax, pol_data())
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  cons <- .sem_constraint_rows(fit@internals$constraints, ram)
  lb <- rep(-Inf, ram$q)
  ub <- rep(Inf, ram$q)
  star <- unname(fit@theta)
  act <- .sem_active_set(star, ram, smp, lb, ub, cons)
  expect_equal(ncol(act$z_theta), ram$q - 1L)
  start <- star + 3e-5 * act$z_theta[, 1L] / sqrt(sum(act$z_theta[, 1L]^2))
  pol <- .sem_polish(start, ram, smp, lb, ub, cons)
  expect_false(is.null(pol))
  expect_lt(max(abs(pol - star)), 1e-9)
  # a step in the wrong direction raises the KKT merit, so nothing is returned
  wrong <- sem_mutate(.sem_polish, "th[cur$free] + cur$step", "th[cur$free] - cur$step")
  expect_null(wrong(start, ram, smp, lb, ub, cons))
})

test_that("only a fit with an active nonlinear row is polished", {
  d <- pol_data()
  lin <- fit_sem("M ~ a*X\nY ~ b*M + cp*X\na == b", d)
  ram <- lin@internals$ram
  smp <- .sem_sample(lin@data, ram)
  cons <- .sem_constraint_rows(lin@internals$constraints, ram)
  expect_null(.sem_polish(unname(lin@theta), ram, smp, rep(-Inf, ram$q), rep(Inf, ram$q), cons))
  expect_null(.sem_polish(unname(lin@theta), ram, smp, rep(-Inf, ram$q), rep(Inf, ram$q), .sem_no_cons(ram$q)))
})

test_that("a polish that breaks the constraint or is worse is never kept", {
  fit <- fit_sem(pol_syntax, pol_data())
  ram <- fit@internals$ram
  smp <- .sem_sample(fit@data, ram)
  cons <- .sem_constraint_rows(fit@internals$constraints, ram)
  lb <- rep(-Inf, ram$q)
  ub <- rep(Inf, ram$q)
  th <- unname(fit@theta)
  gate <- .sem_gate(th, 1L, ram, smp, lb, ub, cons)
  expect_true(gate$accepted)
  res <- list(solution = th, status = 1L, objective = .sem_eval(th, ram, smp, deriv = FALSE)$f)
  # planted defect: a polished point 1e-3 off the constraint (cp moved) passes the stationarity test no better
  # than it passes the feasibility test, so the gate refuses it and the accepted solution stands
  bent <- th
  ic <- match("cp", gsub(" ", "", ram$par_names, fixed = TRUE))
  bent[ic] <- bent[ic] + 1e-3
  testthat::local_mocked_bindings(.sem_polish = function(...) bent)
  kept <- .sem_polish_accept(res, gate, ram, smp, lb, ub, cons)
  expect_identical(kept$res$solution, th)
  expect_identical(kept$gate, gate)
})
