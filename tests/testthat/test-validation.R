# Validation Tests: Comparing medfit to Other Packages
#
# These tests validate that medfit produces correct results by comparing to:
# 1. Manual calculations (ground truth)
# 2. lavaan SEM package
# 3. Published formulas (Baron & Kenny, Sobel)
#
# References:
# - Baron RM, Kenny DA (1986). The moderator-mediator variable distinction.
#   Journal of Personality and Social Psychology, 51(6), 1173-1182.
# - Sobel ME (1982). Asymptotic confidence intervals for indirect effects.
#   Sociological Methodology, 13, 290-312.
# - MacKinnon DP, Lockwood CM, Hoffman JM, West SG, Sheets V (2002).
#   A comparison of methods to test mediation. Psychological Methods, 7(1), 83-104.
# - Preacher KJ, Hayes AF (2008). Asymptotic and resampling strategies for
#   assessing and comparing indirect effects. Behavior Research Methods, 40(3), 879-891.

# ==============================================================================
# Manual Calculations Validation
# ==============================================================================

test_that("path coefficients match manual OLS calculations", {
  # Generate data with known structure
  set.seed(42)
  n <- 500
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  # Manual OLS calculations
  # M = beta0_m + a*X + e_m
  # Y = beta0_y + c'*X + b*M + e_y
  fit_m_manual <- lm(M ~ X, data = data)
  fit_y_manual <- lm(Y ~ X + M, data = data)

  a_manual <- coef(fit_m_manual)["X"]
  b_manual <- coef(fit_y_manual)["M"]
  c_prime_manual <- coef(fit_y_manual)["X"]

  # medfit extraction
  med_data <- extract_mediation(
    fit_m_manual,
    model_y = fit_y_manual,
    treatment = "X",
    mediator = "M"
  )

  # Paths should match exactly

  expect_equal(med_data@a_path, unname(a_manual))
  expect_equal(med_data@b_path, unname(b_manual))
  expect_equal(med_data@c_prime, unname(c_prime_manual))
})

test_that("fit_mediation matches manual glm fitting", {
  set.seed(42)
  n <- 500
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  # Manual GLM
  fit_m_glm <- glm(M ~ X, data = data, family = gaussian())
  fit_y_glm <- glm(Y ~ X + M, data = data, family = gaussian())

  # medfit fit_mediation
  med_fit <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Should match
  expect_equal(med_fit@a_path, unname(coef(fit_m_glm)["X"]))
  expect_equal(med_fit@b_path, unname(coef(fit_y_glm)["M"]))
  expect_equal(med_fit@c_prime, unname(coef(fit_y_glm)["X"]))
})

test_that("indirect effect formula is correct (a * b)", {
  # Per Baron & Kenny (1986) and Sobel (1982):
  # Indirect effect = a * b
  # where a = effect of X on M, b = effect of M on Y|X

  set.seed(123)
  n <- 1000
  X <- rnorm(n)
  M <- 0.4 * X + rnorm(n)  # a = 0.4
  Y <- 0.5 * M + 0.1 * X + rnorm(n)  # b = 0.5, c' = 0.1
  data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Indirect effect = a * b
  indirect <- med_data@a_path * med_data@b_path

  # True indirect = 0.4 * 0.5 = 0.2
  expect_true(abs(indirect - 0.2) < 0.05)  # Within 0.05 of true value

  # Total effect = c' + a*b (Baron & Kenny decomposition)
  total_effect_decomp <- med_data@c_prime + indirect

  # Compare to total effect from simple regression Y ~ X
  fit_total <- lm(Y ~ X, data = data)
  total_from_regression <- coef(fit_total)["X"]

  # Should match (within sampling error)
  expect_true(abs(total_effect_decomp - total_from_regression) < 0.05)
})

test_that("total effect decomposition holds: c = c' + ab", {
  # Baron & Kenny (1986): Total effect = Direct + Indirect
  # c (from Y ~ X) = c' (from Y ~ X + M) + a*b

  set.seed(999)
  n <- 2000  # Large sample for precise estimates
  X <- rnorm(n)
  M <- 0.6 * X + rnorm(n)
  Y <- 0.4 * M + 0.3 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  # Total effect (simple regression)
  c_total <- coef(lm(Y ~ X, data = data))["X"]

  # Mediation decomposition
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  c_prime_plus_ab <- med_data@c_prime + med_data@a_path * med_data@b_path

  # Should be approximately equal
  expect_equal(unname(c_total), c_prime_plus_ab, tolerance = 0.01)
})


# ==============================================================================
# Sobel Standard Error Validation
# ==============================================================================

