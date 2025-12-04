# Tests for extract_mediation() with lavaan models
#
# Test categories:
# 1. Basic extraction from labeled lavaan models
# 2. Extraction from unlabeled lavaan models (by variable names)
# 3. Input validation / error handling
# 4. Comparison with lm extraction
#
# Note: Tests are skipped if lavaan is not installed

# Skip all tests if lavaan is not available
skip_if_not_installed("lavaan")

# --- Test Data Generator ---

# Generate simple mediation data
generate_mediation_data <- function(n = 200, a = 0.5, b = 0.3, c_prime = 0.2, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y <- b * M + c_prime * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}


# ==============================================================================
# Basic Extraction from Labeled lavaan Models
# ==============================================================================

test_that("extract_mediation works with labeled lavaan model", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  # Define lavaan model with labels
  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  # Skip if lavaan method not registered (happens in some test contexts)
  skip_if(
    !requireNamespace("lavaan", quietly = TRUE),
    "lavaan not available"
  )

  # Use the internal function directly since S7 dispatch may not work in tests
  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Check variable names
  expect_equal(med_data@treatment, "X")
  expect_equal(med_data@mediator, "M")
  expect_equal(med_data@outcome, "Y")

  # Check paths are extracted (should be close to true values)
  expect_true(abs(med_data@a_path - 0.5) < 0.2)
  expect_true(abs(med_data@b_path - 0.3) < 0.2)
  expect_true(abs(med_data@c_prime - 0.2) < 0.2)
})

test_that("extract_mediation extracts correct estimates from labeled model", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  # Get lavaan's estimates for comparison
  param_est <- lavaan::parameterEstimates(fit)
  a_lavaan <- param_est[param_est$label == "a", "est"]
  b_lavaan <- param_est[param_est$label == "b", "est"]
  cp_lavaan <- param_est[param_est$label == "cp", "est"]

  # Check paths match lavaan's estimates exactly
  expect_equal(med_data@a_path, a_lavaan, tolerance = 1e-10)
  expect_equal(med_data@b_path, b_lavaan, tolerance = 1e-10)
  expect_equal(med_data@c_prime, cp_lavaan, tolerance = 1e-10)
})

test_that("extract_mediation extracts vcov from lavaan model", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  # vcov should be square
  expect_equal(nrow(med_data@vcov), ncol(med_data@vcov))

  # vcov dimensions should match estimates length
  expect_equal(nrow(med_data@vcov), length(med_data@estimates))

  # Diagonal should have positive values (variances)
  expect_true(all(diag(med_data@vcov) >= 0))
})


# ==============================================================================
# Extraction from Unlabeled lavaan Models
# ==============================================================================

test_that("extract_mediation works with unlabeled lavaan model", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  # Define lavaan model WITHOUT labels
  model <- "
    M ~ X
    Y ~ M + X
  "

  fit <- lavaan::sem(model, data = data)

  # Extract by variable names
  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Check paths are extracted
  expect_true(is.numeric(med_data@a_path))
  expect_true(is.numeric(med_data@b_path))
  expect_true(is.numeric(med_data@c_prime))
})

test_that("extract_mediation auto-detects outcome variable", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ X
    Y ~ M + X
  "

  fit <- lavaan::sem(model, data = data)

  # Don't specify outcome - should auto-detect
  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@outcome, "Y")
})


# ==============================================================================
# Residual Variances and Metadata
# ==============================================================================

test_that("extract_mediation extracts residual SDs from lavaan model", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  # sigma_m and sigma_y should be extracted
  expect_true(!is.null(med_data@sigma_m))
  expect_true(!is.null(med_data@sigma_y))

  # Should be positive
  expect_true(med_data@sigma_m > 0)
  expect_true(med_data@sigma_y > 0)
})

test_that("extract_mediation extracts sample size from lavaan model", {
  skip_if_not_installed("lavaan")

  n <- 150
  data <- generate_mediation_data(n = n)

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@n_obs, n)
})

test_that("extract_mediation detects convergence from lavaan model", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  # Normal model should converge
  expect_true(med_data@converged)
})

test_that("extract_mediation sets source_package to lavaan", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(med_data@source_package, "lavaan")
})


# ==============================================================================
# Input Validation and Error Handling
# ==============================================================================

