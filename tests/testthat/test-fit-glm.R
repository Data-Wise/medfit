# Tests for fit_mediation() with GLM engine
#
# Test categories:
# 1. Basic GLM fitting (Gaussian family)
# 2. GLM with different families (binomial, poisson)
# 3. Formula interface and variable detection
# 4. Models with covariates
# 5. Convergence detection
# 6. Input validation / error handling
# 7. Comparison with manual lm/glm + extract_mediation
#
# Note: Tests are skipped until fit_mediation() is implemented

# --- Test Data Generators ---

# Generate simple mediation data
generate_mediation_data <- function(n = 200, a = 0.5, b = 0.3, c_prime = 0.2, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y <- b * M + c_prime * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}

# Generate mediation data with covariates
generate_mediation_data_with_covariates <- function(n = 200, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  C1 <- rnorm(n)
  C2 <- rnorm(n)
  M <- 0.5 * X + 0.3 * C1 + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + 0.1 * C1 + 0.15 * C2 + rnorm(n)
  data.frame(X = X, M = M, Y = Y, C1 = C1, C2 = C2)
}

# Generate binary outcome data
generate_binary_outcome_data <- function(n = 300, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y_prob <- plogis(0.5 * M + 0.3 * X)
  Y <- rbinom(n, 1, Y_prob)
  data.frame(X = X, M = M, Y = Y)
}

# Generate count outcome data
generate_count_outcome_data <- function(n = 300, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y_lambda <- exp(0.3 * M + 0.2 * X + 1)
  Y <- rpois(n, Y_lambda)
  data.frame(X = X, M = M, Y = Y)
}


# ==============================================================================
# Basic GLM Fitting (Gaussian Family)
# ==============================================================================

test_that("fit_mediation works with basic Gaussian GLM", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Check that paths are reasonable
  expect_true(is.numeric(med_data@a_path))
  expect_true(is.numeric(med_data@b_path))
  expect_true(is.numeric(med_data@c_prime))

  # Check metadata
  expect_equal(med_data@treatment, "X")
  expect_equal(med_data@mediator, "M")
  expect_equal(med_data@outcome, "Y")
  expect_true(med_data@converged)
})


test_that("fit_mediation extracts sigma for Gaussian models", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm",
    family_y = gaussian(),
    family_m = gaussian()
  )

  # Gaussian models should have sigma values
  expect_true(!is.null(med_data@sigma_m))
  expect_true(!is.null(med_data@sigma_y))
  expect_true(med_data@sigma_m > 0)
  expect_true(med_data@sigma_y > 0)
})


test_that("fit_mediation produces reasonable path estimates", {
  skip("fit_mediation() not yet implemented")

  # Known data generating process: a=0.5, b=0.4, c'=0.1
  data <- generate_mediation_data(a = 0.5, b = 0.4, c_prime = 0.1, n = 500)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Estimates should be close to true values (with large n)
  expect_true(abs(med_data@a_path - 0.5) < 0.1)
  expect_true(abs(med_data@b_path - 0.4) < 0.1)
  expect_true(abs(med_data@c_prime - 0.1) < 0.1)
})


test_that("fit_mediation creates valid vcov matrix", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # vcov should be square
  expect_equal(nrow(med_data@vcov), ncol(med_data@vcov))

  # vcov dimensions should match estimates length
  expect_equal(nrow(med_data@vcov), length(med_data@estimates))

  # Diagonal should be positive (variances)
  expect_true(all(diag(med_data@vcov) > 0))

  # Should be symmetric
  expect_true(isSymmetric(med_data@vcov))
})


test_that("fit_mediation stores correct sample size", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data(n = 150)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  expect_equal(med_data@n_obs, 150L)
})


# ==============================================================================
# GLM with Different Families
# ==============================================================================

test_that("fit_mediation works with binary outcome (binomial family)", {
  skip("fit_mediation() not yet implemented")

  data <- generate_binary_outcome_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm",
    family_y = binomial()
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Binary outcome should have NULL sigma_y
  expect_null(med_data@sigma_y)

  # Mediator (Gaussian) should have sigma_m
  expect_true(!is.null(med_data@sigma_m))

  # Paths should be on appropriate scales
  expect_true(is.numeric(med_data@b_path))  # logit scale
  expect_true(is.numeric(med_data@c_prime))  # logit scale
})


test_that("fit_mediation works with count outcome (poisson family)", {
  skip("fit_mediation() not yet implemented")

  data <- generate_count_outcome_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm",
    family_y = poisson()
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Poisson outcome should have NULL sigma_y
  expect_null(med_data@sigma_y)

  # Should converge
  expect_true(med_data@converged)
})