test_that("Sobel SE formula is correctly computed from vcov", {
  # Sobel (1982) SE formula:
  # SE(ab) = sqrt(b^2 * Var(a) + a^2 * Var(b))
  # This assumes Cov(a,b) = 0 (different models)

  set.seed(42)
  n <- 500
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Extract values for Sobel formula
  a <- med_data@a_path
  b <- med_data@b_path
  var_a <- vcov(fit_m)["X", "X"]
  var_b <- vcov(fit_y)["M", "M"]

  # Sobel SE (first-order approximation)
  se_sobel <- sqrt(b^2 * var_a + a^2 * var_b)

  # The vcov matrix should enable this calculation
  # medfit stores aliases "a" and "b" in the vcov
  expect_true("a" %in% names(med_data@estimates))
  expect_true("b" %in% names(med_data@estimates))

  # Variance of "a" in combined vcov should match original
  expect_equal(med_data@vcov["a", "a"], var_a)
  expect_equal(med_data@vcov["b", "b"], var_b)

  # Sobel SE should be positive
  expect_true(se_sobel > 0)
})


# ==============================================================================
# lavaan Comparison
# ==============================================================================

test_that("medfit extraction matches lavaan parameter estimates", {
  skip_if_not_installed("lavaan")

  set.seed(42)
  n <- 500
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  # Fit in lavaan
  model <- "
    M ~ a * X
    Y ~ b * M + cp * X
    indirect := a * b
  "
  fit_lavaan <- lavaan::sem(model, data = data)

  # Get lavaan estimates
  lavaan_params <- lavaan::parameterEstimates(fit_lavaan)
  a_lavaan <- lavaan_params[lavaan_params$label == "a", "est"]
  b_lavaan <- lavaan_params[lavaan_params$label == "b", "est"]
  cp_lavaan <- lavaan_params[lavaan_params$label == "cp", "est"]

  # Fit with medfit
  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)
  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Should match (within numerical tolerance)
  expect_equal(med_data@a_path, a_lavaan, tolerance = 1e-6)
  expect_equal(med_data@b_path, b_lavaan, tolerance = 1e-6)
  expect_equal(med_data@c_prime, cp_lavaan, tolerance = 1e-6)
})

test_that("medfit indirect effect matches lavaan defined parameter", {
  skip_if_not_installed("lavaan")

  set.seed(42)
  n <- 500
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  # lavaan with indirect effect
  model <- "
    M ~ a * X
    Y ~ b * M + cp * X
    indirect := a * b
  "
  fit_lavaan <- lavaan::sem(model, data = data)

  lavaan_params <- lavaan::parameterEstimates(fit_lavaan)
  indirect_lavaan <- lavaan_params[lavaan_params$label == "indirect", "est"]

  # medfit calculation
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )
  indirect_medfit <- med_data@a_path * med_data@b_path

  # Should match
  expect_equal(indirect_medfit, indirect_lavaan, tolerance = 1e-6)
})

test_that("extract_mediation from lavaan object matches direct lavaan extraction", {
  skip_if_not_installed("lavaan")

  set.seed(42)
  n <- 500
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  model <- "
    M ~ a * X
    Y ~ b * M + cp * X
  "
  fit_lavaan <- lavaan::sem(model, data = data)

  # Extract using medfit method for lavaan
  med_lavaan <- extract_mediation(
    fit_lavaan,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  # Direct lavaan extraction
  lavaan_coef <- lavaan::coef(fit_lavaan)

  expect_equal(med_lavaan@a_path, unname(lavaan_coef["a"]), tolerance = 1e-6)
  expect_equal(med_lavaan@b_path, unname(lavaan_coef["b"]), tolerance = 1e-6)
  expect_equal(med_lavaan@c_prime, unname(lavaan_coef["cp"]), tolerance = 1e-6)
})


# ==============================================================================
# Bootstrap Validation
# ==============================================================================

test_that("bootstrap CI covers true indirect effect at nominal rate", {
  skip_if_not_installed("MASS")
  skip_on_cran()  # Time-intensive test

  # Simulation study: check if 95% CI covers true value ~95% of the time
  # True values: a = 0.5, b = 0.4, indirect = 0.2

  n_sims <- 50  # Number of simulation replications
  n_obs <- 200
  n_boot <- 500
  true_a <- 0.5
  true_b <- 0.4
  true_indirect <- true_a * true_b  # = 0.2

  coverage <- logical(n_sims)

  for (i in seq_len(n_sims)) {
    # Generate data
    set.seed(i * 1000)
    X <- rnorm(n_obs)
    M <- true_a * X + rnorm(n_obs)
    Y <- true_b * M + 0.1 * X + rnorm(n_obs)
    data <- data.frame(X = X, M = M, Y = Y)

    # Fit
    med_data <- fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M"
    )

    # Bootstrap
    boot_result <- bootstrap_mediation(
      statistic_fn = function(theta) theta["a"] * theta["b"],
      method = "parametric",
      mediation_data = med_data,
      n_boot = n_boot,
      ci_level = 0.95,
      seed = i
    )

    # Check coverage
    coverage[i] <- boot_result@ci_lower <= true_indirect &&
                   boot_result@ci_upper >= true_indirect
  }

  # Coverage should be approximately 95% (allow 80-100% given small n_sims)
  coverage_rate <- mean(coverage)
  expect_true(coverage_rate >= 0.75)  # At least 75% coverage
  expect_true(coverage_rate <= 1.0)

  # Report actual coverage
  message("Bootstrap coverage rate: ", round(coverage_rate * 100, 1), "%")
})

