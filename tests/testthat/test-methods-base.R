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

  # the ninety percent interval should be narrower than the ninety-five percent interval
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


test_that("confint() errors for bootstrap method", {
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


# ==============================================================================
# coef() / confint() for BootstrapResult
# ==============================================================================

boot_fixture <- function(method = "parametric") {
  set.seed(42)
  X <- rnorm(200)
  M <- 0.5 * X + rnorm(200)
  Y <- 0.3 * M + 0.2 * X + rnorm(200)
  d <- data.frame(X, M, Y)
  med <- extract_mediation(lm(M ~ X, d), model_y = lm(Y ~ X + M, d),
                           treatment = "X", mediator = "M")
  if (method == "nonparametric") {
    return(bootstrap_mediation(
      function(bd) {
        unname(coef(lm(M ~ X, bd))["X"] * coef(lm(Y ~ X + M, bd))["M"])
      },
      method = "nonparametric", data = d, n_boot = 200, seed = 1
    ))
  }
  bootstrap_mediation(function(t) unname(t["a"] * t["b"]), method = method,
                      mediation_data = med, n_boot = 500, seed = 1)
}

test_that("coef() on BootstrapResult returns the named point estimate", {
  r <- boot_fixture()
  expect_identical(coef(r), c(estimate = unname(r@estimate)))
})

test_that("coef() on BootstrapResult keeps the term name for a named statistic", {
  med <- extract_mediation(
    lm(mediator1 ~ treatment, data = mediation_demo),
    model_y = lm(outcome ~ treatment + mediator1, data = mediation_demo),
    treatment = "treatment", mediator = "mediator1"
  )
  # No unname(): the product carries the name "a"
  r <- bootstrap_mediation(function(t) t["a"] * t["b"], method = "plugin",
                           mediation_data = med)
  expect_named(coef(r), "estimate")
  expect_equal(unname(coef(r)), unname(r@estimate))
})

test_that("confint() on BootstrapResult returns the stored interval by default", {
  r <- boot_fixture("nonparametric")
  ci <- confint(r)
  expect_true(is.matrix(ci))
  expect_identical(dim(ci), c(1L, 2L))
  expect_identical(rownames(ci), "estimate")
  expect_identical(colnames(ci), c("2.5 %", "97.5 %"))
  expect_identical(unname(ci[1, ]), c(r@ci_lower, r@ci_upper))
  # Supplying the stored level explicitly is the same as the default
  expect_identical(confint(r, level = 0.95), ci)
})

test_that("confint() on BootstrapResult recomputes a different level", {
  r <- boot_fixture()
  ci90 <- confint(r, level = 0.90)
  expect_identical(colnames(ci90), c("5 %", "95 %"))
  expect_equal(unname(ci90[1, ]),
               stats::quantile(r@boot_estimates, c(0.05, 0.95), names = FALSE))
  expect_gt(ci90[1, 1], r@ci_lower)
  expect_lt(ci90[1, 2], r@ci_upper)
})

test_that("confint() on a plugin BootstrapResult warns and returns NA", {
  r <- boot_fixture("plugin")
  expect_warning(ci <- confint(r), "no bootstrap distribution")
  expect_true(all(is.na(ci)))
  expect_identical(colnames(ci), c("2.5 %", "97.5 %"))
})

test_that("confint() on BootstrapResult validates its arguments", {
  r <- boot_fixture()
  expect_error(confint(r, parm = "a"), "parm")
  expect_error(confint(r, level = 2), "level")
})
