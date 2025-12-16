# Tests for fit_mediation() with GLM engine

test_that("fit_mediation works with basic continuous variables", {
  # Create test data
  set.seed(123)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Fit mediation model
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  # Check class
  expect_true(S7::S7_inherits(med_data, MediationData))

  # Check variable names
  expect_equal(med_data@treatment, "X")
  expect_equal(med_data@mediator, "M")
  expect_equal(med_data@outcome, "Y")

  # Check that paths are reasonable (close to true values)
  expect_true(abs(med_data@a_path - 0.5) < 0.3)  # True a = 0.5
  expect_true(abs(med_data@b_path - 0.4) < 0.3)  # True b = 0.4
  expect_true(abs(med_data@c_prime - 0.3) < 0.3)  # True c' = 0.3

  # Check metadata
  expect_equal(med_data@n_obs, n)
  expect_true(med_data@converged)
})


test_that("fit_mediation works with covariates", {
  # Create test data with covariates
  set.seed(456)
  n <- 100
  X <- rnorm(n)
  C1 <- rnorm(n)
  M <- 0.5 * X + 0.2 * C1 + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + 0.15 * C1 + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y, C1 = C1)

  # Fit mediation model with covariates
  med_data <- fit_mediation(
    formula_y = Y ~ X + M + C1,
    formula_m = M ~ X + C1,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  # Check class
  expect_true(S7::S7_inherits(med_data, MediationData))

  # Check predictor names include covariate
  expect_true("C1" %in% med_data@mediator_predictors)
  expect_true("C1" %in% med_data@outcome_predictors)
})


test_that("fit_mediation works with binary outcome", {
  # Create test data with binary outcome
  set.seed(789)
  n <- 200
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  prob_Y <- plogis(0.3 * X + 0.4 * M)
  Y <- rbinom(n, 1, prob_Y)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Fit mediation model with binary outcome
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M",
    family_y = binomial()
  )

  # Check class
  expect_true(S7::S7_inherits(med_data, MediationData))

  # Sigma for M should be present (gaussian)
  expect_true(!is.null(med_data@sigma_m))

  # Sigma for Y should be NULL (binomial)
  expect_null(med_data@sigma_y)

  # Check source package indicates GLM
  expect_equal(med_data@source_package, "stats::glm")
})


test_that("fit_mediation validates required arguments", {
  # Create minimal test data
  set.seed(111)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )

  # Missing formula_y
  expect_error(
    fit_mediation(formula_m = M ~ X, data = test_data, treatment = "X", mediator = "M"),
    "formula_y"
  )

  # Missing formula_m
  expect_error(
    fit_mediation(formula_y = Y ~ X + M, data = test_data, treatment = "X", mediator = "M"),
    "formula_m"
  )

  # Missing data
  expect_error(
    fit_mediation(formula_y = Y ~ X + M, formula_m = M ~ X, treatment = "X", mediator = "M"),
    "data"
  )

  # Missing treatment
  expect_error(
    fit_mediation(formula_y = Y ~ X + M, formula_m = M ~ X, data = test_data, mediator = "M"),
    "treatment"
  )

  # Missing mediator
  expect_error(
    fit_mediation(formula_y = Y ~ X + M, formula_m = M ~ X, data = test_data, treatment = "X"),
    "mediator"
  )
})


test_that("fit_mediation validates variables in data", {
  # Create test data
  set.seed(222)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )

  # Wrong treatment name
  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = test_data,
      treatment = "Z",
      mediator = "M"
    ),
    "Treatment variable 'Z' not found in data"
  )

  # Wrong mediator name
  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = test_data,
      treatment = "X",
      mediator = "Z"
    ),
    "Mediator variable 'Z' not found in data"
  )
})


test_that("fit_mediation validates formula structure", {
  # Create test data
  set.seed(333)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )

  # Treatment not in formula_y
  expect_error(
    fit_mediation(
      formula_y = Y ~ M,  # Missing X
      formula_m = M ~ X,
      data = test_data,
      treatment = "X",
      mediator = "M"
    ),
    "Treatment variable 'X' must be in formula_y"
  )

  # Treatment not in formula_m
  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ 1,  # Missing X
      data = test_data,
      treatment = "X",
      mediator = "M"
    ),
    "Treatment variable 'X' must be in formula_m"
  )

  # Mediator not in formula_y
  expect_error(
    fit_mediation(
      formula_y = Y ~ X,  # Missing M
      formula_m = M ~ X,
      data = test_data,
      treatment = "X",
      mediator = "M"
    ),
    "Mediator variable 'M' must be in formula_y"
  )
})


test_that("fit_mediation result matches manual extraction", {
  # Create test data
  set.seed(444)
  n <- 100
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Fit using fit_mediation
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  # Manually fit and extract
  fit_m_manual <- lm(M ~ X, data = test_data)
  fit_y_manual <- lm(Y ~ X + M, data = test_data)
  med_data_manual <- extract_mediation(
    fit_m_manual,
    model_y = fit_y_manual,
    treatment = "X",
    mediator = "M"
  )

  # Results should match
  expect_equal(med_data@a_path, med_data_manual@a_path)
  expect_equal(med_data@b_path, med_data_manual@b_path)
  expect_equal(med_data@c_prime, med_data_manual@c_prime)
  expect_equal(med_data@estimates, med_data_manual@estimates)
})


test_that("fit_mediation engine argument is validated", {
  # Create test data
  set.seed(555)
  n <- 50
  test_data <- data.frame(
    X = rnorm(n),
    M = rnorm(n),
    Y = rnorm(n)
  )

  # Invalid engine
  expect_error(
    fit_mediation(
      formula_y = Y ~ X + M,
      formula_m = M ~ X,
      data = test_data,
      treatment = "X",
      mediator = "M",
      engine = "invalid"
    ),
    "'arg' should be one of"
  )
})


test_that("print method works for fit_mediation result", {
  # Create test data
  set.seed(666)
  n <- 50
  X <- rnorm(n)
  M <- 0.5 * X + rnorm(n)
  Y <- 0.3 * X + 0.4 * M + rnorm(n)
  test_data <- data.frame(X = X, M = M, Y = Y)

  # Fit model
  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = test_data,
    treatment = "X",
    mediator = "M"
  )

  # Should print without error
  expect_output(print(med_data), "MediationData object")
})
