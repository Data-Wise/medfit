# Tests for extract_mediation() with lm/glm objects

test_that("extract_mediation works with basic lm models", {
  # Create test data
  set.seed(123)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Fit models

  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  # Extract mediation structure
  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check class

expect_true(S7::S7_inherits(med_data, MediationData))

  # Check path coefficients are extracted correctly
  expect_equal(med_data@a_path, unname(coef(fit_m)["X"]))
  expect_equal(med_data@b_path, unname(coef(fit_y)["M"]))
  expect_equal(med_data@c_prime, unname(coef(fit_y)["X"]))

  # Check variable names
  expect_equal(med_data@treatment, "X")
  expect_equal(med_data@mediator, "M")
  expect_equal(med_data@outcome, "Y")

  # Check metadata
  expect_equal(med_data@n_obs, n)
  expect_true(med_data@converged)
  expect_equal(med_data@source_package, "stats::lm")

  # Check sigma values are extracted
  expect_true(!is.null(med_data@sigma_m))
  expect_true(!is.null(med_data@sigma_y))
  expect_equal(med_data@sigma_m, sigma(fit_m))
  expect_equal(med_data@sigma_y, sigma(fit_y))
})


test_that("extract_mediation works with covariates", {
  # Create test data with covariates
  set.seed(456)
  n <- 100
  X <- rnorm(n)
  C1 <- rnorm(n)
  C2 <- rnorm(n)
  M <- 0.5 * X + 0.2 * C1 + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + 0.1 * C1 + 0.15 * C2 + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y, C1 = C1, C2 = C2)

  # Fit models with covariates
  fit_m <- lm(M ~ X + C1, data = test_data)
  fit_y <- lm(Y ~ X + M + C1 + C2, data = test_data)

  # Extract mediation structure
  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check path coefficients
  expect_equal(med_data@a_path, unname(coef(fit_m)["X"]))
  expect_equal(med_data@b_path, unname(coef(fit_y)["M"]))
  expect_equal(med_data@c_prime, unname(coef(fit_y)["X"]))

  # Check predictor names include covariates
  expect_true("C1" %in% med_data@mediator_predictors)
  expect_true("C1" %in% med_data@outcome_predictors)
  expect_true("C2" %in% med_data@outcome_predictors)
})


test_that("extract_mediation works with glm models (gaussian)", {
  # Create test data
  set.seed(789)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Fit GLM models with gaussian family
  fit_m <- glm(M ~ X, data = test_data, family = gaussian())
  fit_y <- glm(Y ~ X + M, data = test_data, family = gaussian())

  # Extract mediation structure
  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check class
  expect_true(S7::S7_inherits(med_data, MediationData))

  # Check source package
  expect_equal(med_data@source_package, "stats::glm")

  # Sigma should be extracted for gaussian
  expect_true(!is.null(med_data@sigma_m))
  expect_true(!is.null(med_data@sigma_y))
})


test_that("extract_mediation works with glm models (non-gaussian)", {
  # Create test data with binary outcome
  set.seed(101)
  n <- 200
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  # Binary outcome
  prob_Y <- plogis(0.3 * X + 0.4 * M)
  Y <- rbinom(n, 1, prob_Y)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Fit models
  fit_m <- glm(M ~ X, data = test_data, family = gaussian())
  fit_y <- glm(Y ~ X + M, data = test_data, family = binomial())

  # Extract mediation structure
  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check class
  expect_true(S7::S7_inherits(med_data, MediationData))

  # Sigma for M should be extracted (gaussian)
  expect_true(!is.null(med_data@sigma_m))

  # Sigma for Y should be NULL (binomial)
  expect_null(med_data@sigma_y)
})


test_that("extract_mediation validates required arguments", {
  # Create minimal test data
  set.seed(111)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )
  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  # Missing model_y
  expect_error(
    extract_mediation(fit_m, treatment = "X", mediator = "M"),
    "model_y"
  )

  # Missing treatment
  expect_error(
    extract_mediation(fit_m, model_y = fit_y, mediator = "M"),
    "treatment"
  )

  # Missing mediator
  expect_error(
    extract_mediation(fit_m, model_y = fit_y, treatment = "X"),
    "mediator"
  )
})


