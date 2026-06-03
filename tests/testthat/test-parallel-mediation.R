# Tests for ParallelMediationData (Extension A)

make_parallel <- function(a = c(0.5, 0.4), b = c(0.6, 0.3), cp = 0.2,
                          mediators = c("M1", "M2")) {
  k <- length(mediators)
  ParallelMediationData(
    a_paths = a,
    b_paths = b,
    c_prime = cp,
    estimates = c(a, b, cp),
    vcov = diag(0.01, length(c(a, b, cp))),
    treatment = "X",
    mediators = mediators,
    outcome = "Y",
    mediator_predictors = rep(list("X"), k),
    outcome_predictors = c("X", mediators),
    n_obs = 200L,
    converged = TRUE,
    source_package = "medfit"
  )
}

test_that("ParallelMediationData constructs with valid input", {
  pmd <- make_parallel()
  expect_s3_class(pmd, "medfit::ParallelMediationData")
  expect_length(pmd@a_paths, 2)
  expect_length(pmd@b_paths, 2)
  expect_identical(pmd@mediators, c("M1", "M2"))
})

test_that("validator requires >= 2 mediators", {
  expect_error(
    make_parallel(a = 0.5, b = 0.6, mediators = "M1"),
    "at least 2 mediators"
  )
})

test_that("validator requires a_paths and b_paths to match mediator count", {
  expect_error(
    ParallelMediationData(
      a_paths = c(0.5, 0.4, 0.3),  # 3 vs 2 mediators
      b_paths = c(0.6, 0.3),
      c_prime = 0.2,
      estimates = c(0.5, 0.4, 0.3, 0.6, 0.3, 0.2),
      vcov = diag(0.01, 6),
      treatment = "X",
      mediators = c("M1", "M2"),
      outcome = "Y",
      mediator_predictors = list("X", "X"),
      outcome_predictors = c("X", "M1", "M2"),
      n_obs = 100L, converged = TRUE, source_package = "medfit"
    ),
    "a_paths must have length 2"
  )
})

test_that("validator rejects duplicate mediator names", {
  expect_error(
    make_parallel(mediators = c("M1", "M1")),
    "unique"
  )
})

test_that("nie sums the per-mediator products", {
  pmd <- make_parallel(a = c(0.5, 0.4), b = c(0.6, 0.3))
  # a1*b1 plus a2*b2 gives 0.30 plus 0.12, i.e. 0.42
  expect_equal(as.numeric(nie(pmd)), 0.42)
  expect_equal(attr(nie(pmd), "type"), "nie")
  expect_equal(attr(nie(pmd), "n_mediators"), 2L)
})

test_that("nde returns the direct effect", {
  pmd <- make_parallel(cp = 0.2)
  expect_equal(as.numeric(nde(pmd)), 0.2)
})

test_that("te equals indirect + direct, and nie + nde == te", {
  pmd <- make_parallel(a = c(0.5, 0.4), b = c(0.6, 0.3), cp = 0.2)
  expect_equal(as.numeric(te(pmd)), 0.42 + 0.2)
  expect_equal(as.numeric(nie(pmd)) + as.numeric(nde(pmd)),
               as.numeric(te(pmd)))
})

test_that("pm is indirect / total and guards the zero-total case", {
  pmd <- make_parallel(a = c(0.5, 0.4), b = c(0.6, 0.3), cp = 0.2)
  expect_equal(as.numeric(pm(pmd)), 0.42 / 0.62)

  zero_total <- make_parallel(a = c(0.5, -0.5), b = c(0.6, 0.6), cp = 0)
  # indirect cancels to zero (one positive, one equal-and-opposite); direct is zero too
  expect_warning(res <- pm(zero_total), "undefined")
  expect_true(is.na(res))
})

test_that("paths returns interleaved a_j/b_j with c_prime", {
  pmd <- make_parallel(a = c(0.5, 0.4), b = c(0.6, 0.3), cp = 0.2)
  p <- paths(pmd)
  expect_identical(names(p), c("a1", "b1", "a2", "b2", "c_prime"))
  expect_equal(unname(p), c(0.5, 0.6, 0.4, 0.3, 0.2))
})

