# Tests for bootstrap_mediation()

test_that("parametric bootstrap works with MediationData", {
  # Create test data and fit model
  set.seed(123)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  # Define indirect effect function
  indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

  # Run parametric bootstrap
  result <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 500,
    ci_level = 0.95,
    seed = 12345
  )

  # Check class
  expect_true(S7::S7_inherits(result, BootstrapResult))

  # Check properties
  expect_equal(result@method, "parametric")
  expect_equal(result@n_boot, 500L)
  expect_equal(result@ci_level, 0.95)

  # Check that we have bootstrap estimates
  expect_equal(length(result@boot_estimates), 500)

  # Check CI is reasonable
  expect_true(result@ci_lower < result@estimate)
  expect_true(result@ci_upper > result@estimate)

  # Check estimate is close to a * b
  expected_indirect <- med_data@a_path * med_data@b_path
  expect_equal(result@estimate, expected_indirect, tolerance = 0.001)
})


test_that("parametric bootstrap is reproducible with seed", {
  # Create test data
  set.seed(456)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

  # Run twice with same seed
  result1 <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 99999
  )

  result2 <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 99999
  )

  # Results should be identical
  expect_equal(result1@boot_estimates, result2@boot_estimates)
  expect_equal(result1@ci_lower, result2@ci_lower)
  expect_equal(result1@ci_upper, result2@ci_upper)
})


test_that("nonparametric bootstrap works", {
  # Create test data
  set.seed(789)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Define refit function for nonparametric bootstrap
  refit_fn <- function(boot_data) {
    fit_m <- lm(M ~ X, data = boot_data)
    fit_y <- lm(Y ~ X + M, data = boot_data)
    unname(coef(fit_m)["X"] * coef(fit_y)["M"])
  }

  # Run nonparametric bootstrap
  result <- bootstrap_mediation(
    statistic_fn = refit_fn,
    method = "nonparametric",
    data = test_data,
    n_boot = 100,
    ci_level = 0.95,
    seed = 12345
  )

  # Check class
  expect_true(S7::S7_inherits(result, BootstrapResult))

  # Check properties
  expect_equal(result@method, "nonparametric")
  expect_equal(result@ci_level, 0.95)

  # Check that we have bootstrap estimates
  expect_true(length(result@boot_estimates) > 0)

  # Check CI is reasonable
  expect_true(result@ci_lower < result@ci_upper)
})


test_that("nonparametric bootstrap is reproducible with seed", {
  # Create test data
  set.seed(101)
  n <- 50
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  refit_fn <- function(boot_data) {
    fit_m <- lm(M ~ X, data = boot_data)
    fit_y <- lm(Y ~ X + M, data = boot_data)
    unname(coef(fit_m)["X"] * coef(fit_y)["M"])
  }

  # Run twice with same seed
  result1 <- bootstrap_mediation(
    statistic_fn = refit_fn,
    method = "nonparametric",
    data = test_data,
    n_boot = 50,
    seed = 88888
  )

  result2 <- bootstrap_mediation(
    statistic_fn = refit_fn,
    method = "nonparametric",
    data = test_data,
    n_boot = 50,
    seed = 88888
  )

  # Results should be identical
  expect_equal(result1@boot_estimates, result2@boot_estimates)
  expect_equal(result1@ci_lower, result2@ci_lower)
  expect_equal(result1@ci_upper, result2@ci_upper)
})


test_that("plugin method works", {
  # Create test data
  set.seed(111)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

  # Run plugin method
  result <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "plugin",
    mediation_data = med_data
  )

  # Check class
  expect_true(S7::S7_inherits(result, BootstrapResult))

  # Check properties
  expect_equal(result@method, "plugin")
  expect_equal(result@n_boot, 0L)

  # CI values should be NA
  expect_true(is.na(result@ci_lower))
  expect_true(is.na(result@ci_upper))
  expect_true(is.na(result@ci_level))

  # Boot estimates should be empty
  expect_equal(length(result@boot_estimates), 0)

  # Point estimate should match
  expected <- med_data@a_path * med_data@b_path
  expect_equal(result@estimate, expected, tolerance = 0.001)
})


test_that("bootstrap_mediation validates statistic_fn", {
  # Create test data
  set.seed(222)
  n <- 50
  test_data <- data.frame(X = rnorm(n), M = rnorm(n), Y = rnorm(n))

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  # Missing statistic_fn
  expect_error(
    bootstrap_mediation(method = "parametric", mediation_data = med_data),
    "statistic_fn must be a function"
  )

  # Non-function statistic_fn
  expect_error(
    bootstrap_mediation(
      statistic_fn = "not a function",
      method = "parametric",
      mediation_data = med_data
    ),
    "statistic_fn must be a function"
  )
})


