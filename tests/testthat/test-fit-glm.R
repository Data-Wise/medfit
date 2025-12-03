# Tests for fit_mediation() with GLM engine
#
# Test categories:
# 1. Basic fitting with Gaussian models
# 2. Fitting with binary outcomes
# 3. Input validation / error handling
# 4. Integration with extract_mediation()
# 5. Edge cases

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

# Generate binary outcome mediation data
generate_binary_outcome_data <- function(n = 300, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y_prob <- plogis(0.5 * M + 0.3 * X)
  Y <- rbinom(n, 1, Y_prob)
  data.frame(X = X, M = M, Y = Y)
}


# ==============================================================================
# Basic Fitting with Gaussian Models
# ==============================================================================

test_that("fit_mediation works with basic Gaussian models", {
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

  # Check path coefficients are reasonable given true values (a=0.5, b=0.3, c'=0.2)
  expect_true(abs(med_data@a_path - 0.5) < 0.2)
  expect_true(abs(med_data@b_path - 0.3) < 0.2)
  expect_true(abs(med_data@c_prime - 0.2) < 0.2)
})

test_that("fit_mediation correctly identifies variable names", {
  data <- generate_mediation_data()

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

test_that("fit_mediation extracts sigma correctly", {
  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # sigma should be extracted for Gaussian models
  expect_true(!is.null(med_data@sigma_m))
  expect_true(!is.null(med_data@sigma_y))
  expect_true(med_data@sigma_m > 0)
  expect_true(med_data@sigma_y > 0)
})

test_that("fit_mediation handles models with covariates", {
  data <- generate_mediation_data_with_covariates()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M + Z1 + Z2,
    formula_m = M ~ X + Z1,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Check predictor names include covariates
  expect_true("X" %in% med_data@mediator_predictors)
  expect_true("Z1" %in% med_data@mediator_predictors)
  expect_true("M" %in% med_data@outcome_predictors)
  expect_true("Z2" %in% med_data@outcome_predictors)
})

test_that("fit_mediation uses default engine = 'glm'", {
  data <- generate_mediation_data()

  # Should work without specifying engine
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_s3_class(med_data, "medfit::MediationData")
  expect_true(grepl("glm", med_data@source_package))
})

test_that("fit_mediation sets source_package to indicate fitting method", {
  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_true(grepl("fit_mediation", med_data@source_package))
  expect_true(grepl("glm", med_data@source_package))
})


# ==============================================================================
# Fitting with Binary Outcomes
# ==============================================================================

test_that("fit_mediation works with binary outcome (logistic)", {
  data <- generate_binary_outcome_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    family_y = binomial(),
    family_m = gaussian()
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # sigma_y should be NULL for binomial
  expect_null(med_data@sigma_y)

  # sigma_m should still be present (Gaussian mediator)
  expect_true(!is.null(med_data@sigma_m))
})

test_that("fit_mediation works with different family specifications", {
  data <- generate_mediation_data()

  # Gaussian with explicit family objects
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M",
    family_y = gaussian(),
    family_m = gaussian()
  )

  expect_s3_class(med_data, "medfit::MediationData")
})


# ==============================================================================
# Consistency with Manual Fitting
# ==============================================================================

test_that("fit_mediation produces same results as manual glm fitting", {
  data <- generate_mediation_data()

  # Manual fitting
  fit_m_manual <- glm(M ~ X, data = data, family = gaussian())
  fit_y_manual <- glm(Y ~ X + M, data = data, family = gaussian())

  med_manual <- extract_mediation(
    fit_m_manual,
    model_y = fit_y_manual,
    treatment = "X",
    mediator = "M"
  )

  # Using fit_mediation
  med_fit <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Path coefficients should match exactly
  expect_equal(med_fit@a_path, med_manual@a_path)
  expect_equal(med_fit@b_path, med_manual@b_path)
  expect_equal(med_fit@c_prime, med_manual@c_prime)

  # Sigma values should match
  expect_equal(med_fit@sigma_m, med_manual@sigma_m)
  expect_equal(med_fit@sigma_y, med_manual@sigma_y)
})


# ==============================================================================
# Input Validation and Error Handling
# ==============================================================================

test_that("fit_mediation errors for invalid engine", {
  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M",
      engine = "nonexistent"
    ),
    "arg.*should be one of"  # match.arg error
  )
})

