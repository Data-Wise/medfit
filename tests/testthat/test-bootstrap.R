# Tests for bootstrap_mediation()
#
# Test categories:
# 1. Parametric bootstrap
# 2. Nonparametric bootstrap
# 3. Plugin method
# 4. Input validation / error handling
# 5. Reproducibility with seeds
# 6. Edge cases

# --- Test Data Generator ---

# Generate simple mediation data
generate_mediation_data <- function(n = 200, a = 0.5, b = 0.3, c_prime = 0.2, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y <- b * M + c_prime * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}

# Create a MediationData object for testing
create_test_mediation_data <- function() {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )
}

# Simple statistic function: indirect effect (a * b)
indirect_effect <- function(theta) {
  # theta should have named elements "a" and "b"
  theta["a"] * theta["b"]
}


# ==============================================================================
# Parametric Bootstrap Tests
# ==============================================================================

test_that("parametric bootstrap returns BootstrapResult", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    ci_level = 0.95,
    seed = 123
  )

  expect_s3_class(result, "medfit::BootstrapResult")
  expect_equal(result@method, "parametric")
})

test_that("parametric bootstrap produces valid confidence interval", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 500,
    ci_level = 0.95,
    seed = 123
  )

  # CI should be ordered
  expect_true(result@ci_lower <= result@ci_upper)

  # Estimate should be within CI (generally)
  # Using wider tolerance since bootstrap can be noisy
  expect_true(result@ci_lower <= result@estimate + 0.1)
  expect_true(result@ci_upper >= result@estimate - 0.1)

  # ci_level should be stored
  expect_equal(result@ci_level, 0.95)
})

test_that("parametric bootstrap stores correct n_boot", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 200,
    seed = 123
  )

  expect_equal(result@n_boot, 200L)
  expect_equal(length(result@boot_estimates), 200L)
})

test_that("parametric bootstrap is reproducible with seed", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result1 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 42
  )

  result2 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 42
  )

  expect_equal(result1@estimate, result2@estimate)
  expect_equal(result1@ci_lower, result2@ci_lower)
  expect_equal(result1@ci_upper, result2@ci_upper)
  expect_equal(result1@boot_estimates, result2@boot_estimates)
})

test_that("parametric bootstrap gives different results with different seeds", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result1 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 42
  )

  result2 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 99
  )

  # Results should differ (with very high probability)
  expect_false(all(result1@boot_estimates == result2@boot_estimates))
})


# ==============================================================================
# Nonparametric Bootstrap Tests
# ==============================================================================

test_that("nonparametric bootstrap returns BootstrapResult", {
  data <- generate_mediation_data()

  # Statistic function for nonparametric: fit models and compute indirect
  np_statistic <- function(d) {
    fit_m <- lm(M ~ X, data = d)
    fit_y <- lm(Y ~ X + M, data = d)
    coef(fit_m)["X"] * coef(fit_y)["M"]
  }

  result <- bootstrap_mediation(
    statistic_fn = np_statistic,
    method = "nonparametric",
    data = data,
    n_boot = 50,  # Small for speed
    ci_level = 0.95,
    seed = 123
  )

  expect_s3_class(result, "medfit::BootstrapResult")
  expect_equal(result@method, "nonparametric")
})

test_that("nonparametric bootstrap produces valid confidence interval", {
  data <- generate_mediation_data()

  np_statistic <- function(d) {
    fit_m <- lm(M ~ X, data = d)
    fit_y <- lm(Y ~ X + M, data = d)
    coef(fit_m)["X"] * coef(fit_y)["M"]
  }

  result <- bootstrap_mediation(
    statistic_fn = np_statistic,
    method = "nonparametric",
    data = data,
    n_boot = 100,
    ci_level = 0.95,
    seed = 123
  )

  # CI should be ordered
  expect_true(result@ci_lower <= result@ci_upper)

  # ci_level should be stored
  expect_equal(result@ci_level, 0.95)
})

test_that("nonparametric bootstrap is reproducible with seed", {
  data <- generate_mediation_data()

  np_statistic <- function(d) {
    fit_m <- lm(M ~ X, data = d)
    fit_y <- lm(Y ~ X + M, data = d)
    coef(fit_m)["X"] * coef(fit_y)["M"]
  }

  result1 <- bootstrap_mediation(
    statistic_fn = np_statistic,
    method = "nonparametric",
    data = data,
    n_boot = 50,
    seed = 42
  )

  result2 <- bootstrap_mediation(
    statistic_fn = np_statistic,
    method = "nonparametric",
    data = data,
    n_boot = 50,
    seed = 42
  )

  expect_equal(result1@estimate, result2@estimate)
  expect_equal(result1@boot_estimates, result2@boot_estimates)
})


