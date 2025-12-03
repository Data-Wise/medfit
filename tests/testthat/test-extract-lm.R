# Tests for extract_mediation() with lm/glm models
#
# Test categories:
# 1. Basic extraction from lm models
# 2. Extraction from glm models
# 3. Input validation / error handling
# 4. Edge cases

# --- Test Data Generator ---

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
  Z1 <- rnorm(n)
  Z2 <- rnorm(n)
  M <- 0.5 * X + 0.3 * Z1 + rnorm(n)
  Y <- 0.3 * M + 0.2 * X + 0.1 * Z1 + 0.15 * Z2 + rnorm(n)
  data.frame(X = X, M = M, Y = Y, Z1 = Z1, Z2 = Z2)
}


# ==============================================================================
# Basic Extraction from lm Models
# ==============================================================================

test_that("extract_mediation works with basic lm models", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Check path coefficients are extracted correctly
  expect_equal(med_data@a_path, unname(coef(fit_m)["X"]))
  expect_equal(med_data@b_path, unname(coef(fit_y)["M"]))
  expect_equal(med_data@c_prime, unname(coef(fit_y)["X"]))

  # Check paths are reasonable given true values (a=0.5, b=0.3, c'=0.2)
  expect_true(abs(med_data@a_path - 0.5) < 0.2)  # Within 0.2 of true value
  expect_true(abs(med_data@b_path - 0.3) < 0.2)
  expect_true(abs(med_data@c_prime - 0.2) < 0.2)
})

test_that("extract_mediation correctly identifies variable names", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@treatment, "X")
  expect_equal(med_data@mediator, "M")
  expect_equal(med_data@outcome, "Y")
})

test_that("extract_mediation extracts sigma correctly for lm models", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # sigma should be extracted
  expect_true(!is.null(med_data@sigma_m))
  expect_true(!is.null(med_data@sigma_y))
  expect_equal(med_data@sigma_m, sigma(fit_m))
  expect_equal(med_data@sigma_y, sigma(fit_y))
})

test_that("extract_mediation correctly counts observations", {
  data <- generate_mediation_data(n = 150)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@n_obs, 150L)
})

test_that("extract_mediation sets converged = TRUE for lm models", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  expect_true(med_data@converged)
})

test_that("extract_mediation handles models with covariates", {
  data <- generate_mediation_data_with_covariates()

  fit_m <- lm(M ~ X + Z1, data = data)
  fit_y <- lm(Y ~ X + M + Z1 + Z2, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Path coefficients should still be extracted correctly
  expect_equal(med_data@a_path, unname(coef(fit_m)["X"]))
  expect_equal(med_data@b_path, unname(coef(fit_y)["M"]))
  expect_equal(med_data@c_prime, unname(coef(fit_y)["X"]))

  # Check predictor names
  expect_true("X" %in% med_data@mediator_predictors)
  expect_true("Z1" %in% med_data@mediator_predictors)
  expect_true("M" %in% med_data@outcome_predictors)
  expect_true("Z2" %in% med_data@outcome_predictors)
})


# ==============================================================================
# Estimates and Variance-Covariance Matrix
# ==============================================================================

test_that("extract_mediation creates combined estimates vector", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # estimates should contain all coefficients plus aliases
  expect_true("a" %in% names(med_data@estimates))
  expect_true("b" %in% names(med_data@estimates))
  expect_true("c_prime" %in% names(med_data@estimates))

  # Aliases should match path values
  expect_equal(unname(med_data@estimates["a"]), med_data@a_path)
  expect_equal(unname(med_data@estimates["b"]), med_data@b_path)
  expect_equal(unname(med_data@estimates["c_prime"]), med_data@c_prime)
})

test_that("extract_mediation creates square vcov matrix", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # vcov should be square
  expect_equal(nrow(med_data@vcov), ncol(med_data@vcov))

  # vcov dimensions should match estimates length
  expect_equal(nrow(med_data@vcov), length(med_data@estimates))

  # vcov should have named rows and columns
  expect_equal(rownames(med_data@vcov), names(med_data@estimates))
  expect_equal(colnames(med_data@vcov), names(med_data@estimates))
})

test_that("vcov diagonal contains positive variances", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # All diagonal elements should be non-negative (variances)
  expect_true(all(diag(med_data@vcov) >= 0))
})


# ==============================================================================
# GLM Models
# ==============================================================================

test_that("extract_mediation works with glm models (Gaussian)", {
  data <- generate_mediation_data()

  fit_m <- glm(M ~ X, data = data, family = gaussian())
  fit_y <- glm(Y ~ X + M, data = data, family = gaussian())

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Check paths match lm results
  fit_m_lm <- lm(M ~ X, data = data)
  fit_y_lm <- lm(Y ~ X + M, data = data)

  expect_equal(med_data@a_path, unname(coef(fit_m_lm)["X"]), tolerance = 1e-10)
  expect_equal(med_data@b_path, unname(coef(fit_y_lm)["M"]), tolerance = 1e-10)

  # source_package should indicate glm
  expect_equal(med_data@source_package, "stats::glm")
})