test_that("print method runs without error", {
  pmd <- make_parallel()
  expect_output(print(pmd), "ParallelMediationData")
  expect_output(print(pmd), "parallel mediators")
})

test_that("scales to 3 parallel mediators", {
  pmd <- make_parallel(
    a = c(0.5, 0.4, 0.3), b = c(0.6, 0.3, 0.2),
    mediators = c("M1", "M2", "M3")
  )
  # three products sum to 0.48 (0.30 and 0.12 and 0.06)
  expect_equal(as.numeric(nie(pmd)), 0.48)
  expect_identical(names(paths(pmd)),
                   c("a1", "b1", "a2", "b2", "a3", "b3", "c_prime"))
})

test_that("optional residual SDs are accepted when well-formed", {
  pmd <- ParallelMediationData(
    a_paths = c(0.5, 0.4), b_paths = c(0.6, 0.3), c_prime = 0.2,
    estimates = c(0.5, 0.4, 0.6, 0.3, 0.2), vcov = diag(0.01, 5),
    sigma_mediators = c(1.0, 1.1), sigma_y = 0.9,
    treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
    mediator_predictors = list("X", "X"), outcome_predictors = c("X", "M1", "M2"),
    n_obs = 200L, converged = TRUE, source_package = "medfit"
  )
  expect_equal(pmd@sigma_mediators, c(1.0, 1.1))
  expect_equal(pmd@sigma_y, 0.9)
})

test_that("validator rejects wrong-length sigma_mediators and negative sigma_y", {
  base <- list(
    a_paths = c(0.5, 0.4), b_paths = c(0.6, 0.3), c_prime = 0.2,
    estimates = c(0.5, 0.4, 0.6, 0.3, 0.2), vcov = diag(0.01, 5),
    treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
    mediator_predictors = list("X", "X"), outcome_predictors = c("X", "M1", "M2"),
    n_obs = 200L, converged = TRUE, source_package = "medfit"
  )
  expect_error(do.call(ParallelMediationData, c(base, list(sigma_mediators = 1.0))),
               "sigma_mediators must have length 2")
  expect_error(do.call(ParallelMediationData, c(base, list(sigma_y = -1))),
               "non-negative scalar")
})

test_that("validator rejects non-square vcov and estimates/vcov mismatch", {
  expect_error(
    ParallelMediationData(
      a_paths = c(0.5, 0.4), b_paths = c(0.6, 0.3), c_prime = 0.2,
      estimates = c(0.5, 0.4, 0.6, 0.3, 0.2),
      vcov = matrix(0.01, nrow = 5, ncol = 4),  # non-square
      treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
      mediator_predictors = list("X", "X"), outcome_predictors = c("X", "M1", "M2"),
      n_obs = 200L, converged = TRUE, source_package = "medfit"
    ),
    "vcov must be a square matrix"
  )
  expect_error(
    ParallelMediationData(
      a_paths = c(0.5, 0.4), b_paths = c(0.6, 0.3), c_prime = 0.2,
      estimates = c(0.5, 0.4, 0.6),              # length 3 vs 4x4 vcov
      vcov = diag(0.01, 4),
      treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
      mediator_predictors = list("X", "X"), outcome_predictors = c("X", "M1", "M2"),
      n_obs = 200L, converged = TRUE, source_package = "medfit"
    ),
    "estimates must match vcov"
  )
})

test_that("coef/vcov/nobs methods work", {
  pmd <- make_parallel(a = c(0.5, 0.4), b = c(0.6, 0.3), cp = 0.2)
  expect_identical(names(coef(pmd, "paths")), c("a1", "b1", "a2", "b2", "c_prime"))
  expect_equal(unname(coef(pmd, "effects")), c(0.42, 0.2, 0.62))
  expect_equal(coef(pmd, "all"), pmd@estimates)
  expect_equal(dim(vcov(pmd)), c(5L, 5L))
  expect_identical(nobs(pmd), 200L)
})

test_that("show method dispatches to print", {
  pmd <- make_parallel()
  expect_output(methods::show(pmd), "ParallelMediationData")
})