test_that("parametric and nonparametric bootstrap give similar results", {
  skip_if_not_installed("MASS")

  set.seed(42)
  n <- 300
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Parametric bootstrap
  boot_param <- bootstrap_mediation(
    statistic_fn = function(theta) theta["a"] * theta["b"],
    method = "parametric",
    mediation_data = med_data,
    n_boot = 500,
    seed = 123
  )

  # Nonparametric bootstrap
  np_statistic <- function(d) {
    fit_m <- lm(M ~ X, data = d)
    fit_y <- lm(Y ~ X + M, data = d)
    coef(fit_m)["X"] * coef(fit_y)["M"]
  }

  boot_nonparam <- bootstrap_mediation(
    statistic_fn = np_statistic,
    method = "nonparametric",
    data = data,
    n_boot = 500,
    seed = 123
  )

  # Estimates should be similar (within 0.05)
  expect_true(abs(boot_param@estimate - boot_nonparam@estimate) < 0.05)

  # CIs should overlap substantially
  # Check that the CIs have at least 50% overlap
  overlap_lower <- max(boot_param@ci_lower, boot_nonparam@ci_lower)
  overlap_upper <- min(boot_param@ci_upper, boot_nonparam@ci_upper)
  overlap_width <- max(0, overlap_upper - overlap_lower)

  param_width <- boot_param@ci_upper - boot_param@ci_lower
  nonparam_width <- boot_nonparam@ci_upper - boot_nonparam@ci_lower
  min_width <- min(param_width, nonparam_width)

  overlap_proportion <- overlap_width / min_width
  expect_true(overlap_proportion > 0.5)  # At least 50% overlap
})


# ==============================================================================
# Variance-Covariance Matrix Validation
# ==============================================================================

test_that("vcov matrix matches separate model vcov matrices", {
  set.seed(42)
  n <- 500
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check that vcov blocks match original models
  vcov_m <- vcov(fit_m)
  vcov_y <- vcov(fit_y)

  # The m_X variance should match
  expect_equal(
    med_data@vcov["m_X", "m_X"],
    vcov_m["X", "X"],
    tolerance = 1e-10
  )

  # The y_M variance should match
  expect_equal(
    med_data@vcov["y_M", "y_M"],
    vcov_y["M", "M"],
    tolerance = 1e-10
  )

  # The y_X variance should match
  expect_equal(
    med_data@vcov["y_X", "y_X"],
    vcov_y["X", "X"],
    tolerance = 1e-10
  )
})


# ==============================================================================
# Residual Variance Validation
# ==============================================================================

test_that("sigma_m and sigma_y match lm sigma values", {
  set.seed(42)
  n <- 500
  sigma_m_true <- 0.8
  sigma_y_true <- 1.2

  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n, sd = sigma_m_true)
  Y <- 0.3 * M + 0.2 * X + rnorm(n, sd = sigma_y_true)
  data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Should match lm sigma
  expect_equal(med_data@sigma_m, sigma(fit_m))
  expect_equal(med_data@sigma_y, sigma(fit_y))

  # Should be close to true values (with some sampling error)
  expect_true(abs(med_data@sigma_m - sigma_m_true) < 0.1)
  expect_true(abs(med_data@sigma_y - sigma_y_true) < 0.1)
})


# ==============================================================================
# Binary Outcome Validation
# ==============================================================================

test_that("logistic outcome coefficients match glm coefficients", {
  set.seed(42)
  n <- 1000
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  # Binary outcome
  logit_p <- 0.5 * M + 0.3 * X
  Y <- rbinom(n, 1, plogis(logit_p))
  data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- glm(Y ~ X + M, data = data, family = binomial())

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # b and c' should be on logit scale (matching GLM)
  expect_equal(med_data@b_path, unname(coef(fit_y)["M"]))
  expect_equal(med_data@c_prime, unname(coef(fit_y)["X"]))

  # sigma_y should be NULL for binomial
  expect_null(med_data@sigma_y)
})