test_that("extract_mediation_lavaan errors without lavaan installed", {
  # This test checks the requireNamespace check
  # Since we're in a context where lavaan IS installed (or skipped),
  # we can't easily test the error case
  skip("Cannot test requireNamespace error when lavaan is installed")
})

test_that("extract_mediation errors for invalid treatment argument", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  expect_error(
    extract_mediation_lavaan(
      fit,
      treatment = 1,  # Not a character
      mediator = "M"
    ),
    "treatment.*string"  # checkmate: Must be of type 'string'
  )
})

test_that("extract_mediation errors for invalid mediator argument", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  expect_error(
    extract_mediation_lavaan(
      fit,
      treatment = "X",
      mediator = c("M1", "M2")  # Multiple values
    ),
    "mediator.*length 1"  # checkmate: Must have length 1
  )
})

test_that("extract_mediation errors when treatment not in model", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  # Model without X predicting M
  model <- "
    M ~ 1
    Y ~ M
  "

  fit <- lavaan::sem(model, data = data)

  expect_error(
    extract_mediation_lavaan(
      fit,
      treatment = "X",
      mediator = "M",
      outcome = "Y"
    ),
    "Could not find a path"
  )
})


# ==============================================================================
# Standardized Coefficients
# ==============================================================================

test_that("extract_mediation can extract standardized coefficients", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    standardized = TRUE
  )

  # Get lavaan's standardized estimates for comparison
  std_est <- lavaan::standardizedSolution(fit)
  a_std <- std_est[std_est$label == "a", "est.std"]
  b_std <- std_est[std_est$label == "b", "est.std"]

  # Standardized paths should match
  expect_equal(med_data@a_path, a_std, tolerance = 1e-10)
  expect_equal(med_data@b_path, b_std, tolerance = 1e-10)
})


# ==============================================================================
# Comparison with lm Extraction
# ==============================================================================

test_that("lavaan extraction produces similar results to lm extraction", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data(n = 500, seed = 456)

  # Fit with lm
  fit_m_lm <- lm(M ~ X, data = data)
  fit_y_lm <- lm(Y ~ X + M, data = data)

  med_lm <- extract_mediation(
    fit_m_lm,
    model_y = fit_y_lm,
    treatment = "X",
    mediator = "M"
  )

  # Fit with lavaan
  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit_lavaan <- lavaan::sem(model, data = data)

  med_lavaan <- extract_mediation_lavaan(
    fit_lavaan,
    treatment = "X",
    mediator = "M"
  )

  # Path estimates should be very similar (ML vs OLS)
  expect_equal(med_lavaan@a_path, med_lm@a_path, tolerance = 0.01)
  expect_equal(med_lavaan@b_path, med_lm@b_path, tolerance = 0.01)
  expect_equal(med_lavaan@c_prime, med_lm@c_prime, tolerance = 0.01)
})

test_that("indirect effect can be computed from lavaan extraction", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data(a = 0.5, b = 0.4, c_prime = 0.1)

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  # Compute indirect effect
  indirect <- med_data@a_path * med_data@b_path

  # Should be close to true value (0.5 * 0.4 = 0.2)
  expect_true(abs(indirect - 0.2) < 0.15)
})


# ==============================================================================
# Custom Path Labels
# ==============================================================================

test_that("extract_mediation works with custom path labels", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  # Model with custom labels
  model <- "
    M ~ path_a*X
    Y ~ path_b*M + direct*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M",
    a_label = "path_a",
    b_label = "path_b",
    cp_label = "direct"
  )

  # Check return type
  expect_s3_class(med_data, "medfit::MediationData")

  # Check paths are extracted
  expect_true(is.numeric(med_data@a_path))
  expect_true(is.numeric(med_data@b_path))
  expect_true(is.numeric(med_data@c_prime))
})


# ==============================================================================
# Print Method Works with lavaan-Extracted Data
# ==============================================================================

test_that("print method works for lavaan-extracted MediationData", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()

  model <- "
    M ~ a*X
    Y ~ b*M + cp*X
  "

  fit <- lavaan::sem(model, data = data)

  med_data <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator = "M"
  )

  # print should not error
  expect_output(print(med_data), "MediationData")
  expect_output(print(med_data), "a \\(X -> M\\)")
})
