# Integration Tests for medfit Package
#
# These tests verify the full workflow:
# 1. fit_mediation() -> MediationData
# 2. extract_mediation() -> MediationData
# 3. bootstrap_mediation() -> BootstrapResult
#
# Test categories:
# 1. Complete workflow with fit_mediation
# 2. Complete workflow with manual models + extract_mediation
# 3. Comparing fit vs extract paths
# 4. Workflow with covariates
# 5. Workflow with binary outcomes

# --- Test Data Generators ---

#' Generate simple mediation data with known true values
generate_mediation_data <- function(n = 200, a = 0.5, b = 0.3, c_prime = 0.2, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y <- b * M + c_prime * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}

#' Generate mediation data with covariates
generate_mediation_data_with_covariates <- function(n = 300, seed = 123) {
  set.seed(seed)
  # Covariates
  Z1 <- rnorm(n)
  Z2 <- rnorm(n)
  # Treatment
  X <- rnorm(n)
  # Mediator (depends on X and Z1)
  M <- 0.5 * X + 0.3 * Z1 + rnorm(n)
  # Outcome (depends on X, M, Z1, Z2)
  Y <- 0.3 * M + 0.2 * X + 0.15 * Z1 + 0.1 * Z2 + rnorm(n)
  data.frame(X = X, M = M, Y = Y, Z1 = Z1, Z2 = Z2)
}

#' Generate binary outcome mediation data
generate_binary_outcome_data <- function(n = 500, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  # Binary outcome via logistic model
  logit_p <- 0.5 * M + 0.3 * X
  Y <- rbinom(n, 1, plogis(logit_p))
  data.frame(X = X, M = M, Y = Y)
}


# ==============================================================================
# Complete Workflow with fit_mediation
# ==============================================================================

test_that("complete workflow: fit -> bootstrap (parametric)", {
  skip_if_not_installed("MASS")

  data <- generate_mediation_data(n = 200, a = 0.5, b = 0.3, c_prime = 0.2)

  # Step 1: Fit mediation model
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_s3_class(med_data, "medfit::MediationData")

  # Step 2: Define statistic function (indirect effect)
  indirect_effect <- function(theta) {
    theta["a"] * theta["b"]
  }

  # Step 3: Bootstrap inference
  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 200,
    ci_level = 0.95,
    seed = 42
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  expect_equal(boot_result@method, "parametric")

  # Indirect effect should be close to true value (0.5 * 0.3 = 0.15)
  expect_true(abs(boot_result@estimate - 0.15) < 0.1)

  # CI should contain the true value (most of the time)
  # Using wide tolerance since we have limited bootstrap samples
  expect_true(boot_result@ci_lower < 0.25)
  expect_true(boot_result@ci_upper > 0.05)
})

