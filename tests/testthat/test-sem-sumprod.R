# Native SEM engine: a sum of products set to zero, best-effort (T16, G12).
# `a1*b1 + a2*b2 == 0` has no exact branch reduction (unlike a single product), so it is fitted by the
# nonlinear route with best-of-n starts; the starts-disagree warning is the signal that a better optimum may
# exist. Fixtures are parallel-mediator data: effects of 0.9 on one path and 0.1 on the other leave several
# local optima; moderate effects leave one.

sp_syntax <- "M1 ~ a1*X\nM2 ~ a2*X\nY ~ b1*M1 + b2*M2 + cp*X\na1*b1 + a2*b2 == 0"

sp_data <- function(a1, b1, a2, b2, n = 300, seed = 1) {
  set.seed(seed)
  x <- stats::rnorm(n)
  m1 <- a1 * x + stats::rnorm(n, sd = 0.5)
  m2 <- a2 * x + stats::rnorm(n, sd = 0.5)
  y <- b1 * m1 + b2 * m2 + 0.2 * x + stats::rnorm(n, sd = 0.5)
  data.frame(X = x, M1 = m1, M2 = m2, Y = y)
}

test_that("a sum of products set to zero fits and satisfies the constraint", {
  d <- sp_data(0.9, 0.9, 0.1, 0.1)
  fit <- suppressWarnings(fit_sem(sp_syntax, d))
  th <- coef(fit)
  expect_lt(abs(th[["a1"]] * th[["b1"]] + th[["a2"]] * th[["b2"]]), 1e-6)
  expect_identical(fit@diagnostics$active_constraints, "a1*b1 + a2*b2 == 0")
})

test_that("the fixture warns when the starts disagree, and more starts are never worse", {
  d <- sp_data(0.9, 0.9, 0.1, 0.1)
  expect_warning(fit5 <- fit_sem(sp_syntax, d), "the starts disagree")
  fit20 <- suppressWarnings(fit_sem(sp_syntax, d, n_starts = 20))
  expect_lte(fit20@f, fit5@f + 1e-9)
})

test_that("the warning is silent when the starts agree", {
  d <- sp_data(0.5, 0.4, 0.5, 0.3)
  expect_no_warning(fit_sem(sp_syntax, d))
})

test_that("the syntax help and the constraints page say it is best-effort", {
  path <- testthat::test_path("..", "..", "R", "sem-syntax-help.R")
  page <- testthat::test_path("..", "..", "vignettes", "articles", "model-native-constraints.qmd")
  if (!file.exists(path) || !file.exists(page)) testthat::skip("package sources not available")
  expect_match(paste(readLines(path), collapse = " "), "sum of products.*best-effort", perl = TRUE)
  expect_match(paste(readLines(page), collapse = " "), "sum of products.*best-effort", perl = TRUE)
})
