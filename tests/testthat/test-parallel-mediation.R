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
  # 0.5*0.6 + 0.4*0.3 = 0.30 + 0.12 = 0.42
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
  # indirect = 0.5*0.6 + (-0.5)*0.6 = 0; total = 0
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
  # 0.30 + 0.12 + 0.06 = 0.48
  expect_equal(as.numeric(nie(pmd)), 0.48)
  expect_identical(names(paths(pmd)),
                   c("a1", "b1", "a2", "b2", "a3", "b3", "c_prime"))
})