test_that("complete workflow: fit -> bootstrap (nonparametric)", {
  data <- generate_mediation_data(n = 150, a = 0.5, b = 0.3, c_prime = 0.2)

  # Step 1: Fit mediation model
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Step 2: Define statistic function for nonparametric bootstrap
  # This function receives data and must fit models + compute statistic
  np_indirect_effect <- function(d) {
    fit_m <- lm(M ~ X, data = d)
    fit_y <- lm(Y ~ X + M, data = d)
    coef(fit_m)["X"] * coef(fit_y)["M"]
  }

  # Step 3: Nonparametric bootstrap inference
  boot_result <- bootstrap_mediation(
    statistic_fn = np_indirect_effect,
    method = "nonparametric",
    data = data,
    n_boot = 100,  # Smaller for speed
    ci_level = 0.95,
    seed = 42
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  expect_equal(boot_result@method, "nonparametric")

  # Estimate should be reasonable
  expect_true(abs(boot_result@estimate - 0.15) < 0.15)
})

test_that("complete workflow: fit -> plugin estimate", {
  data <- generate_mediation_data()

  # Step 1: Fit
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Step 2: Plugin estimate (no CI)
  indirect_effect <- function(theta) theta["a"] * theta["b"]

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "plugin",
    mediation_data = med_data
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  expect_equal(boot_result@method, "plugin")
  expect_true(is.na(boot_result@ci_lower))
  expect_true(is.na(boot_result@ci_upper))

  # Plugin estimate should match manual calculation
  expected <- med_data@a_path * med_data@b_path
  expect_equal(unname(boot_result@estimate), expected)
})


# ==============================================================================
# Complete Workflow with Manual Models + extract_mediation
# ==============================================================================

test_that("complete workflow: extract -> bootstrap", {
  skip_if_not_installed("MASS")

  data <- generate_mediation_data()

  # Step 1: Fit models manually
  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  # Step 2: Extract mediation structure
  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  expect_s3_class(med_data, "medfit::MediationData")

  # Step 3: Bootstrap
  indirect_effect <- function(theta) theta["a"] * theta["b"]

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
})


# ==============================================================================
# Consistency Between fit_mediation and extract_mediation
# ==============================================================================

test_that("fit_mediation and extract_mediation produce identical paths", {
  data <- generate_mediation_data()

  # Method 1: fit_mediation
  med_fit <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Method 2: manual + extract_mediation
  fit_m <- glm(M ~ X, data = data, family = gaussian())
  fit_y <- glm(Y ~ X + M, data = data, family = gaussian())

  med_extract <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Path coefficients should be identical
  expect_equal(med_fit@a_path, med_extract@a_path)
  expect_equal(med_fit@b_path, med_extract@b_path)
  expect_equal(med_fit@c_prime, med_extract@c_prime)

  # Sigma values should be identical
  expect_equal(med_fit@sigma_m, med_extract@sigma_m)
  expect_equal(med_fit@sigma_y, med_extract@sigma_y)

  # Variable names should match
  expect_equal(med_fit@treatment, med_extract@treatment)
  expect_equal(med_fit@mediator, med_extract@mediator)
  expect_equal(med_fit@outcome, med_extract@outcome)
})


# ==============================================================================
# Workflow with Covariates
# ==============================================================================

test_that("workflow with covariates produces valid results", {
  skip_if_not_installed("MASS")

  data <- generate_mediation_data_with_covariates()

  # Fit with covariates
  med_data <- fit_mediation(
    formula_y = Y ~ X + M + Z1 + Z2,
    formula_m = M ~ X + Z1,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Check predictor names include covariates
  expect_true("Z1" %in% med_data@mediator_predictors)
  expect_true("Z1" %in% med_data@outcome_predictors)
  expect_true("Z2" %in% med_data@outcome_predictors)

  # Bootstrap should work with covariates
  indirect_effect <- function(theta) theta["a"] * theta["b"]

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
  expect_true(!is.na(boot_result@estimate))
})


# ==============================================================================
# Workflow with Binary Outcomes
# ==============================================================================

test_that("workflow with binary outcome (logistic) produces valid results", {
  skip_if_not_installed("MASS")

  data <- generate_binary_outcome_data()

  # Fit with logistic outcome
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    family_y = binomial(),
    family_m = gaussian()
  )

  # sigma_y should be NULL for binomial
  expect_null(med_data@sigma_y)

  # sigma_m should be present (Gaussian mediator)
  expect_true(!is.null(med_data@sigma_m))

  # Bootstrap should work
  indirect_effect <- function(theta) theta["a"] * theta["b"]

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
})


# ==============================================================================
# Print and Summary Methods in Workflow
# ==============================================================================

test_that("print methods work throughout workflow", {
  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Print MediationData
  expect_output(print(med_data), "MediationData")
  expect_output(print(med_data), "a \\(X -> M\\)")
  expect_output(print(med_data), "Indirect")

  # Summary MediationData
  summ <- summary(med_data)
  expect_s3_class(summ, "summary.MediationData")
  expect_output(print(summ), "Summary of MediationData")
})

test_that("print methods work for BootstrapResult", {
  skip_if_not_installed("MASS")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  indirect_effect <- function(theta) theta["a"] * theta["b"]

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 50,
    seed = 123
  )

  # Print BootstrapResult
  expect_output(print(boot_result), "BootstrapResult")
  expect_output(print(boot_result), "parametric")
  expect_output(print(boot_result), "Confidence Interval")

  # Summary BootstrapResult
  summ <- summary(boot_result)
  expect_s3_class(summ, "summary.BootstrapResult")
})


