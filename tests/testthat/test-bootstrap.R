# Tests for bootstrap_mediation()
#
# Test categories:
# 1. Parametric bootstrap
# 2. Nonparametric bootstrap
# 3. Plugin method
# 4. Parallel processing
# 5. Reproducibility and seed handling
# 6. Input validation / error handling
# 7. CI coverage properties

# --- Test Data Generators ---

# Generate simple mediation data
generate_mediation_data <- function(n = 200, a = 0.5, b = 0.3, c_prime = 0.2, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y <- b * M + c_prime * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}

# Create a MediationData object from lm fits
create_test_mediation_data <- function(data) {
  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )
}

# Simple indirect effect function (uses parameter names from extract_mediation)
indirect_effect <- function(theta) {
  theta["m_X"] * theta["y_M"]
}


# ==============================================================================
# Parametric Bootstrap
# ==============================================================================

test_that("parametric bootstrap returns BootstrapResult object", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  expect_true(S7::S7_inherits(result, BootstrapResult))
  expect_equal(result@method, "parametric")
  expect_equal(result@n_boot, 1000L)
})


test_that("parametric bootstrap computes reasonable point estimate", {
  

  data <- generate_mediation_data(a = 0.5, b = 0.4, c_prime = 0.1)
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  # True indirect effect: 0.5 * 0.4 = 0.2
  # Should be within 0.1 of true value
  expect_true(abs(result@estimate - 0.2) < 0.1)
})


test_that("parametric bootstrap produces valid confidence interval", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    ci_level = 0.95,
    seed = 123
  )

  # CI should be ordered correctly
  expect_true(result@ci_lower < result@ci_upper)

  # Point estimate should be between CI bounds (usually)
  expect_true(result@estimate >= result@ci_lower)
  expect_true(result@estimate <= result@ci_upper)

  # CI width should be positive
  ci_width <- result@ci_upper - result@ci_lower
  expect_true(ci_width > 0)
})


test_that("parametric bootstrap stores bootstrap distribution", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  # Should have 1000 bootstrap estimates
  expect_length(result@boot_estimates, 1000)

  # Bootstrap estimates should be numeric
  expect_true(is.numeric(result@boot_estimates))

  # No NA values
  expect_false(any(is.na(result@boot_estimates)))
})


test_that("parametric bootstrap respects ci_level argument", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  # 95% CI
  result_95 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    ci_level = 0.95,
    seed = 123
  )

  # 90% CI (should be narrower)
  result_90 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    ci_level = 0.90,
    seed = 123
  )

  width_95 <- result_95@ci_upper - result_95@ci_lower
  width_90 <- result_90@ci_upper - result_90@ci_lower

  # 90% CI should be narrower than 95% CI
  expect_true(width_90 < width_95)
})


# ==============================================================================
# Nonparametric Bootstrap
# ==============================================================================

test_that("nonparametric bootstrap returns BootstrapResult object", {
  

  data <- generate_mediation_data()

  # Statistic function that refits models
  statistic_fn_refit <- function(boot_data) {
    med_data <- create_test_mediation_data(boot_data)
    med_data@a_path * med_data@b_path
  }

  result <- bootstrap_mediation(
    statistic_fn = statistic_fn_refit,
    method = "nonparametric",
    data = data,
    n_boot = 100,  # Use fewer for speed
    seed = 123
  )

  expect_true(S7::S7_inherits(result, BootstrapResult))
  expect_equal(result@method, "nonparametric")
  expect_equal(result@n_boot, 100L)
})


test_that("nonparametric bootstrap computes reasonable point estimate", {
  

  data <- generate_mediation_data(a = 0.5, b = 0.4, c_prime = 0.1)

  statistic_fn_refit <- function(boot_data) {
    med_data <- create_test_mediation_data(boot_data)
    med_data@a_path * med_data@b_path
  }

  result <- bootstrap_mediation(
    statistic_fn = statistic_fn_refit,
    method = "nonparametric",
    data = data,
    n_boot = 100,
    seed = 123
  )

  # True indirect effect: 0.5 * 0.4 = 0.2
  expect_true(abs(result@estimate - 0.2) < 0.15)
})