test_that("bootstrap_mediation validates ci_level", {
  # Create test data
  set.seed(333)
  n <- 50
  test_data <- data.frame(X = rnorm(n), M = rnorm(n), Y = rnorm(n))

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

  # ci_level = 0
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_fn,
      method = "parametric",
      mediation_data = med_data,
      ci_level = 0
    ),
    "ci_level must be between 0 and 1"
  )

  # ci_level = 1
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_fn,
      method = "parametric",
      mediation_data = med_data,
      ci_level = 1
    ),
    "ci_level must be between 0 and 1"
  )

  # ci_level > 1
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_fn,
      method = "parametric",
      mediation_data = med_data,
      ci_level = 1.5
    ),
    "ci_level must be between 0 and 1"
  )
})


test_that("parametric bootstrap validates mediation_data", {
  indirect_fn <- function(theta) theta["a"] * theta["b"]

  # Missing mediation_data
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_fn,
      method = "parametric",
      n_boot = 100
    ),
    "mediation_data is required"
  )

  # Wrong type
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_fn,
      method = "parametric",
      mediation_data = data.frame(a = 1, b = 2),
      n_boot = 100
    ),
    "mediation_data must be a MediationData object"
  )
})


test_that("nonparametric bootstrap validates data", {
  refit_fn <- function(boot_data) 0.5

  # Missing data
  expect_error(
    bootstrap_mediation(
      statistic_fn = refit_fn,
      method = "nonparametric",
      n_boot = 100
    ),
    "data is required"
  )

  # Wrong type
  expect_error(
    bootstrap_mediation(
      statistic_fn = refit_fn,
      method = "nonparametric",
      data = matrix(1:4, 2, 2),
      n_boot = 100
    ),
    "data must be a data frame"
  )
})


test_that("plugin method validates mediation_data", {
  indirect_fn <- function(theta) theta["a"] * theta["b"]

  # Missing mediation_data
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_fn,
      method = "plugin"
    ),
    "mediation_data is required"
  )
})


test_that("print method works for BootstrapResult", {
  # Create test data
  set.seed(444)
  n <- 50
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

  result <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  # Should print without error
  expect_output(print(result), "BootstrapResult object")
  expect_output(print(result), "Method:")
  expect_output(print(result), "Confidence Interval")
})


test_that("summary method works for BootstrapResult", {
  # Create test data
  set.seed(555)
  n <- 50
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

  result <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  # Summary should work
  summ <- summary(result)
  expect_s3_class(summ, "summary.BootstrapResult")
  expect_true("ci" %in% names(summ))
  expect_true("boot_dist" %in% names(summ))
})


test_that("different ci_levels produce different CIs", {
  # Create test data
  set.seed(666)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  indirect_fn <- function(theta) theta["m_X"] * theta["y_M"]

  # 90% CI
  result_90 <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    ci_level = 0.90,
    seed = 777
  )

  # 99% CI
  result_99 <- bootstrap_mediation(
    statistic_fn = indirect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    ci_level = 0.99,
    seed = 777
  )

  # 99% CI should be wider than 90% CI
  width_90 <- result_90@ci_upper - result_90@ci_lower
  width_99 <- result_99@ci_upper - result_99@ci_lower
  expect_true(width_99 > width_90)
})


test_that("nonparametric bootstrap handles failed samples gracefully", {
  # Create test data
  set.seed(888)
  n <- 30
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )

  # Function that occasionally fails
  flaky_fn <- function(boot_data) {
    if (runif(1) < 0.1) stop("Random failure")
    fit_m <- lm(M ~ X, data = boot_data)
    fit_y <- lm(Y ~ X + M, data = boot_data)
    unname(coef(fit_m)["X"] * coef(fit_y)["M"])
  }

  # Should warn about failed samples but still work
  expect_warning(
    result <- bootstrap_mediation(
      statistic_fn = flaky_fn,
      method = "nonparametric",
      data = test_data,
      n_boot = 100,
      seed = 999
    ),
    "bootstrap samples failed"
  )

  # Result should still be valid
  expect_true(S7::S7_inherits(result, BootstrapResult))
  expect_true(length(result@boot_estimates) > 0)
})
