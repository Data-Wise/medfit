# Tests for Base R Generic Methods

test_that("coef() extracts path coefficients", {
  # Generate test data
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = mydata,
    treatment = "X",
    mediator = "M"
  )

  # Test paths extraction
  paths <- coef(med_data)
  expect_named(paths, c("a", "b", "c_prime"))
  expect_length(paths, 3)
  expect_true(all(is.numeric(paths)))

  # Test effects extraction
  effects <- coef(med_data, type = "effects")
  expect_named(effects, c("nie", "nde", "te"))
  expect_length(effects, 3)

  # Verify NIE = a * b
  expect_equal(unname(effects["nie"]), unname(paths["a"] * paths["b"]))

  # Verify TE = NIE + NDE
  expect_equal(unname(effects["te"]), unname(effects["nie"] + effects["nde"]))

  # Test all extraction
  all_coefs <- coef(med_data, type = "all")
  expect_true(length(all_coefs) >= 3)
})


test_that("vcov() extracts variance-covariance matrix", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = mydata,
    treatment = "X",
    mediator = "M"
  )

  v <- vcov(med_data)

  # Should be a matrix

  expect_true(is.matrix(v))

  # Should be square
  expect_equal(nrow(v), ncol(v))

  # Should be same as stored vcov
  expect_identical(v, med_data@vcov)

  # Diagonal should be non-negative (variances)
  expect_true(all(diag(v) >= 0))
})


test_that("nobs() returns number of observations", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = mydata,
    treatment = "X",
    mediator = "M"
  )

  expect_equal(nobs(med_data), 100L)
  expect_type(nobs(med_data), "integer")
})


test_that("confint() computes confidence intervals for paths", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = mydata,
    treatment = "X",
    mediator = "M"
  )

  # Default 95% CI for paths
  ci <- confint(med_data)

  expect_true(is.matrix(ci))
  expect_equal(nrow(ci), 3)  # a, b, c_prime
  expect_equal(ncol(ci), 2)  # lower, upper

  # Lower should be less than upper
  expect_true(all(ci[, 1] < ci[, 2]))

  # Point estimates should be within CI
  paths <- coef(med_data)
  expect_true(all(paths >= ci[, 1] & paths <= ci[, 2]))
})


test_that("confint() respects confidence level", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = mydata,
    treatment = "X",
    mediator = "M"
  )

  ci_95 <- confint(med_data, level = 0.95)
  ci_90 <- confint(med_data, level = 0.90)

  # 90% CI should be narrower than 95% CI
  width_95 <- ci_95[, 2] - ci_95[, 1]
  width_90 <- ci_90[, 2] - ci_90[, 1]
  expect_true(all(width_90 < width_95))
})


test_that("confint() for effects warns about NIE approximation", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = mydata,
    treatment = "X",
    mediator = "M"
  )

  # Should warn about NIE approximation
  expect_warning(
    ci_effects <- confint(med_data, parm = "effects"),
    "NIE may be inaccurate"
  )

  # Should still return matrix with nie, nde, te
  expect_true(is.matrix(ci_effects))
  expect_equal(nrow(ci_effects), 3)
})


test_that("confint() errors for bootstrap method",
{
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  med_data <- fit_mediation(
    formula_y = Y ~ X + M,
    formula_m = M ~ X,
    data = mydata,
    treatment = "X",
    mediator = "M"
  )

  expect_error(
    confint(med_data, method = "boot"),
    "Bootstrap CI requires bootstrap_mediation"
  )
})


test_that("coef() works for SerialMediationData", {
  # Create a SerialMediationData object directly
  serial_data <- SerialMediationData(
    a_path = 0.5,
    d_path = 0.4,
    b_path = 0.3,
    c_prime = 0.1,
    estimates = c(a = 0.5, d = 0.4, b = 0.3, cp = 0.1),
    vcov = diag(4) * 0.01,
    sigma_mediators = c(1.0, 1.1),
    sigma_y = 1.2,
    treatment = "X",
    mediators = c("M1", "M2"),
    outcome = "Y",
    mediator_predictors = list(c("X"), c("X", "M1")),
    outcome_predictors = c("X", "M1", "M2"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "test"
  )

  # Test paths extraction
  paths <- coef(serial_data)
  expect_true("a" %in% names(paths))
  expect_true("d" %in% names(paths))
  expect_true("b" %in% names(paths))
  expect_true("c_prime" %in% names(paths))

  # Test effects extraction
  effects <- coef(serial_data, type = "effects")
  expect_named(effects, c("indirect", "direct", "total"))

  # Verify indirect = a * d * b
  expect_equal(
    unname(effects["indirect"]),
    0.5 * 0.4 * 0.3
  )
})


test_that("vcov() works for SerialMediationData", {
  serial_data <- SerialMediationData(
    a_path = 0.5,
    d_path = 0.4,
    b_path = 0.3,
    c_prime = 0.1,
    estimates = c(a = 0.5, d = 0.4, b = 0.3, cp = 0.1),
    vcov = diag(4) * 0.01,
    sigma_mediators = c(1.0, 1.1),
    sigma_y = 1.2,
    treatment = "X",
    mediators = c("M1", "M2"),
    outcome = "Y",
    mediator_predictors = list(c("X"), c("X", "M1")),
    outcome_predictors = c("X", "M1", "M2"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "test"
  )

  v <- vcov(serial_data)
  expect_true(is.matrix(v))
  expect_equal(nrow(v), 4)
  expect_equal(ncol(v), 4)
})


test_that("nobs() works for SerialMediationData", {
  serial_data <- SerialMediationData(
    a_path = 0.5,
    d_path = 0.4,
    b_path = 0.3,
    c_prime = 0.1,
    estimates = c(a = 0.5, d = 0.4, b = 0.3, cp = 0.1),
    vcov = diag(4) * 0.01,
    sigma_mediators = c(1.0, 1.1),
    sigma_y = 1.2,
    treatment = "X",
    mediators = c("M1", "M2"),
    outcome = "Y",
    mediator_predictors = list(c("X"), c("X", "M1")),
    outcome_predictors = c("X", "M1", "M2"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "test"
  )

  expect_equal(nobs(serial_data), 100L)
})