# ==============================================================================
# Statistical Properties Tests
# ==============================================================================

test_that("bootstrap CI contains true value most of the time", {
  skip_if_not_installed("MASS")
  skip_on_cran()  # Skip on CRAN due to time

  # Run multiple replications to check coverage
  n_reps <- 20
  true_indirect <- 0.5 * 0.3  # = 0.15
  contains_true <- logical(n_reps)

  for (i in seq_len(n_reps)) {
    data <- generate_mediation_data(n = 200, a = 0.5, b = 0.3, seed = i * 100)

    med_data <- fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M"
    )

    indirect_effect <- function(theta) theta["a"] * theta["b"]

    boot_result <- bootstrap_mediation(
      statistic_fn = indirect_effect,
      method = "parametric",
      mediation_data = med_data,
      n_boot = 500,
      ci_level = 0.95,
      seed = i
    )

    contains_true[i] <- boot_result@ci_lower <= true_indirect &&
                        boot_result@ci_upper >= true_indirect
  }

  # Coverage should be roughly 95% (allow 70-100% given small n_reps)
  coverage <- mean(contains_true)
  expect_true(coverage >= 0.70)  # At least 70% coverage
})


# ==============================================================================
# Reproducibility Tests
# ==============================================================================

test_that("entire workflow is reproducible with seed", {
  skip_if_not_installed("MASS")

  data <- generate_mediation_data(seed = 999)

  indirect_effect <- function(theta) theta["a"] * theta["b"]

  # First run
  med1 <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  boot1 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med1,
    n_boot = 100,
    seed = 42
  )

  # Second run (same seed)
  med2 <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  boot2 <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med2,
    n_boot = 100,
    seed = 42
  )

  # Results should be identical
  expect_equal(med1@a_path, med2@a_path)
  expect_equal(boot1@estimate, boot2@estimate)
  expect_equal(boot1@ci_lower, boot2@ci_lower)
  expect_equal(boot1@ci_upper, boot2@ci_upper)
  expect_equal(boot1@boot_estimates, boot2@boot_estimates)
})


# ==============================================================================
# Edge Cases in Workflow
# ==============================================================================

test_that("workflow handles small sample sizes", {
  skip_if_not_installed("MASS")

  data <- generate_mediation_data(n = 30, seed = 123)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@n_obs, 30L)

  indirect_effect <- function(theta) theta["a"] * theta["b"]

  # Bootstrap should still work (though estimates may be noisy)
  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 50,
    seed = 123
  )

  expect_s3_class(boot_result, "medfit::BootstrapResult")
})

test_that("workflow handles zero effect", {
  skip_if_not_installed("MASS")

  # Generate data with zero a path
  data <- generate_mediation_data(n = 200, a = 0, b = 0.3, c_prime = 0.2)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # a_path should be close to 0
  expect_true(abs(med_data@a_path) < 0.2)

  indirect_effect <- function(theta) theta["a"] * theta["b"]

  boot_result <- bootstrap_mediation(
    statistic_fn = indirect_effect,
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  # Indirect effect should be close to 0
  expect_true(abs(boot_result@estimate) < 0.1)

  # CI should contain 0
  expect_true(boot_result@ci_lower <= 0.05)
  expect_true(boot_result@ci_upper >= -0.05)
})