test_that("fit_mediation works with binary mediator (binomial family)", {
  skip("fit_mediation() not yet implemented")

  set.seed(123)
  n <- 300
  X <- rnorm(n)
  M_prob <- plogis(0.5 * X)
  M <- rbinom(n, 1, M_prob)
  Y <- 0.3 * M + 0.2 * X + rnorm(n)
  data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm",
    family_m = binomial()
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Binary mediator should have NULL sigma_m
  expect_null(med_data@sigma_m)

  # Gaussian outcome should have sigma_y
  expect_true(!is.null(med_data@sigma_y))
})


test_that("fit_mediation works with both binary mediator and outcome", {
  skip("fit_mediation() not yet implemented")

  set.seed(123)
  n <- 300
  X <- rnorm(n)
  M_prob <- plogis(0.5 * X)
  M <- rbinom(n, 1, M_prob)
  Y_prob <- plogis(0.3 * M + 0.2 * X)
  Y <- rbinom(n, 1, Y_prob)
  data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm",
    family_y = binomial(),
    family_m = binomial()
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Both should be NULL for non-Gaussian
  expect_null(med_data@sigma_m)
  expect_null(med_data@sigma_y)
})


# ==============================================================================
# Formula Interface and Variable Detection
# ==============================================================================

test_that("fit_mediation correctly parses formulas", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data_with_covariates()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M + C1 + C2,
    formula_m = M ~ X + C1,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Check predictor lists
  expect_true("X" %in% med_data@mediator_predictors)
  expect_true("C1" %in% med_data@mediator_predictors)
  expect_false("C2" %in% med_data@mediator_predictors)  # Not in M model

  expect_true("X" %in% med_data@outcome_predictors)
  expect_true("M" %in% med_data@outcome_predictors)
  expect_true("C1" %in% med_data@outcome_predictors)
  expect_true("C2" %in% med_data@outcome_predictors)
})


test_that("fit_mediation auto-detects outcome variable from formula_y", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  # Outcome variable is Y (LHS of formula_y)
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  expect_equal(med_data@outcome, "Y")
})


test_that("fit_mediation handles formulas with transformations", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()
  data$X_squared <- data$X^2

  med_data <- fit_mediation(
    formula_y = Y ~ X + M + I(X^2),
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Should still identify variables correctly
  expect_s3_class(med_data, "medfit::MediationData")
})


test_that("fit_mediation handles interaction terms", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data_with_covariates()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M + C1 + X:C1,
    formula_m = M ~ X + C1,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  expect_s3_class(med_data, "medfit::MediationData")
})


# ==============================================================================
# Models with Covariates
# ==============================================================================

test_that("fit_mediation handles multiple covariates", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data_with_covariates()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M + C1 + C2,
    formula_m = M ~ X + C1,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Paths should still be extracted correctly
  expect_true(is.numeric(med_data@a_path))
  expect_true(is.numeric(med_data@b_path))
  expect_true(is.numeric(med_data@c_prime))

  # estimates should include all parameters
  expect_true(length(med_data@estimates) > 3)  # More than just a, b, c'
})


test_that("fit_mediation handles different covariates in M and Y models", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data_with_covariates()

  # M model has only C1, Y model has both C1 and C2
  med_data <- fit_mediation(
    formula_y = Y ~ X + M + C1 + C2,
    formula_m = M ~ X + C1,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  expect_s3_class(med_data, "medfit::MediationData")

  # Predictor lists should reflect formula specifications
  expect_true("C1" %in% med_data@mediator_predictors)
  expect_false("C2" %in% med_data@mediator_predictors)
  expect_true("C2" %in% med_data@outcome_predictors)
})


# ==============================================================================
# Convergence Detection
# ==============================================================================

test_that("fit_mediation detects convergence for normal models", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  expect_true(med_data@converged)
})


test_that("fit_mediation detects non-convergence", {
  skip("fit_mediation() not yet implemented")

  # Create data that might cause convergence issues
  set.seed(123)
  n <- 50
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  # Perfect separation for binary outcome
  Y <- ifelse(M > 0, 1, 0)
  data <- data.frame(X = X, M = M, Y = Y)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm",
    family_y = binomial()
  )

  # May or may not converge - just check that converged flag is set
  expect_true(is.logical(med_data@converged))
})


# ==============================================================================
# Input Validation and Error Handling
# ==============================================================================