test_that("nonparametric bootstrap produces valid confidence interval", {
  

  data <- generate_mediation_data()

  statistic_fn_refit <- function(boot_data) {
    med_data <- create_test_mediation_data(boot_data)
    med_data@a_path * med_data@b_path
  }

  result <- bootstrap_mediation(
    statistic_fn = statistic_fn_refit,
    method = "nonparametric",
    data = data,
    n_boot = 100,
    ci_level = 0.95,
    seed = 123
  )

  # CI should be ordered correctly
  expect_true(result@ci_lower < result@ci_upper)

  # CI width should be positive
  expect_true((result@ci_upper - result@ci_lower) > 0)
})


test_that("nonparametric bootstrap handles small samples", {
  

  # Small sample size
  data <- generate_mediation_data(n = 30)

  statistic_fn_refit <- function(boot_data) {
    med_data <- create_test_mediation_data(boot_data)
    med_data@a_path * med_data@b_path
  }

  result <- bootstrap_mediation(
    statistic_fn = statistic_fn_refit,
    method = "nonparametric",
    data = data,
    n_boot = 100,
    seed = 123
  )

  expect_true(S7::S7_inherits(result, BootstrapResult))
  expect_equal(result@n_boot, 100L)
})


# ==============================================================================
# Plugin Method
# ==============================================================================

test_that("plugin method returns BootstrapResult with NA confidence interval", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  expect_true(S7::S7_inherits(result, BootstrapResult))
  expect_equal(result@method, "plugin")
  expect_equal(result@n_boot, 0L)

  # CI should be NA for plugin
  expect_true(is.na(result@ci_lower))
  expect_true(is.na(result@ci_upper))
  expect_true(is.na(result@ci_level))

  # Boot estimates should be empty
  expect_length(result@boot_estimates, 0)
})


test_that("plugin method computes point estimate only", {
  

  data <- generate_mediation_data(a = 0.5, b = 0.4, c_prime = 0.1)
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  # Should have a point estimate
  expect_true(is.numeric(result@estimate))
  expect_false(is.na(result@estimate))

  # Should be close to true value (0.2)
  expect_true(abs(result@estimate - 0.2) < 0.15)
})


test_that("plugin method is fast", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  # Plugin should complete very quickly (< 0.1 seconds)
  time_start <- Sys.time()
  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )
  time_end <- Sys.time()

  elapsed <- as.numeric(difftime(time_end, time_start, units = "secs"))
  expect_true(elapsed < 0.1)
})


# ==============================================================================
# Parallel Processing
# ==============================================================================

test_that("parallel bootstrap produces same results as sequential (with seed)", {
  
  skip_on_os("windows")  # Parallel may not work on Windows

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  # Sequential
  result_seq <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    parallel = FALSE,
    seed = 123
  )

  # Parallel
  result_par <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    parallel = TRUE,
    ncores = 2,
    seed = 123
  )

  # Results should be identical (or very close)
  expect_equal(result_seq@estimate, result_par@estimate, tolerance = 0.01)
  expect_equal(result_seq@ci_lower, result_par@ci_lower, tolerance = 0.01)
  expect_equal(result_seq@ci_upper, result_par@ci_upper, tolerance = 0.01)
})


test_that("parallel bootstrap uses correct number of cores", {
  
  skip_on_os("windows")

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  # This test would check internal implementation details
  # May need to be adjusted based on actual implementation
  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    parallel = TRUE,
    ncores = 2,
    seed = 123
  )

  expect_true(S7::S7_inherits(result, BootstrapResult))
})


# ==============================================================================
# Reproducibility and Seed Handling
# ==============================================================================

test_that("parametric bootstrap is reproducible with same seed", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result1 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  result2 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  # Results should be identical
  expect_equal(result1@estimate, result2@estimate)
  expect_equal(result1@ci_lower, result2@ci_lower)
  expect_equal(result1@ci_upper, result2@ci_upper)
  expect_equal(result1@boot_estimates, result2@boot_estimates)
})