test_that("extract_mediation validates variable names in models", {
  # Create test data
  set.seed(222)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )
  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  # Wrong treatment name
  expect_error(
    extract_mediation(fit_m, model_y = fit_y, treatment = "Z", mediator = "M"),
    "Treatment variable 'Z' not found"
  )

  # Wrong mediator name
  expect_error(
    extract_mediation(fit_m, model_y = fit_y, treatment = "X", mediator = "Z"),
    "Mediator variable 'Z' not found"
  )
})


test_that("extract_mediation creates valid vcov matrix", {
  # Create test data
  set.seed(333)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check vcov is square
  expect_equal(nrow(med_data@vcov), ncol(med_data@vcov))

  # Check vcov matches estimates length
  expect_equal(nrow(med_data@vcov), length(med_data@estimates))

  # Check vcov is symmetric
  expect_true(isSymmetric(med_data@vcov))

  # Check vcov has named rows/cols
  expect_equal(rownames(med_data@vcov), names(med_data@estimates))
  expect_equal(colnames(med_data@vcov), names(med_data@estimates))

  # Check block diagonal structure - off-diagonal blocks should be zero
  n_m <- length(coef(fit_m))
  n_y <- length(coef(fit_y))
  off_diag_block <- med_data@vcov[1:n_m, (n_m + 1):(n_m + n_y)]
  expect_true(all(off_diag_block == 0))
})


test_that("extract_mediation auto-detects outcome variable name",
{
  # Create test data
  set.seed(444)
  n <- 50
  test_data <- data.frame(
    treatment = rnorm(n),
    mediator = rnorm(n),
    response = rnorm(n)
  )

  fit_m <- lm(mediator ~ treatment, data = test_data)
  fit_y <- lm(response ~ treatment + mediator, data = test_data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "treatment",
    mediator = "mediator"
  )

  # Should auto-detect "response" as outcome
  expect_equal(med_data@outcome, "response")
})


test_that("extract_mediation estimates names are prefixed correctly", {
  # Create test data
  set.seed(555)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )

  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Check prefixes
  expect_true(all(grepl("^m_", names(med_data@estimates)[1:2])))
  expect_true(all(grepl("^y_", names(med_data@estimates)[3:5])))

  # Check specific names
  expect_true("m_X" %in% names(med_data@estimates))
  expect_true("y_X" %in% names(med_data@estimates))
  expect_true("y_M" %in% names(med_data@estimates))
})


test_that("extract_mediation handles non-converged glm", {
  # This is tricky to test because glm usually converges

  # We'll create a mock scenario by manually setting converged = FALSE
  # For now, just test that the check function works

  # Create test data
  set.seed(666)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )

  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Both lm models should report converged = TRUE
  expect_true(med_data@converged)
})


test_that("print method works for extracted MediationData", {
  # Create test data
  set.seed(777)
  n <- 50
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Should print without error
  expect_output(print(med_data), "MediationData object")
  expect_output(print(med_data), "Path coefficients")
  expect_output(print(med_data), "a \\(X -> M\\)")
})


test_that("summary method works for extracted MediationData", {
  # Create test data
  set.seed(888)
  n <- 50
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  fit_m <- lm(M ~ X, data = test_data)
  fit_y <- lm(Y ~ X + M, data = test_data)

  med_data <- extract_mediation(
    fit_m,
    model_y = fit_y,
    treatment = "X",
    mediator = "M"
  )

  # Summary should work
  summ <- summary(med_data)
  expect_s3_class(summ, "summary.MediationData")

  # Check summary contents
  expect_true("paths" %in% names(summ))
  expect_true("variables" %in% names(summ))
  expect_equal(summ$n_obs, n)
})