test_that("extract_mediation works with binary outcome (logistic)", {
  set.seed(123)
  n <- 300
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y_prob <- plogis(0.5 * M + 0.3 * X)
  Y <- rbinom(n, 1, Y_prob)
  data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- glm(Y ~ X + M, data = data, family = binomial())

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Paths should be on logit scale for outcome model
  expect_equal(med_data@b_path, unname(coef(fit_y)["M"]))
  expect_equal(med_data@c_prime, unname(coef(fit_y)["X"]))

  # sigma_y should be NULL for binomial GLM
  expect_null(med_data@sigma_y)
})

test_that("extract_mediation detects glm convergence", {
  data <- generate_mediation_data()

  fit_m <- glm(M ~ X, data = data, family = gaussian())
  fit_y <- glm(Y ~ X + M, data = data, family = gaussian())

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Normal GLMs should converge
  expect_true(med_data@converged)
})


# ==============================================================================
# Input Validation and Error Handling
# ==============================================================================

test_that("extract_mediation errors when treatment not in mediator model", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  expect_error(
    extract_mediation(
      fit_m,
      model_y = fit_y,
      treatment = "NonExistent",
      mediator = "M"
    ),
    "treatment in mediator model"  # checkmate: Must be element of set
  )
})

test_that("extract_mediation errors when treatment not in outcome model", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ M, data = data)  # Missing X

  expect_error(
    extract_mediation(
      fit_m,
      model_y = fit_y,
      treatment = "X",
      mediator = "M"
    ),
    "treatment in outcome model"  # checkmate: Must be element of set
  )
})

test_that("extract_mediation errors when mediator not in outcome model", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X, data = data)  # Missing M

  expect_error(
    extract_mediation(
      fit_m,
      model_y = fit_y,
      treatment = "X",
      mediator = "M"
    ),
    "mediator in outcome model"  # checkmate: Must be element of set
  )
})

test_that("extract_mediation errors when model_y is missing", {
  data <- generate_mediation_data()
  fit_m <- lm(M ~ X, data = data)

  expect_error(
    extract_mediation(
      fit_m,
      treatment = "X",
      mediator = "M"
    ),
    "model_y"  # checkmate: Must inherit from class 'lm'/'glm'
  )
})

test_that("extract_mediation errors when treatment is not character", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  expect_error(
    extract_mediation(
      fit_m,
      model_y = fit_y,
      treatment = 1,
      mediator = "M"
    ),
    "treatment.*string"  # checkmate: Must be of type 'string'
  )
})

test_that("extract_mediation errors when mediator is not character", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  expect_error(
    extract_mediation(
      fit_m,
      model_y = fit_y,
      treatment = "X",
      mediator = c("M", "M2")
    ),
    "mediator.*length 1"  # checkmate: Must have length 1
  )
})


# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("extract_mediation works with different variable names", {
  set.seed(123)
  n <- 200
  treatment_var <- rnorm(n)
  mediator_var <- 0.5 * treatment_var + rnorm(n)
  outcome_var <- 0.3 * mediator_var + 0.2 * treatment_var + rnorm(n)
  data <- data.frame(
    treatment_var = treatment_var,
    mediator_var = mediator_var,
    outcome_var = outcome_var
  )

  fit_m <- lm(mediator_var ~ treatment_var, data = data)
  fit_y <- lm(outcome_var ~ treatment_var + mediator_var, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "treatment_var",
    mediator = "mediator_var"
  )

  expect_equal(med_data@treatment, "treatment_var")
  expect_equal(med_data@mediator, "mediator_var")
  expect_equal(med_data@outcome, "outcome_var")
})

test_that("extract_mediation handles small sample sizes", {
  # Small sample (n=30)
  data <- generate_mediation_data(n = 30)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@n_obs, 30L)
  expect_s3_class(med_data, "medfit::MediationData")
})

test_that("indirect effect can be computed from extracted paths", {
  data <- generate_mediation_data(a = 0.5, b = 0.4, c_prime = 0.1)

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Compute indirect effect
  indirect <- med_data@a_path * med_data@b_path

  # Should be close to true value (0.5 * 0.4 = 0.2)
  expect_true(abs(indirect - 0.2) < 0.15)
})

test_that("print method works for extracted MediationData", {
  data <- generate_mediation_data()

  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # print should not error
  expect_output(print(med_data), "MediationData")
  expect_output(print(med_data), "a \\(X -> M\\)")
})
