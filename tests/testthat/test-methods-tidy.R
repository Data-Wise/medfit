# Tests for Tidyverse Methods (tidy, glance)

test_that("tidy.S7_object works for MediationData", {
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

  # Default: type = "all"
  tidy_all <- generics::tidy(result)
  expect_s3_class(tidy_all, "data.frame")
  expect_equal(nrow(tidy_all), 6)  # a, b, c_prime, nie, nde, te
  expect_true("term" %in% names(tidy_all))
  expect_true("estimate" %in% names(tidy_all))
})


test_that("tidy() type='paths' returns only path coefficients", {
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

  tidy_paths <- generics::tidy(result, type = "paths")
  expect_equal(nrow(tidy_paths), 3)  # a, b, c_prime
  expect_true(all(c("a", "b", "c_prime") %in% tidy_paths$term))
  expect_true("std.error" %in% names(tidy_paths))
})


test_that("tidy() type='effects' returns only mediation effects", {
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

  tidy_effects <- generics::tidy(result, type = "effects")
  expect_equal(nrow(tidy_effects), 3)  # nie, nde, te
  expect_true(all(c("nie", "nde", "te") %in% tidy_effects$term))
})


test_that("tidy() conf.int=TRUE adds confidence intervals", {
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

  tidy_ci <- generics::tidy(result, conf.int = TRUE)
  expect_true("conf.low" %in% names(tidy_ci))
  expect_true("conf.high" %in% names(tidy_ci))

  # CIs for paths should be numeric (not NA)
  paths_rows <- which(tidy_ci$term %in% c("a", "b", "c_prime"))
  expect_false(any(is.na(tidy_ci$conf.low[paths_rows])))
  expect_false(any(is.na(tidy_ci$conf.high[paths_rows])))
})


test_that("tidy() conf.level parameter works", {
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

  tidy_95 <- generics::tidy(result, type = "paths", conf.int = TRUE, conf.level = 0.95)
  tidy_90 <- generics::tidy(result, type = "paths", conf.int = TRUE, conf.level = 0.90)

  # 90% CI should be narrower than 95% CI
  width_95 <- tidy_95$conf.high[1] - tidy_95$conf.low[1]
  width_90 <- tidy_90$conf.high[1] - tidy_90$conf.low[1]
  expect_true(width_90 < width_95)
})


test_that("glance.S7_object works for MediationData", {
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

  glance_result <- generics::glance(result)
  expect_s3_class(glance_result, "data.frame")
  expect_equal(nrow(glance_result), 1)

  # Check expected columns
  expect_true(all(c("nie", "nde", "te", "pm", "nobs", "converged") %in%
                    names(glance_result)))

  expect_equal(glance_result$nobs, 100L)
  expect_true(glance_result$converged)
})


test_that("tidy.S7_object works for SerialMediationData", {
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

  # Default: type = "all"
  tidy_all <- generics::tidy(serial_data)
  expect_s3_class(tidy_all, "data.frame")
  expect_equal(nrow(tidy_all), 7)  # a, d, b, c_prime, nie, nde, te
  expect_true(all(c("a", "d", "b", "c_prime", "nie", "nde", "te") %in%
                    tidy_all$term))
})


test_that("tidy() for SerialMediationData with type='paths'", {
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

  tidy_paths <- generics::tidy(serial_data, type = "paths")
  expect_equal(nrow(tidy_paths), 4)  # a, d, b, c_prime
})


test_that("tidy() for SerialMediationData warns about conf.int", {
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

  expect_warning(
    generics::tidy(serial_data, conf.int = TRUE),
    "bootstrap"
  )
})


test_that("glance.S7_object works for SerialMediationData", {
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

  glance_result <- generics::glance(serial_data)
  expect_s3_class(glance_result, "data.frame")
  expect_equal(nrow(glance_result), 1)

  # Check expected columns including n_mediators
  expect_true(all(c("nie", "nde", "te", "pm", "n_mediators", "nobs", "converged") %in%
                    names(glance_result)))
  expect_equal(glance_result$n_mediators, 2L)
})


test_that("tidy.S7_object works for BootstrapResult", {
  boot_result <- BootstrapResult(
    estimate = 0.2,
    ci_lower = 0.1,
    ci_upper = 0.3,
    ci_level = 0.95,
    method = "parametric",
    n_boot = 1000L,
    boot_estimates = rnorm(1000, 0.2, 0.05)
  )

  tidy_boot <- generics::tidy(boot_result)
  expect_s3_class(tidy_boot, "data.frame")
  expect_equal(nrow(tidy_boot), 1)
  expect_true(all(c("term", "estimate", "std.error", "conf.low", "conf.high") %in%
                    names(tidy_boot)))

  expect_equal(tidy_boot$estimate, 0.2)
  expect_equal(tidy_boot$conf.low, 0.1)
  expect_equal(tidy_boot$conf.high, 0.3)
})


test_that("glance.S7_object works for BootstrapResult", {
  boot_result <- BootstrapResult(
    estimate = 0.2,
    ci_lower = 0.1,
    ci_upper = 0.3,
    ci_level = 0.95,
    method = "parametric",
    n_boot = 1000L,
    boot_estimates = rnorm(1000, 0.2, 0.05)
  )

  glance_boot <- generics::glance(boot_result)
  expect_s3_class(glance_boot, "data.frame")
  expect_equal(nrow(glance_boot), 1)
  expect_true(all(c("estimate", "ci_level", "method", "n_boot") %in%
                    names(glance_boot)))

  expect_equal(glance_boot$method, "parametric")
  expect_equal(glance_boot$n_boot, 1000L)
})


test_that("tidy.S7_object errors for unknown S7 object", {
  # Create a custom S7 class that isn't supported
  TestClass <- S7::new_class("TestClass", properties = list(x = class_numeric))
  test_obj <- TestClass(x = 1)

  expect_error(
    generics::tidy(test_obj),
    "not implemented"
  )
})


test_that("glance.S7_object errors for unknown S7 object", {
  TestClass <- S7::new_class("TestClass", properties = list(x = class_numeric))
  test_obj <- TestClass(x = 1)

  expect_error(
    generics::glance(test_obj),
    "not implemented"
  )
})


test_that("tidy() returns tibble when tibble package is available", {
  skip_if_not_installed("tibble")

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

  tidy_result <- generics::tidy(result)
  expect_s3_class(tidy_result, "tbl_df")
})


test_that("glance() returns tibble when tibble package is available", {
  skip_if_not_installed("tibble")

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

  glance_result <- generics::glance(result)
  expect_s3_class(glance_result, "tbl_df")
})


test_that("tidy() estimates match effect extractors", {
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

  tidy_result <- generics::tidy(result)

  # Check that tidy estimates match extractor functions
  nie_row <- which(tidy_result$term == "nie")
  nde_row <- which(tidy_result$term == "nde")
  te_row <- which(tidy_result$term == "te")

  expect_equal(tidy_result$estimate[nie_row], as.numeric(nie(result)))
  expect_equal(tidy_result$estimate[nde_row], as.numeric(nde(result)))
  expect_equal(tidy_result$estimate[te_row], as.numeric(te(result)))
})


test_that("glance() values match effect extractors", {
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

  glance_result <- generics::glance(result)

  expect_equal(glance_result$nie, as.numeric(nie(result)))
  expect_equal(glance_result$nde, as.numeric(nde(result)))
  expect_equal(glance_result$te, as.numeric(te(result)))
  expect_equal(glance_result$pm, as.numeric(pm(result)))
  expect_equal(glance_result$nobs, nobs(result))
})
