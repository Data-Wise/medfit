# Issue #213 (0.11.0 plan T2): a nonlinear equality constraint with unbounded residual variances lets the solver step to
# a negative variance. The constrained fit at a constraint value the unconstrained MLE already satisfies must reproduce
# the unconstrained fit (LR = 0). These tests are RED until T3; the frozen unconstrained and linear-constrained fits
# must stay as they are.

nv_model <- "M ~ a*X\nY ~ cp*X + b*M\nM ~~ Vm*M\nY ~~ Vy*Y"

nv_data <- function(seed, a, b, sigma_y2) {
  set.seed(seed)
  n <- 250
  d <- data.frame(X = stats::rbinom(n, 1, 0.5))
  d$M <- a * d$X + stats::rnorm(n)
  d$Y <- 0.3 * d$X + b * d$M + sqrt(sigma_y2) * stats::rnorm(n)
  d
}

# the constraint a*b/sqrt(2*(b^2*Vm+Vy)) == q, with q read off the unconstrained fit, so it holds there
nv_constrained <- function(d, h1, ...) {
  cf <- stats::coef(h1)
  q <- cf[["a"]] * cf[["b"]] / sqrt(2 * (cf[["b"]]^2 * cf[["Vm"]] + cf[["Vy"]]))
  fit_sem(paste0(nv_model, "\na*b/sqrt(2*(b^2*Vm+Vy)) == ", format(q, digits = 17)), d, ...)
}

nv_lr <- function(h1, h2) 2 * (as.numeric(stats::logLik(h1)) - as.numeric(stats::logLik(h2)))

# Warnings other than the multi-start spread note: the fix is about NaN standard errors and a far-off stop, and a
# "starts disagree" note is legitimate for a nonlinear row (CLAUDE.md), so it must not decide these tests.
nv_nan_warnings <- function(expr) {
  w <- character()
  value <- withCallingHandlers(expr, warning = function(c) {
    w <<- c(w, conditionMessage(c))
    invokeRestart("muffleWarning")
  })
  list(value = value, nan = grep("NaN", w, value = TRUE))
}

test_that("#213 seed 1: the constrained fit at the unconstrained MLE reproduces it (LR about 0)", {
  d <- nv_data(1, 1.5, 1, 1)
  h1 <- fit_sem(nv_model, d)
  h2 <- nv_constrained(d, h1, n_starts = 8)
  expect_lt(abs(nv_lr(h1, h2)), 1e-3)
  expect_equal(stats::coef(h2)[names(stats::coef(h1))], stats::coef(h1), tolerance = 1e-4)
})

test_that("#213 seed 101 (a = 2.5, b = 1.5, sigma_Y^2 = 2): no far-off stop and no NaN standard errors", {
  d <- nv_data(101, 2.5, 1.5, 2)
  h1 <- fit_sem(nv_model, d)
  r <- nv_nan_warnings(nv_constrained(d, h1, n_starts = 8))
  expect_length(r$nan, 0)
  expect_lt(abs(nv_lr(h1, r$value)), 1e-3)
  expect_true(all(stats::coef(r$value)[c("Vm", "Vy")] > 0))
})

test_that("#213 default n_starts: both cases fit and reproduce the unconstrained fit", {
  for (args in list(c(1, 1.5, 1, 1), c(101, 2.5, 1.5, 2))) {
    d <- nv_data(args[1], args[2], args[3], args[4])
    h1 <- fit_sem(nv_model, d)
    h2 <- suppressWarnings(nv_constrained(d, h1))
    expect_lt(abs(nv_lr(h1, h2)), 1e-3)
  }
})

test_that("frozen: the unconstrained fit is unchanged", {
  h1 <- fit_sem(nv_model, nv_data(1, 1.5, 1, 1))
  expect_equal(
    unname(stats::coef(h1)),
    c(1.6207555059629293, 0.33389304220197757, 1.1022904459970113, 1.0177303562479751, 1.123522944064872,
      0.24998400103532953),
    tolerance = 1e-9
  )
  expect_equal(as.numeric(stats::logLik(h1)), -907.66463531393788, tolerance = 1e-9)
})

test_that("frozen: a linear-constrained fit is unchanged", {
  h2 <- fit_sem("M ~ a*X\nY ~ cp*X + b*M\na == 0.5", nv_data(1, 1.5, 1, 1))
  expect_equal(
    unname(stats::coef(h2)),
    c(0.5, 0.33389304371404077, 1.1022904446383688, 1.3317334916166899, 1.1235229427205182, 0.24998399967914409),
    tolerance = 1e-7
  )
})