# ==============================================================================
# Plugin Method Tests
# ==============================================================================

test_that("plugin method returns BootstrapResult", {
  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  expect_s3_class(result, "medfit::BootstrapResult")
  expect_equal(result@method, "plugin")
})

test_that("plugin method has NA confidence intervals", {
  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  expect_true(is.na(result@ci_lower))
  expect_true(is.na(result@ci_upper))
  expect_true(is.na(result@ci_level))
})

test_that("plugin method has n_boot = 0", {
  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  expect_equal(result@n_boot, 0L)
  expect_equal(length(result@boot_estimates), 0L)
})

test_that("plugin method computes correct point estimate", {
  med_data <- create_test_mediation_data()

  # Expected indirect effect
  expected <- med_data@a_path * med_data@b_path

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  # Should match exactly
  expect_equal(unname(result@estimate), expected)
})


# ==============================================================================
# Input Validation Tests
# ==============================================================================

test_that("bootstrap_mediation errors for invalid method", {
  med_data <- create_test_mediation_data()

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "invalid",
      mediation_data = med_data
    ),
    "arg.*should be one of"
  )
})

test_that("bootstrap_mediation errors when statistic_fn is not a function", {
  med_data <- create_test_mediation_data()

  expect_error(
    bootstrap_mediation(
      statistic_fn = "not a function",
      method = "plugin",
      mediation_data = med_data
    ),
    "statistic_fn must be a function"
  )
})

test_that("bootstrap_mediation errors for invalid n_boot", {
  med_data <- create_test_mediation_data()

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      n_boot = -1
    ),
    "n_boot must be a positive"
  )

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      n_boot = 0
    ),
    "n_boot must be a positive"
  )
})

test_that("bootstrap_mediation errors for invalid ci_level", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      n_boot = 10,
      ci_level = 0
    ),
    "ci_level must be.*between 0 and 1"
  )

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      n_boot = 10,
      ci_level = 1
    ),
    "ci_level must be.*between 0 and 1"
  )
})

test_that("parametric bootstrap errors without mediation_data", {
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      n_boot = 10
    ),
    "mediation_data is required"
  )
})

test_that("nonparametric bootstrap errors without data", {
  expect_error(
    bootstrap_mediation(
      statistic_fn = function(d) 1,
      method = "nonparametric",
      n_boot = 10
    ),
    "data is required"
  )
})

test_that("plugin method errors without mediation_data", {
  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "plugin"
    ),
    "mediation_data is required"
  )
})


# ==============================================================================
# Different ci_level Tests
# ==============================================================================

test_that("parametric bootstrap respects different ci_level", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result_90 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 500,
    ci_level = 0.90,
    seed = 123
  )

  result_99 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 500,
    ci_level = 0.99,
    seed = 123
  )

  # 99% CI should be wider than 90% CI
  width_90 <- result_90@ci_upper - result_90@ci_lower
  width_99 <- result_99@ci_upper - result_99@ci_lower

  expect_true(width_99 > width_90)
})


# ==============================================================================
# Print Method Tests
# ==============================================================================

test_that("print method works for parametric BootstrapResult", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  expect_output(print(result), "BootstrapResult")
  expect_output(print(result), "parametric")
  expect_output(print(result), "Confidence Interval")
})

test_that("print method works for plugin BootstrapResult", {
  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  expect_output(print(result), "BootstrapResult")
  expect_output(print(result), "plugin")
  expect_output(print(result), "No confidence interval")
})


# ==============================================================================
# Summary Method Tests
# ==============================================================================

test_that("summary method works for BootstrapResult", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  summ <- summary(result)

  expect_s3_class(summ, "summary.BootstrapResult")
  expect_equal(summ$method, "parametric")
  expect_true("boot_dist" %in% names(summ))
})


# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("bootstrap handles small n_boot", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 10,
    seed = 123
  )

  expect_equal(result@n_boot, 10L)
  expect_s3_class(result, "medfit::BootstrapResult")
})

test_that("default method is parametric", {
  skip_if_not_installed("MASS")

  med_data <- create_test_mediation_data()

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    mediation_data = med_data,
    n_boot = 10,
    seed = 123
  )

  expect_equal(result@method, "parametric")
})