test_that("fit_mediation errors when treatment not in mediator formula", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ 1,  # Missing X
      data = data,
      treatment = "X",
      mediator = "M",
      engine = "glm"
    ),
    "treatment.*mediator.*formula"
  )
})


test_that("fit_mediation errors when treatment not in outcome formula", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ M,  # Missing X
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M",
      engine = "glm"
    ),
    "treatment.*outcome.*formula"
  )
})


test_that("fit_mediation errors when mediator not in outcome formula", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X,  # Missing M
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M",
      engine = "glm"
    ),
    "mediator.*outcome.*formula"
  )
})


test_that("fit_mediation errors for invalid engine", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M",
      engine = "invalid_engine"
    ),
    "engine"
  )
})


test_that("fit_mediation errors when data is not a data.frame", {
  skip("fit_mediation() not yet implemented")

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = "not a data frame",
      treatment = "X",
      mediator = "M",
      engine = "glm"
    ),
    "data.*data.frame"
  )
})


test_that("fit_mediation errors when treatment variable not in data", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ NonExistent + M,
      formula_m = M ~ NonExistent,
      data = data,
      treatment = "NonExistent",
      mediator = "M",
      engine = "glm"
    ),
    "NonExistent.*not found.*data"
  )
})


test_that("fit_mediation errors when mediator variable not in data", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + NonExistent,
      formula_m = NonExistent ~ X,
      data = data,
      treatment = "X",
      mediator = "NonExistent",
      engine = "glm"
    ),
    "NonExistent.*not found.*data"
  )
})


test_that("fit_mediation errors for invalid family_y", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M",
      engine = "glm",
      family_y = "not a family object"
    ),
    "family_y"
  )
})


# ==============================================================================
# Comparison with Manual lm/glm + extract_mediation
# ==============================================================================

test_that("fit_mediation produces same results as manual fitting", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  # Manual approach
  fit_m_manual <- lm(M ~ X, data = data)
  fit_y_manual <- lm(Y ~ X + M, data = data)
  med_manual <- extract_mediation(
    fit_m_manual,
    model_y = fit_y_manual,
    treatment = "X",
    mediator = "M"
  )

  # fit_mediation approach
  med_auto <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Results should be identical
  expect_equal(med_auto@a_path, med_manual@a_path, tolerance = 1e-10)
  expect_equal(med_auto@b_path, med_manual@b_path, tolerance = 1e-10)
  expect_equal(med_auto@c_prime, med_manual@c_prime, tolerance = 1e-10)
  expect_equal(med_auto@sigma_m, med_manual@sigma_m, tolerance = 1e-10)
  expect_equal(med_auto@sigma_y, med_manual@sigma_y, tolerance = 1e-10)
})


test_that("fit_mediation with covariates matches manual fitting", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data_with_covariates()

  # Manual approach
  fit_m_manual <- lm(M ~ X + C1, data = data)
  fit_y_manual <- lm(Y ~ X + M + C1 + C2, data = data)
  med_manual <- extract_mediation(
    fit_m_manual,
    model_y = fit_y_manual,
    treatment = "X",
    mediator = "M"
  )

  # fit_mediation approach
  med_auto <- fit_mediation(
    formula_y = Y ~ X + M + C1 + C2,
    formula_m = M ~ X + C1,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Results should be identical
  expect_equal(med_auto@a_path, med_manual@a_path, tolerance = 1e-10)
  expect_equal(med_auto@b_path, med_manual@b_path, tolerance = 1e-10)
  expect_equal(med_auto@c_prime, med_manual@c_prime, tolerance = 1e-10)
})


# ==============================================================================
# Integration with Other Functions
# ==============================================================================

test_that("fit_mediation output works with print method", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  expect_output(print(med_data), "MediationData")
  expect_output(print(med_data), "a \\(X -> M\\)")
})


test_that("fit_mediation output works with summary method", {
  skip("fit_mediation() not yet implemented")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  summ <- summary(med_data)

  expect_s3_class(summ, "summary.MediationData")
  expect_true("paths" %in% names(summ))
})


test_that("fit_mediation output can be used with bootstrap_mediation", {
  skip("fit_mediation() not yet implemented")
  skip("bootstrap_mediation() not yet implemented")

  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    engine = "glm"
  )

  # Should be able to bootstrap
  result <- bootstrap_mediation(
    statistic_fn = function(theta) theta["a"] * theta["b"],
    method = "parametric",
    mediation_data = med_data,
    n_boot = 100,
    seed = 123
  )

  expect_s3_class(result, "medfit::BootstrapResult")
})
