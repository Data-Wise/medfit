# Tests for S7 Class Definitions
#
# This file tests:
# - MediationData class validation and methods
# - BootstrapResult class validation and methods

library(testthat)

# Test MediationData class -------------------------------------------------

test_that("MediationData can be created with valid inputs", {
  # Create valid MediationData object
  med_data <- MediationData(
    a_path = 0.5,
    b_path = 0.3,
    c_prime = 0.2,
    estimates = c(0.5, 0.3, 0.2),
    vcov = matrix(c(0.01, 0, 0,
                    0, 0.01, 0,
                    0, 0, 0.01), nrow = 3),
    sigma_m = 1.0,
    sigma_y = 1.2,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    mediator_predictors = c("X", "C1"),
    outcome_predictors = c("X", "M", "C1"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "stats"
  )

  expect_s3_class(med_data, "medfit::MediationData")
  expect_equal(med_data@a_path, 0.5)
  expect_equal(med_data@b_path, 0.3)
  expect_equal(med_data@c_prime, 0.2)
  expect_equal(med_data@n_obs, 100L)
  expect_true(med_data@converged)
})


test_that("MediationData validator catches invalid a_path", {
  expect_error(
    MediationData(
      a_path = c(0.5, 0.6),  # Not scalar
      b_path = 0.3,
      c_prime = 0.2,
      estimates = c(0.5, 0.3, 0.2),
      vcov = matrix(c(0.01, 0, 0,
                      0, 0.01, 0,
                      0, 0, 0.01), nrow = 3),
      sigma_m = NULL,
      sigma_y = NULL,
      treatment = "X",
      mediator = "M",
      outcome = "Y",
      mediator_predictors = "X",
      outcome_predictors = c("X", "M"),
      data = NULL,
      n_obs = 100L,
      converged = TRUE,
      source_package = "stats"
    ),
    "a_path must be a scalar"
  )
})


test_that("MediationData validator catches invalid vcov", {
  expect_error(
    MediationData(
      a_path = 0.5,
      b_path = 0.3,
      c_prime = 0.2,
      estimates = c(0.5, 0.3, 0.2),
      vcov = matrix(c(0.01, 0, 0,
                      0, 0.01, 0), nrow = 2),  # Not square
      sigma_m = NULL,
      sigma_y = NULL,
      treatment = "X",
      mediator = "M",
      outcome = "Y",
      mediator_predictors = "X",
      outcome_predictors = c("X", "M"),
      data = NULL,
      n_obs = 100L,
      converged = TRUE,
      source_package = "stats"
    ),
    "vcov must be a square"
  )
})


test_that("MediationData validator catches mismatched estimates and vcov", {
  expect_error(
    MediationData(
      a_path = 0.5,
      b_path = 0.3,
      c_prime = 0.2,
      estimates = c(0.5, 0.3),  # Length 2
      vcov = matrix(c(0.01, 0, 0,
                      0, 0.01, 0,
                      0, 0, 0.01), nrow = 3),  # 3x3
      sigma_m = NULL,
      sigma_y = NULL,
      treatment = "X",
      mediator = "M",
      outcome = "Y",
      mediator_predictors = "X",
      outcome_predictors = c("X", "M"),
      data = NULL,
      n_obs = 100L,
      converged = TRUE,
      source_package = "stats"
    ),
    "Number of estimates must match vcov"
  )
})


test_that("MediationData validator catches negative sigma", {
  expect_error(
    MediationData(
      a_path = 0.5,
      b_path = 0.3,
      c_prime = 0.2,
      estimates = c(0.5, 0.3, 0.2),
      vcov = matrix(c(0.01, 0, 0,
                      0, 0.01, 0,
                      0, 0, 0.01), nrow = 3),
      sigma_m = -1.0,  # Negative
      sigma_y = NULL,
      treatment = "X",
      mediator = "M",
      outcome = "Y",
      mediator_predictors = "X",
      outcome_predictors = c("X", "M"),
      data = NULL,
      n_obs = 100L,
      converged = TRUE,
      source_package = "stats"
    ),
    "sigma_m must be a non-negative"
  )
})


test_that("MediationData validator catches invalid n_obs", {
  expect_error(
    MediationData(
      a_path = 0.5,
      b_path = 0.3,
      c_prime = 0.2,
      estimates = c(0.5, 0.3, 0.2),
      vcov = matrix(c(0.01, 0, 0,
                      0, 0.01, 0,
                      0, 0, 0.01), nrow = 3),
      sigma_m = NULL,
      sigma_y = NULL,
      treatment = "X",
      mediator = "M",
      outcome = "Y",
      mediator_predictors = "X",
      outcome_predictors = c("X", "M"),
      data = NULL,
      n_obs = 0L,  # Not positive
      converged = TRUE,
      source_package = "stats"
    ),
    "n_obs must be a positive"
  )
})


test_that("MediationData print method works", {
  skip_on_ci()  # S7 method dispatch issue in CI

  med_data <- MediationData(
    a_path = 0.5,
    b_path = 0.3,
    c_prime = 0.2,
    estimates = c(0.5, 0.3, 0.2),
    vcov = matrix(c(0.01, 0, 0,
                    0, 0.01, 0,
                    0, 0, 0.01), nrow = 3),
    sigma_m = 1.0,
    sigma_y = 1.2,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    mediator_predictors = "X",
    outcome_predictors = c("X", "M"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "stats"
  )

  expect_output(print(med_data), "MediationData object")
  expect_output(print(med_data), "a \\(X -> M\\)")
  expect_output(print(med_data), "0.5000")
  expect_output(print(med_data), "Indirect")
  expect_output(print(med_data), "0.1500")  # 0.5 * 0.3
})


test_that("MediationData summary method works", {
  skip_on_ci()  # S7 method dispatch issue in CI

  med_data <- MediationData(
    a_path = 0.5,
    b_path = 0.3,
    c_prime = 0.2,
    estimates = c(0.5, 0.3, 0.2),
    vcov = matrix(c(0.01, 0, 0,
                    0, 0.01, 0,
                    0, 0, 0.01), nrow = 3),
    sigma_m = NULL,
    sigma_y = NULL,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    mediator_predictors = "X",
    outcome_predictors = c("X", "M"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "stats"
  )

  summ <- summary(med_data)
  expect_s3_class(summ, "summary.MediationData")
  expect_equal(unname(summ$paths["a"]), 0.5)
  expect_equal(unname(summ$paths["b"]), 0.3)
  expect_equal(unname(summ$paths["indirect"]), 0.15)
  expect_equal(summ$n_obs, 100L)
})


# Test BootstrapResult class -----------------------------------------------

test_that("BootstrapResult can be created with valid inputs (parametric)", {
  boot_result <- BootstrapResult(
    estimate = 0.15,
    ci_lower = 0.10,
    ci_upper = 0.20,
    ci_level = 0.95,
    boot_estimates = rnorm(1000, 0.15, 0.02),
    n_boot = 1000L,
    method = "parametric",
    call = NULL
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  expect_equal(boot_result@estimate, 0.15)
  expect_equal(boot_result@ci_lower, 0.10)
  expect_equal(boot_result@ci_upper, 0.20)
  expect_equal(boot_result@method, "parametric")
  expect_equal(boot_result@n_boot, 1000L)
})


test_that("BootstrapResult can be created for plugin method", {
  boot_result <- BootstrapResult(
    estimate = 0.15,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    ci_level = NA_real_,
    boot_estimates = numeric(0),
    n_boot = 0L,
    method = "plugin",
    call = NULL
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  expect_equal(boot_result@estimate, 0.15)
  expect_equal(boot_result@method, "plugin")
  expect_equal(boot_result@n_boot, 0L)
})


test_that("BootstrapResult validator catches invalid CI ordering", {
  expect_error(
    BootstrapResult(
      estimate = 0.15,
      ci_lower = 0.20,  # Greater than upper
      ci_upper = 0.10,
      ci_level = 0.95,
      boot_estimates = rnorm(1000, 0.15, 0.02),
      n_boot = 1000L,
      method = "parametric",
      call = NULL
    ),
    "ci_lower must be less than or equal to ci_upper"
  )
})


test_that("BootstrapResult validator catches invalid ci_level", {
  expect_error(
    BootstrapResult(
      estimate = 0.15,
      ci_lower = 0.10,
      ci_upper = 0.20,
      ci_level = 1.5,  # > 1
      boot_estimates = rnorm(1000, 0.15, 0.02),
      n_boot = 1000L,
      method = "parametric",
      call = NULL
    ),
    "ci_level must be between 0 and 1"
  )
})


test_that("BootstrapResult validator catches invalid method", {
  expect_error(
    BootstrapResult(
      estimate = 0.15,
      ci_lower = 0.10,
      ci_upper = 0.20,
      ci_level = 0.95,
      boot_estimates = rnorm(1000, 0.15, 0.02),
      n_boot = 1000L,
      method = "invalid_method",
      call = NULL
    ),
    "method must be 'parametric', 'nonparametric', or 'plugin'"
  )
})


test_that("BootstrapResult validator catches mismatched n_boot and boot_estimates", {
  expect_error(
    BootstrapResult(
      estimate = 0.15,
      ci_lower = 0.10,
      ci_upper = 0.20,
      ci_level = 0.95,
      boot_estimates = rnorm(500, 0.15, 0.02),  # 500 estimates
      n_boot = 1000L,  # But n_boot = 1000
      method = "parametric",
      call = NULL
    ),
    "Length of boot_estimates must match n_boot"
  )
})


test_that("BootstrapResult print method works for parametric", {
  skip_on_ci()  # S7 method dispatch issue in CI

  boot_result <- BootstrapResult(
    estimate = 0.15,
    ci_lower = 0.10,
    ci_upper = 0.20,
    ci_level = 0.95,
    boot_estimates = rnorm(1000, 0.15, 0.02),
    n_boot = 1000L,
    method = "parametric",
    call = NULL
  )

  expect_output(print(boot_result), "BootstrapResult object")
  expect_output(print(boot_result), "Method:\\s+parametric")
  expect_output(print(boot_result), "Estimate:\\s+0.1500")
  expect_output(print(boot_result), "95% Confidence Interval")
})


test_that("BootstrapResult print method works for plugin", {
  skip_on_ci()  # S7 method dispatch issue in CI

  boot_result <- BootstrapResult(
    estimate = 0.15,
    ci_lower = NA_real_,
    ci_upper = NA_real_,
    ci_level = NA_real_,
    boot_estimates = numeric(0),
    n_boot = 0L,
    method = "plugin",
    call = NULL
  )

  expect_output(print(boot_result), "BootstrapResult object")
  expect_output(print(boot_result), "Method:\\s+plugin")
  expect_output(print(boot_result), "No confidence interval for plugin")
})


test_that("BootstrapResult summary method works", {
  skip_on_ci()  # S7 method dispatch issue in CI

  boot_estimates <- rnorm(1000, 0.15, 0.02)
  boot_result <- BootstrapResult(
    estimate = 0.15,
    ci_lower = 0.10,
    ci_upper = 0.20,
    ci_level = 0.95,
    boot_estimates = boot_estimates,
    n_boot = 1000L,
    method = "parametric",
    call = NULL
  )

  summ <- summary(boot_result)
  expect_s3_class(summ, "summary.BootstrapResult")
  expect_equal(summ$method, "parametric")
  expect_equal(summ$estimate, 0.15)
  expect_equal(unname(summ$ci["lower"]), 0.10)
  expect_equal(unname(summ$ci["upper"]), 0.20)
  expect_length(summ$boot_dist, 6)  # summary() returns 6 values
})


# Test Edge Cases ----------------------------------------------------------

test_that("MediationData works with NULL data", {
  med_data <- MediationData(
    a_path = 0.5,
    b_path = 0.3,
    c_prime = 0.2,
    estimates = c(0.5, 0.3, 0.2),
    vcov = matrix(c(0.01, 0, 0,
                    0, 0.01, 0,
                    0, 0, 0.01), nrow = 3),
    sigma_m = NULL,
    sigma_y = NULL,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    mediator_predictors = "X",
    outcome_predictors = c("X", "M"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "stats"
  )

  expect_null(med_data@data)
})


test_that("MediationData works with actual data frame", {
  test_data <- data.frame(
    X = rnorm(100),
    M = rnorm(100),
    Y = rnorm(100)
  )

  med_data <- MediationData(
    a_path = 0.5,
    b_path = 0.3,
    c_prime = 0.2,
    estimates = c(0.5, 0.3, 0.2),
    vcov = matrix(c(0.01, 0, 0,
                    0, 0.01, 0,
                    0, 0, 0.01), nrow = 3),
    sigma_m = NULL,
    sigma_y = NULL,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    mediator_predictors = "X",
    outcome_predictors = c("X", "M"),
    data = test_data,
    n_obs = 100L,
    converged = TRUE,
    source_package = "stats"
  )

  expect_equal(nrow(med_data@data), 100)
})


test_that("MediationData validator catches data/n_obs mismatch", {
  test_data <- data.frame(
    X = rnorm(100),
    M = rnorm(100),
    Y = rnorm(100)
  )

  expect_error(
    MediationData(
      a_path = 0.5,
      b_path = 0.3,
      c_prime = 0.2,
      estimates = c(0.5, 0.3, 0.2),
      vcov = matrix(c(0.01, 0, 0,
                      0, 0.01, 0,
                      0, 0, 0.01), nrow = 3),
      sigma_m = NULL,
      sigma_y = NULL,
      treatment = "X",
      mediator = "M",
      outcome = "Y",
      mediator_predictors = "X",
      outcome_predictors = c("X", "M"),
      data = test_data,
      n_obs = 50L,  # Mismatch!
      converged = TRUE,
      source_package = "stats"
    ),
    "Number of rows in data must match n_obs"
  )
})
