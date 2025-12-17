# Tests for med() and quick() ADHD-Friendly Entry Points

test_that("med() fits basic mediation model", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  result <- med(
    data = mydata,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  expect_s3_class(result, "medfit::MediationData")
  expect_equal(result@treatment, "X")
  expect_equal(result@mediator, "M")
  expect_equal(result@outcome, "Y")
  expect_equal(nobs(result), 100L)
})


test_that("med() works with covariates", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(
    X = rnorm(n),
    C1 = rnorm(n),
    C2 = rnorm(n)
  )
  mydata$M <- 0.5 * mydata$X + 0.2 * mydata$C1 + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + 0.1 * mydata$C2 + rnorm(n)

  result <- med(
    data = mydata,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    covariates = c("C1", "C2")
  )

  expect_s3_class(result, "medfit::MediationData")

  # Should have covariates in predictors
  expect_true("C1" %in% result@mediator_predictors)
  expect_true("C2" %in% result@outcome_predictors)
})


test_that("med() validates inputs", {
  mydata <- data.frame(X = 1:10, M = 1:10, Y = 1:10)

  # Missing variable
  expect_error(
    med(data = mydata, treatment = "A", mediator = "M", outcome = "Y"),
    "treatment"
  )

  # Invalid covariate
  expect_error(
    med(data = mydata, treatment = "X", mediator = "M", outcome = "Y",
        covariates = "MISSING"),
    "covariates"
  )
})


test_that("med() with boot=TRUE adds bootstrap result", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  result <- med(
    data = mydata,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    boot = TRUE,
    n_boot = 100,
    seed = 42
  )

  # Should have bootstrap attribute
  boot_result <- attr(result, "bootstrap")
  expect_true(!is.null(boot_result))
  expect_s3_class(boot_result, "medfit::BootstrapResult")

  # Bootstrap should have CI
  expect_false(is.na(boot_result@ci_lower))
  expect_false(is.na(boot_result@ci_upper))
})


test_that("quick() produces output for MediationData", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  result <- med(
    data = mydata,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  # Capture output
  output <- capture.output(quick(result))

  # Should contain key elements
  expect_true(grepl("NIE", output[1]))
  expect_true(grepl("NDE", output[1]))
  expect_true(grepl("PM", output[1]))
  expect_true(grepl("%", output[1]))
})


test_that("quick() shows CI when bootstrap is available", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  result <- med(
    data = mydata,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    boot = TRUE,
    n_boot = 100,
    seed = 42
  )

  # Capture output
  output <- capture.output(quick(result))

  # Should contain CI brackets
  expect_true(grepl("\\[", output[1]))
  expect_true(grepl("\\]", output[1]))
})


test_that("quick() errors for non-MediationData objects", {
  expect_error(
    quick(list(a = 1)),
    "requires a MediationData"
  )

  expect_error(
    quick(1:10),
    "requires a MediationData"
  )
})


test_that("quick() works for SerialMediationData", {
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

  output <- capture.output(quick(serial_data))

  # Should mention mediators
  expect_true(grepl("mediators", output[1]))
  expect_true(grepl("NIE", output[1]))
})


test_that("quick() returns invisibly", {
  set.seed(123)
  n <- 100
  mydata <- data.frame(X = rnorm(n))
  mydata$M <- 0.5 * mydata$X + rnorm(n)
  mydata$Y <- 0.3 * mydata$X + 0.4 * mydata$M + rnorm(n)

  result <- med(
    data = mydata,
    treatment = "X",
    mediator = "M",
    outcome = "Y"
  )

  # Capture return value
  invisible_result <- capture.output(returned <- quick(result))

  # Should return the original object
  expect_identical(returned, result)
})
