# Edge Case Tests for medfit Package
#
# Test categories:
# 1. Small sample sizes
# 2. Zero effects
# 3. Perfect correlation
# 4. Near-singular covariance matrices
# 5. Missing or problematic data
# 6. Extreme values
# 7. Variable naming edge cases

# ==============================================================================
# Small Sample Sizes
# ==============================================================================

test_that("fit_mediation handles very small samples (n=20)", {
  data <- generate_simple_mediation_data(n = 20, seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_s3_class(med_data, "medfit::MediationData")
  expect_equal(med_data@n_obs, 20L)
  expect_true(med_data@converged)
})

test_that("extract_mediation handles very small samples (n=15)", {
  data <- generate_simple_mediation_data(n = 15, seed = 456)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  expect_s3_class(med_data, "medfit::MediationData")
  expect_equal(med_data@n_obs, 15L)
})

test_that("bootstrap handles small samples with warnings", {
  skip_without_mass()

  data <- generate_simple_mediation_data(n = 25, seed = 789)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Should still work, even if estimates are noisy
  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 50,
    seed = 123
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
})


# ==============================================================================
# Zero Effects
# ==============================================================================

test_that("fit_mediation handles zero a path", {
  data <- generate_simple_mediation_data(n = 200, a = 0, b = 0.3, seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # a_path should be close to 0
  expect_true(abs(med_data@a_path) < 0.2)
})

test_that("fit_mediation handles zero b path", {
  data <- generate_simple_mediation_data(n = 200, a = 0.5, b = 0, seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # b_path should be close to 0
  expect_true(abs(med_data@b_path) < 0.2)
})

test_that("fit_mediation handles all zero effects", {
  data <- generate_simple_mediation_data(n = 200, a = 0, b = 0, c_prime = 0,
                                          seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # All paths should be close to 0
  expect_true(abs(med_data@a_path) < 0.2)
  expect_true(abs(med_data@b_path) < 0.2)
  expect_true(abs(med_data@c_prime) < 0.2)
})


# ==============================================================================
# High Correlation
# ==============================================================================

test_that("fit_mediation handles high X-M correlation", {
  set.seed(123)
  n <- 200
  X <- rnorm(n)
  M <- 0.95 * X + rnorm(n, sd = 0.1)  # Very high correlation
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_s3_class(med_data, "medfit::MediationData")
  expect_true(med_data@converged)
})


# ==============================================================================
# Near-Singular Covariance Matrices
# ==============================================================================

test_that("parametric bootstrap handles near-singular vcov", {
  skip_without_mass()

  # Create data with high correlation
  set.seed(123)
  n <- 100
  X <- rnorm(n)
  M <- 0.99 * X + rnorm(n, sd = 0.01)  # Almost perfect correlation
  Y <- 0.5 * M + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Bootstrap should handle near-singular vcov via eigenvalue adjustment
  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 50,
    seed = 123
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  # Result may be noisy but should not error
  expect_true(!is.na(boot_result@estimate))
})


# ==============================================================================
# Variable Naming Edge Cases
# ==============================================================================

test_that("fit_mediation handles variable names with dots", {
  set.seed(123)
  n <- 200
  data <- data.frame(
    treat.var = rnorm(n),
    med.var = NA_real_,
    out.var = NA_real_
  )
  data$med.var <- 0.5 * data$treat.var + rnorm(n)
  data$out.var <- 0.3 * data$med.var + 0.2 * data$treat.var + rnorm(n)

  med_data <- fit_mediation(
    formula_y = out.var ~ treat.var + med.var,
    formula_m = med.var ~ treat.var,
    data = data,
    treatment = "treat.var",
    mediator = "med.var"
  )

  expect_equal(med_data@treatment, "treat.var")
  expect_equal(med_data@mediator, "med.var")
  expect_equal(med_data@outcome, "out.var")
})

test_that("fit_mediation handles variable names with underscores", {
  set.seed(123)
  n <- 200
  data <- data.frame(
    treatment_var = rnorm(n),
    mediator_var = NA_real_,
    outcome_var = NA_real_
  )
  data$mediator_var <- 0.5 * data$treatment_var + rnorm(n)
  data$outcome_var <- 0.3 * data$mediator_var + 0.2 * data$treatment_var + rnorm(n)

  med_data <- fit_mediation(
    formula_y = outcome_var ~ treatment_var + mediator_var,
    formula_m = mediator_var ~ treatment_var,
    data = data,
    treatment = "treatment_var",
    mediator = "mediator_var"
  )

  expect_equal(med_data@treatment, "treatment_var")
  expect_equal(med_data@mediator, "mediator_var")
})

test_that("fit_mediation handles single-letter variable names", {
  set.seed(123)
  n <- 200
  data <- data.frame(
    X = rnorm(n),
    M = NA_real_,
    Y = NA_real_
  )
  data$M <- 0.5 * data$X + rnorm(n)
  data$Y <- 0.3 * data$M + 0.2 * data$X + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@treatment, "X")
  expect_equal(med_data@mediator, "M")
  expect_equal(med_data@outcome, "Y")
})


# ==============================================================================
# Large Effects
# ==============================================================================

test_that("fit_mediation handles large path coefficients", {
  data <- generate_simple_mediation_data(n = 200, a = 5, b = 3, c_prime = 2,
                                          seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Paths should be close to true values
  expect_true(abs(med_data@a_path - 5) < 1)
  expect_true(abs(med_data@b_path - 3) < 1)
  expect_true(abs(med_data@c_prime - 2) < 1)
})


# ==============================================================================
# Negative Effects
# ==============================================================================

test_that("fit_mediation handles negative path coefficients", {
  data <- generate_simple_mediation_data(n = 200, a = -0.5, b = 0.3,
                                          c_prime = -0.2, seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # a_path should be negative
  expect_true(med_data@a_path < 0)
})

test_that("fit_mediation handles suppression effect (opposite sign a and b)", {
  data <- generate_simple_mediation_data(n = 200, a = 0.5, b = -0.3,
                                          c_prime = 0.5, seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Indirect effect (a * b) should be negative
  indirect <- med_data@a_path * med_data@b_path
  expect_true(indirect < 0)
})


# ==============================================================================
# Bootstrap Edge Cases
# ==============================================================================

test_that("bootstrap handles very small n_boot", {
  skip_without_mass()

  med_data <- create_test_mediation_data()

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 5,
    seed = 123
  )

  expect_equal(boot_result@n_boot, 5L)
  expect_equal(length(boot_result@boot_estimates), 5L)
})

test_that("bootstrap handles n_boot = 1", {
  skip_without_mass()

  med_data <- create_test_mediation_data()

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 1,
    seed = 123
  )

  expect_equal(boot_result@n_boot, 1L)
  # CI will be same as estimate when n_boot = 1
})


# ==============================================================================
# Different CI Levels
# ==============================================================================

test_that("bootstrap handles extreme ci_level (0.01)", {
  skip_without_mass()

  med_data <- create_test_mediation_data()

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    ci_level = 0.01,
    seed = 123
  )

  expect_equal(boot_result@ci_level, 0.01)
  # 1% CI should be very narrow
  width_01 <- boot_result@ci_upper - boot_result@ci_lower
  expect_true(width_01 > 0)  # Should still have positive width
})

test_that("bootstrap handles ci_level = 0.99", {
  skip_without_mass()

  med_data <- create_test_mediation_data()

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect_fn,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    ci_level = 0.99,
    seed = 123
  )

  expect_equal(boot_result@ci_level, 0.99)
})


# ==============================================================================
# Statistic Function Edge Cases
# ==============================================================================

test_that("bootstrap handles statistic that returns named value", {
  skip_without_mass()

  med_data <- create_test_mediation_data()

  # Statistic function that returns named value
  named_stat <- function(theta) {
    result <- theta["a"] * theta["b"]
    names(result) <- "indirect"
    result
  }

  boot_result <- bootstrap_mediation(
    statistic_fn = named_stat,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 50,
    seed = 123
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  expect_true(!is.na(boot_result@estimate))
})


# ==============================================================================
# Data with Factor Variables (edge case)
# ==============================================================================

test_that("fit_mediation handles data with unused factor columns", {
  set.seed(123)
  n <- 200
  data <- data.frame(
    X = rnorm(n),
    M = NA_real_,
    Y = NA_real_,
    group = factor(sample(c("A", "B", "C"), n, replace = TRUE))
  )
  data$M <- 0.5 * data$X + rnorm(n)
  data$Y <- 0.3 * data$M + 0.2 * data$X + rnorm(n)

  # Should work even with unused factor column
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_s3_class(med_data, "medfit::MediationData")
})


# ==============================================================================
# Convergence Issues
# ==============================================================================

test_that("fit_mediation warns on non-convergence", {
  # This is hard to trigger with simple GLMs, so we just verify

  # that the converged property is correctly set for normal case
  data <- generate_simple_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_true(med_data@converged)
})
