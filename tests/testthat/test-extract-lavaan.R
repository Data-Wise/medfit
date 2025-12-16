# Tests for extract_mediation() with lavaan objects
#
# These tests require lavaan to be installed. They will be skipped if
# lavaan is not available.

test_that("extract_mediation works with basic lavaan model", {
  skip_if_not_installed("lavaan")

  # Create test data
  set.seed(123)
  n <- 200
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Define and fit lavaan model
  model <- "
    M ~ X
    Y ~ M + X
  "
  fit <- lavaan::sem(model, data = test_data)

  # Extract mediation structure
  med_data <- extract_mediation(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  # Check class
  expect_true(S7::S7_inherits(med_data, MediationData))

  # Check variable names
  expect_equal(med_data@treatment, "X")
  expect_equal(med_data@mediator, "M")
  expect_equal(med_data@outcome, "Y")

  # Check that paths are reasonable
  expect_true(abs(med_data@a_path - 0.5) < 0.2)
  expect_true(abs(med_data@b_path - 0.4) < 0.2)
  expect_true(abs(med_data@c_prime - 0.3) < 0.2)

  # Check metadata
  expect_equal(med_data@n_obs, n)
  expect_true(med_data@converged)
  expect_equal(med_data@source_package, "lavaan")
})


test_that("extract_mediation works with labeled lavaan model", {
  skip_if_not_installed("lavaan")

  # Create test data
  set.seed(456)
  n <- 200
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Define model with labels
  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "
  fit <- lavaan::sem(model, data = test_data)

  # Extract mediation structure
  med_data <- extract_mediation(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  # Check class
  expect_true(S7::S7_inherits(med_data, MediationData))

  # Check paths
  expect_true(is.numeric(med_data@a_path))
  expect_true(is.numeric(med_data@b_path))
  expect_true(is.numeric(med_data@c_prime))
})


test_that("extract_mediation auto-detects outcome variable", {
  skip_if_not_installed("lavaan")

  # Create test data
  set.seed(789)
  n <- 200
  treatment <- rnorm(n)
  mediator <- 0.5 * treatment + rnorm(n)
  response <- 0.3 * treatment + 0.4 * mediator + rnorm(n)
  test_data <- data.frame(treatment = treatment, mediator = mediator, response = response)

  # Define model
  model <- "
    mediator ~ treatment
    response ~ mediator + treatment
  "
  fit <- lavaan::sem(model, data = test_data)

  # Extract without specifying outcome
  med_data <- extract_mediation(
    fit,
    treatment = "treatment",
    mediator = "mediator"
  )

  # Should auto-detect "response" as outcome
  expect_equal(med_data@outcome, "response")
})


test_that("extract_mediation works with covariates in lavaan", {
  skip_if_not_installed("lavaan")

  # Create test data
  set.seed(101)
  n <- 200
  X <- rnorm(n)
  C <- rnorm(n)
  M <- 0.5 * X + 0.2 * C + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + 0.15 * C + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y, C = C)

  # Define model with covariate
  model <- "
    M ~ X + C
    Y ~ M + X + C
  "
  fit <- lavaan::sem(model, data = test_data)

  # Extract mediation structure
  med_data <- extract_mediation(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  # Check that covariates are in predictors
  expect_true("C" %in% med_data@mediator_predictors)
  expect_true("C" %in% med_data@outcome_predictors)
})


test_that("extract_mediation validates required arguments for lavaan", {
  skip_if_not_installed("lavaan")

  # Create simple fitted model
  set.seed(111)
  n <- 100
  test_data <- data.frame(X = rnorm(n), M = rnorm(n), Y = rnorm(n))
  model <- "M ~ X; Y ~ M + X"
  fit <- lavaan::sem(model, data = test_data)

  # Missing treatment
  expect_error(
    extract_mediation(fit, mediator = "M", outcome = "Y"),
    "treatment"
  )

  # Missing mediator
  expect_error(
    extract_mediation(fit, treatment = "X", outcome = "Y"),
    "mediator"
  )
})


test_that("extract_mediation errors on missing paths in lavaan", {
  skip_if_not_installed("lavaan")

  # Create model without proper paths
  set.seed(222)
  n <- 100
  test_data <- data.frame(X = rnorm(n), M = rnorm(n), Y = rnorm(n), Z = rnorm(n))

  # Model where X doesn't predict M
  model <- "M ~ Z; Y ~ M + X"
  fit <- lavaan::sem(model, data = test_data)

  # Should error because a path doesn't exist
  expect_error(
    extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"),
    "a path not found"
  )
})


test_that("extract_mediation warns on missing c' path", {
  skip_if_not_installed("lavaan")

  # Create model with full mediation (no direct effect)
  set.seed(333)
  n <- 200
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.4 * M + rnorm(n)  # No direct X -> Y
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Model without direct effect
  model <- "
    M ~ X
    Y ~ M
  "
  fit <- lavaan::sem(model, data = test_data)

  # Should warn about missing c' path
  expect_warning(
    med_data <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y"),
    "c' path"
  )

  # c' should be set to 0
  expect_equal(med_data@c_prime, 0)
})


test_that("extract_mediation creates valid vcov from lavaan", {
  skip_if_not_installed("lavaan")

  # Create test data
  set.seed(444)
  n <- 200
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  model <- "M ~ X; Y ~ M + X"
  fit <- lavaan::sem(model, data = test_data)

  med_data <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")

  # Check vcov is square
  expect_equal(nrow(med_data@vcov), ncol(med_data@vcov))

  # Check vcov matches estimates length
  expect_equal(nrow(med_data@vcov), length(med_data@estimates))

  # Check vcov is symmetric
  expect_true(isSymmetric(med_data@vcov))
})


test_that("print method works for lavaan-extracted MediationData", {
  skip_if_not_installed("lavaan")

  # Create test data
  set.seed(555)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  model <- "M ~ X; Y ~ M + X"
  fit <- lavaan::sem(model, data = test_data)

  med_data <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")

  # Should print without error
  expect_output(print(med_data), "MediationData object")
  expect_output(print(med_data), "lavaan")
})


test_that("bootstrap works with lavaan-extracted MediationData", {
  skip_if_not_installed("lavaan")
  skip_if_not_installed("MASS")

  # Create test data
  set.seed(666)
  n <- 200
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  model <- "M ~ X; Y ~ M + X"
  fit <- lavaan::sem(model, data = test_data)

  med_data <- extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y")

  # Find parameter names for a and b paths
  param_names <- names(med_data@estimates)
  # lavaan uses different naming, so we use the paths directly
  indirect_fn <- function(theta) {
    med_data@a_path * med_data@b_path
  }

  # This is a simplified version - for real use, you'd use proper parameter indexing
  # For now, just verify the bootstrap infrastructure works with lavaan data
  simple_fn <- function(theta) theta[1] * theta[2]  # Product of first two params

  result <- bootstrap_mediation(
    statistic_fn = simple_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  # Check class
  expect_true(S7::S7_inherits(result, BootstrapResult))
  expect_equal(result@n_boot, 100L)
})