test_that("fit_mediation errors when treatment not in data", {
  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "NonExistent",
      mediator = "M"
    ),
    "Treatment variable.*not found"
  )
})

test_that("fit_mediation errors when mediator not in data", {
  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "NonExistent"
    ),
    "Mediator variable.*not found"
  )
})

test_that("fit_mediation errors when treatment not in mediator formula", {
  data <- generate_mediation_data()
  data$Z <- rnorm(nrow(data))

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ Z,  # Missing X
      data = data,
      treatment = "X",
      mediator = "M"
    ),
    "Treatment.*must appear.*formula_m"
  )
})

test_that("fit_mediation errors when mediator not in outcome formula", {
  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X,  # Missing M
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M"
    ),
    "Mediator.*must appear.*formula_y"
  )
})

test_that("fit_mediation errors when mediator is not response in formula_m", {
  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = Y ~ X,  # Wrong response variable
      data = data,
      treatment = "X",
      mediator = "M"
    ),
    "Mediator model response.*does not match"
  )
})

test_that("fit_mediation errors for empty data", {
  data <- data.frame(X = numeric(0), M = numeric(0), Y = numeric(0))

  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M"
    ),
    "min.rows"  # checkmate: must have >= 1 rows
  )
})

test_that("fit_mediation errors for non-formula input", {
  data <- generate_mediation_data()

  expect_error(
    fit_mediation(
      formula_y = "Y ~ X + M",  # String instead of formula
      formula_m = M ~ X,
      data = data,
      treatment = "X",
      mediator = "M"
    ),
    "formula"  # checkmate: must be a formula
  )
})


# ==============================================================================
# Convergence Handling
# ==============================================================================

test_that("fit_mediation reports convergence status", {
  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Normal models should converge
  expect_true(med_data@converged)
})


# ==============================================================================
# Edge Cases
# ==============================================================================

test_that("fit_mediation works with small sample sizes", {
  data <- generate_mediation_data(n = 30)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@n_obs, 30L)
  expect_s3_class(med_data, "medfit::MediationData")
})

test_that("fit_mediation handles variable names with underscores", {
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

  med_data <- fit_mediation(
    formula_y = outcome_var ~ treatment_var + mediator_var,
    formula_m = mediator_var ~ treatment_var,
    data = data,
    treatment = "treatment_var",
    mediator = "mediator_var"
  )

  expect_equal(med_data@treatment, "treatment_var")
  expect_equal(med_data@mediator, "mediator_var")
  expect_equal(med_data@outcome, "outcome_var")
})

test_that("fit_mediation vcov matrix is properly formed", {
  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # vcov should be square
  expect_equal(nrow(med_data@vcov), ncol(med_data@vcov))

  # vcov dimensions should match estimates length
  expect_equal(nrow(med_data@vcov), length(med_data@estimates))

  # All diagonal elements should be non-negative
  expect_true(all(diag(med_data@vcov) >= 0))
})

test_that("indirect effect can be computed from fitted mediation", {
  data <- generate_mediation_data(a = 0.5, b = 0.4, c_prime = 0.1)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # Compute indirect effect
  indirect <- med_data@a_path * med_data@b_path

  # Should be close to true value (0.5 * 0.4 = 0.2)
  expect_true(abs(indirect - 0.2) < 0.15)
})

test_that("print method works for fitted MediationData", {
  data <- generate_mediation_data()

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = data,
    treatment = "X",
    mediator = "M"
  )

  # print should not error
  expect_output(print(med_data), "MediationData")
  expect_output(print(med_data), "a \\(X -> M\\)")
})