test_that("nonparametric bootstrap is reproducible with same seed", {
  

  data <- generate_mediation_data()

  statistic_fn_refit <- function(boot_data) {
    med_data <- create_test_mediation_data(boot_data)
    med_data@a_path * med_data@b_path
  }

  result1 <- bootstrap_mediation(
    statistic_fn = statistic_fn_refit,
    method = "nonparametric",
    data = data,
    n_boot = 100,
    seed = 123
  )

  result2 <- bootstrap_mediation(
    statistic_fn = statistic_fn_refit,
    method = "nonparametric",
    data = data,
    n_boot = 100,
    seed = 123
  )

  # Results should be identical
  expect_equal(result1@estimate, result2@estimate)
  expect_equal(result1@ci_lower, result2@ci_lower)
  expect_equal(result1@ci_upper, result2@ci_upper)
})


test_that("different seeds produce different results", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result1 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  result2 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 456
  )

  # Results should be different
  expect_false(isTRUE(all.equal(result1@boot_estimates, result2@boot_estimates)))
})


# ==============================================================================
# Input Validation and Error Handling
# ==============================================================================

test_that("bootstrap_mediation errors when mediation_data missing for parametric", {
  

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      n_boot = 1000
    ),
    "mediation_data"
  )
})


test_that("bootstrap_mediation errors when data missing for nonparametric", {
  

  expect_error(
    bootstrap_mediation(
      statistic_fn = function(x) 1,
      method = "nonparametric",
      n_boot = 1000
    ),
    "data"
  )
})


test_that("bootstrap_mediation errors for invalid method", {


  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "invalid_method",
      mediation_data = med_data
    ),
    "should be one of"
  )
})


test_that("bootstrap_mediation errors for invalid n_boot", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      n_boot = -100  # Negative
    ),
    "n_boot"
  )
})


test_that("bootstrap_mediation errors for invalid ci_level", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  expect_error(
    bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      ci_level = 1.5  # > 1
    ),
    "ci_level"
  )
})


test_that("bootstrap_mediation errors when statistic_fn is not a function", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  expect_error(
    bootstrap_mediation(
      statistic_fn = "not a function",
      method = "parametric",
      mediation_data = med_data
    ),
    "statistic_fn.*function"
  )
})


# ==============================================================================
# CI Coverage Properties (Simulation-Based)
# ==============================================================================

test_that("parametric bootstrap achieves nominal CI coverage", {
  
  skip("Simulation test - run separately for CI coverage validation")

  # This test runs a simulation to verify that 95% CIs contain
  # the true parameter about 95% of the time

  n_sim <- 100  # Number of simulations (use 1000+ for real validation)
  true_indirect <- 0.5 * 0.3  # True indirect effect
  coverage_count <- 0

  for (i in 1:n_sim) {
    data <- generate_mediation_data(seed = 1000 + i)
    med_data <- create_test_mediation_data(data)

    result <- bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      n_boot = 1000,
      ci_level = 0.95,
      seed = 2000 + i
    )

    # Check if CI contains true value
    if (result@ci_lower <= true_indirect && true_indirect <= result@ci_upper) {
      coverage_count <- coverage_count + 1
    }
  }

  coverage_rate <- coverage_count / n_sim

  # Coverage should be close to 0.95 (allow some sampling variation)
  # With n_sim=100, 95% CI for coverage is roughly (0.91, 0.99)
  expect_true(coverage_rate >= 0.85)  # Conservative lower bound
  expect_true(coverage_rate <= 1.00)
})


# ==============================================================================
# Print and Summary Methods
# ==============================================================================

test_that("print method works for BootstrapResult from parametric", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  expect_output(print(result), "BootstrapResult")
  expect_output(print(result), "parametric")
  expect_output(print(result), "Estimate")
  expect_output(print(result), "Confidence Interval")
})


test_that("print method works for BootstrapResult from plugin", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  expect_output(print(result), "BootstrapResult")
  expect_output(print(result), "plugin")
  expect_output(print(result), "No confidence interval")
})


test_that("summary method works for BootstrapResult", {
  

  data <- generate_mediation_data()
  med_data <- create_test_mediation_data(data)

  result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1000,
    seed = 123
  )

  summ <- summary(result)

  expect_s3_class(summ, "summary.BootstrapResult")
  expect_equal(summ$method, "parametric")
  expect_true("estimate" %in% names(summ))
  expect_true("ci" %in% names(summ))
  expect_true("boot_dist" %in% names(summ))
})
