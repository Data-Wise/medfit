# Tests for off-diagonal covariance preservation in the lavaan extractor
#
# Regression tests for the bug where extract_mediation_lavaan() copied only the
# DIAGONAL variance for the a/b/c_prime aliases, dropping the off-diagonal
# covariances cov(a, b), cov(a, c'), cov(b, c') from the returned @vcov.
#
# In a single-equation SEM the path coefficients are estimated jointly, so the
# alias block must reproduce lavaan::vcov() exactly -- including off-diagonals.
# The buggy code zero-initialised the alias rows/cols and only filled the
# diagonal, so e.g. cov(b, c') came back as 0 even though b and c' share the
# outcome equation and are genuinely correlated. Dropping these covariances
# silently biases downstream indirect-effect confidence intervals.
#
# Note: Tests are skipped if lavaan is not installed

skip_if_not_installed("lavaan")

# --- Test Data Generator ---

make_cov_data <- function(n = 200, seed = 1) {
  set.seed(seed)
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.4 * M + 0.2 * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}


# ==============================================================================
# Full path-block matches lavaan::vcov (labeled model)
# ==============================================================================

test_that("lavaan extractor reproduces full a/b/c' covariance block", {
  skip_if_not_installed("lavaan")

  dat <- make_cov_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = dat)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  v <- med_data@vcov

  # Aliases present and look-up-able by name.
  expect_true(all(c("a", "b", "c_prime") %in% rownames(v)))
  expect_true(all(c("a", "b", "c_prime") %in% colnames(v)))

  lav_v <- lavaan::vcov(fit)

  # The 3x3 alias block must equal the true lavaan covariance among a/b/cp,
  # including ALL off-diagonals -- this is the core acceptance criterion.
  block <- v[c("a", "b", "c_prime"), c("a", "b", "c_prime")]
  true_block <- lav_v[c("a", "b", "cp"), c("a", "b", "cp")]
  dimnames(true_block) <- dimnames(block)
  expect_equal(block, true_block, tolerance = 1e-8)
})

test_that("lavaan extractor preserves the non-zero off-diagonal cov(b, c')", {
  skip_if_not_installed("lavaan")

  dat <- make_cov_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = dat)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  v <- med_data@vcov
  lav_v <- lavaan::vcov(fit)

  # b and c' are jointly estimated in the Y equation -> genuinely non-zero.
  true_cov_bcp <- lav_v["b", "cp"]
  expect_true(abs(true_cov_bcp) > 1e-6)

  # KEY: the buggy diagonal-only copy returned 0 here. Now it matches lavaan.
  expect_equal(v["b", "c_prime"], true_cov_bcp, tolerance = 1e-8)
  expect_equal(v["c_prime", "b"], true_cov_bcp, tolerance = 1e-8)
  expect_false(isTRUE(all.equal(v["b", "c_prime"], 0)))

  # Other alias covariances also match (cov(a, b), cov(a, c')).
  expect_equal(v["a", "b"], lav_v["a", "b"], tolerance = 1e-8)
  expect_equal(v["a", "c_prime"], lav_v["a", "cp"], tolerance = 1e-8)

  # Diagonal variances still correct.
  expect_equal(v["a", "a"], lav_v["a", "a"], tolerance = 1e-8)
  expect_equal(v["b", "b"], lav_v["b", "b"], tolerance = 1e-8)
  expect_equal(v["c_prime", "c_prime"], lav_v["cp", "cp"], tolerance = 1e-8)
})

test_that("alias<->original cross-covariances are preserved", {
  skip_if_not_installed("lavaan")

  dat <- make_cov_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = dat)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  v <- med_data@vcov
  lav_v <- lavaan::vcov(fit)

  # cov between alias "b" and the original residual-variance parameter Y~~Y
  # must match cov(cp-source, Y~~Y) etc. Check the whole "b" row against the
  # source "b" row over the original parameters.
  orig <- colnames(lav_v)
  expect_equal(
    unname(v["b", orig]),
    unname(lav_v["b", orig]),
    tolerance = 1e-8
  )
})

test_that("expanded vcov stays symmetric and the path block is PSD", {
  skip_if_not_installed("lavaan")

  dat <- make_cov_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = dat)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  v <- med_data@vcov

  expect_equal(v, t(v), tolerance = 1e-12)

  block <- v[c("a", "b", "c_prime"), c("a", "b", "c_prime")]
  eig <- eigen(block, symmetric = TRUE, only.values = TRUE)$values
  expect_true(all(eig >= -1e-8))
})


# ==============================================================================
# Off-diagonal covariance preserved for unlabeled model (by-name fallback)
# ==============================================================================

test_that("lavaan extractor preserves off-diagonals for unlabeled model", {
  skip_if_not_installed("lavaan")

  dat <- make_cov_data()

  # No labels: lavaan names params "M~X", "Y~M", "Y~X".
  model <- "
    M ~ X
    Y ~ M + X
  "

  fit <- lavaan::sem(model, data = dat)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  v <- med_data@vcov
  lav_v <- lavaan::vcov(fit)

  true_cov_bcp <- lav_v["Y~M", "Y~X"]
  expect_true(abs(true_cov_bcp) > 1e-6)

  expect_equal(v["b", "c_prime"], true_cov_bcp, tolerance = 1e-8)
  expect_equal(v["a", "b"], lav_v["M~X", "Y~M"], tolerance = 1e-8)
  expect_equal(v["a", "c_prime"], lav_v["M~X", "Y~X"], tolerance = 1e-8)
})
