# Tests for Effect Extractor Generics

test_that("nie() extracts natural indirect effect", {
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

  result <- nie(med_data)

  # Should return numeric
  expect_true(is.numeric(result))
  expect_length(result, 1)

  # Should equal a * b
  expect_equal(as.numeric(result), med_data@a_path * med_data@b_path)

  # Should have mediation_effect class
  expect_s3_class(result, "mediation_effect")

  # Should have type attribute
  expect_equal(attr(result, "type"), "nie")
})


test_that("nde() extracts natural direct effect", {
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

  result <- nde(med_data)

  # Should return numeric
  expect_true(is.numeric(result))
  expect_length(result, 1)

  # Should equal c_prime
  expect_equal(as.numeric(result), med_data@c_prime)

  # Should have mediation_effect class
  expect_s3_class(result, "mediation_effect")

  # Should have type attribute
  expect_equal(attr(result, "type"), "nde")
})


test_that("te() extracts total effect", {
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

  result <- te(med_data)

  # Should return numeric
  expect_true(is.numeric(result))
  expect_length(result, 1)

  # TE = NIE + NDE
  expected_te <- as.numeric(nie(med_data)) + as.numeric(nde(med_data))
  expect_equal(as.numeric(result), expected_te)

  # Should have type attribute
  expect_equal(attr(result, "type"), "te")
})


test_that("pm() extracts proportion mediated", {
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

  result <- pm(med_data)

  # Should return numeric
  expect_true(is.numeric(result))
  expect_length(result, 1)

  # PM = NIE / TE
  expected_pm <- as.numeric(nie(med_data)) / as.numeric(te(med_data))
  expect_equal(as.numeric(result), expected_pm)

  # Should have type attribute
  expect_equal(attr(result, "type"), "pm")

  # In this example, should be between 0 and 1
  expect_true(result > 0 && result < 1)
})


test_that("pm() warns when total effect is zero", {
  # Create a MediationData object where TE ≈ 0
  med_data <- MediationData(
    a_path = 0.5,
    b_path = 0.4,
    c_prime = -0.2,  # c' = -a*b so TE ≈ 0
    estimates = c(a = 0.5, b = 0.4, cp = -0.2),
    vcov = diag(3) * 0.01,
    sigma_m = 1.0,
    sigma_y = 1.0,
    treatment = "X",
    mediator = "M",
    outcome = "Y",
    mediator_predictors = "X",
    outcome_predictors = c("X", "M"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "test"
  )

  expect_warning(
    result <- pm(med_data),
    "Total effect is approximately zero"
  )
  expect_true(is.na(result))
})


test_that("paths() extracts all path coefficients", {
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

  result <- paths(med_data)

  # Should return named vector
  expect_named(result, c("a", "b", "c_prime"))
  expect_length(result, 3)

  # Values should match object properties
  expect_equal(unname(result["a"]), med_data@a_path)
  expect_equal(unname(result["b"]), med_data@b_path)
  expect_equal(unname(result["c_prime"]), med_data@c_prime)
})


test_that("effect extractors work for SerialMediationData", {
  # Create a SerialMediationData object
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

  # NIE = a * d * b
  expected_nie <- 0.5 * 0.4 * 0.3
  expect_equal(as.numeric(nie(serial_data)), expected_nie)

  # NDE = c_prime
  expect_equal(as.numeric(nde(serial_data)), 0.1)

  # TE = NIE + NDE
  expected_te <- expected_nie + 0.1
  expect_equal(as.numeric(te(serial_data)), expected_te)

  # PM = NIE / TE
  expected_pm <- expected_nie / expected_te
  expect_equal(as.numeric(pm(serial_data)), expected_pm)

  # paths should include d
  p <- paths(serial_data)
  expect_true("a" %in% names(p))
  expect_true("d" %in% names(p))
  expect_true("b" %in% names(p))
  expect_true("c_prime" %in% names(p))
})


test_that("SerialMediationData paths() handles multiple mediators", {
  # 3 mediators -> d21, d32
  serial_data <- SerialMediationData(
    a_path = 0.5,
    d_path = c(0.4, 0.35),
    b_path = 0.3,
    c_prime = 0.1,
    estimates = c(a = 0.5, d21 = 0.4, d32 = 0.35, b = 0.3, cp = 0.1),
    vcov = diag(5) * 0.01,
    sigma_mediators = c(1.0, 1.1, 1.05),
    sigma_y = 1.2,
    treatment = "X",
    mediators = c("M1", "M2", "M3"),
    outcome = "Y",
    mediator_predictors = list(
      c("X"),
      c("X", "M1"),
      c("X", "M1", "M2")
    ),
    outcome_predictors = c("X", "M1", "M2", "M3"),
    data = NULL,
    n_obs = 100L,
    converged = TRUE,
    source_package = "test"
  )

  p <- paths(serial_data)

  # Should have d21 and d32
  expect_true("d21" %in% names(p))
  expect_true("d32" %in% names(p))

  # NIE = a * d21 * d32 * b
  expected_nie <- 0.5 * 0.4 * 0.35 * 0.3
  expect_equal(as.numeric(nie(serial_data)), expected_nie)
})


test_that("print.mediation_effect formats output correctly", {
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

  # Capture printed output
  output <- capture.output(print(nie(med_data)))
  expect_true(grepl("Natural Indirect Effect", output[1]))

  output <- capture.output(print(nde(med_data)))
  expect_true(grepl("Natural Direct Effect", output[1]))

  output <- capture.output(print(pm(med_data)))
  expect_true(grepl("Proportion Mediated", output[1]))
})
