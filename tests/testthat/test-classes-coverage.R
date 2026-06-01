# Coverage-focused tests for classes.R (testthat 3e).
#
# Complements test-classes.R by exercising the summary-print and show methods
# (and their optional-field branches), which the existing tests construct but
# do not print, plus remaining validator error branches. These are the lines
# covr flagged as uncovered in classes.R.

# --- Builders for valid objects -------------------------------------------

make_med <- function(sigma_m = 1.0, sigma_y = 1.2, converged = TRUE,
                     data = NULL, n_obs = 100L) {
  MediationData(
    a_path = 0.5, b_path = 0.3, c_prime = 0.2,
    estimates = c(a = 0.5, b = 0.3, c_prime = 0.2),
    vcov = diag(3) * 0.01,
    sigma_m = sigma_m, sigma_y = sigma_y,
    treatment = "X", mediator = "M", outcome = "Y",
    mediator_predictors = c("X"), outcome_predictors = c("X", "M"),
    data = data, n_obs = n_obs, converged = converged, source_package = "stats"
  )
}

make_boot <- function(method = "parametric") {
  if (method == "plugin") {
    BootstrapResult(
      estimate = 0.15, ci_lower = NA_real_, ci_upper = NA_real_,
      ci_level = NA_real_, boot_estimates = numeric(0),
      n_boot = 0L, method = "plugin", call = NULL
    )
  } else {
    BootstrapResult(
      estimate = 0.15, ci_lower = 0.10, ci_upper = 0.20, ci_level = 0.95,
      boot_estimates = stats::rnorm(500, 0.15, 0.02),
      n_boot = 500L, method = method, call = NULL
    )
  }
}

make_serial <- function(n_med = 2) {
  if (n_med == 2) {
    SerialMediationData(
      a_path = 0.5, d_path = 0.4, b_path = 0.3, c_prime = 0.1,
      estimates = c(0.5, 0.4, 0.3, 0.1), vcov = diag(4) * 0.01,
      sigma_mediators = c(1.0, 1.1), sigma_y = 1.2,
      treatment = "X", mediators = c("M1", "M2"), outcome = "Y",
      mediator_predictors = list("X", c("X", "M1")),
      outcome_predictors = c("X", "M1", "M2"),
      data = NULL, n_obs = 100L, converged = TRUE, source_package = "lavaan"
    )
  } else {
    SerialMediationData(
      a_path = 0.5, d_path = c(0.4, 0.35), b_path = 0.3, c_prime = 0.1,
      estimates = c(0.5, 0.4, 0.35, 0.3, 0.1), vcov = diag(5) * 0.01,
      sigma_mediators = c(1.0, 1.1, 1.05), sigma_y = 1.2,
      treatment = "X", mediators = c("M1", "M2", "M3"), outcome = "Y",
      mediator_predictors = list("X", c("X", "M1"), c("X", "M1", "M2")),
      outcome_predictors = c("X", "M1", "M2", "M3"),
      data = NULL, n_obs = 100L, converged = TRUE, source_package = "lavaan"
    )
  }
}

# ==============================================================================
# MediationData: summary -> print.summary, and show
# ==============================================================================

test_that("print.summary.MediationData prints all sections incl. residual SDs", {
  out <- capture.output(print(summary(make_med())))
  expect_true(any(grepl("Summary of MediationData", out)))
  expect_true(any(grepl("Residual Standard Deviations", out)))
  expect_true(any(grepl("Mediator model", out)))
  expect_true(any(grepl("Outcome model", out)))
  expect_true(any(grepl("Variance-Covariance", out)))
})

test_that("print.summary.MediationData omits residual SDs when both are NULL", {
  out <- capture.output(print(summary(make_med(sigma_m = NULL, sigma_y = NULL))))
  expect_false(any(grepl("Residual Standard Deviations", out)))
})

test_that("print.summary.MediationData reports non-convergence", {
  out <- capture.output(print(summary(make_med(converged = FALSE))))
  expect_true(any(grepl("Converged:\\s*No", out)))
})

test_that("show(MediationData) prints the object", {
  expect_output(show(make_med()), "MediationData")
})

# ==============================================================================
# BootstrapResult: summary -> print.summary (parametric vs plugin), and show
# ==============================================================================

test_that("print.summary.BootstrapResult prints CI + distribution for parametric", {
  out <- capture.output(print(summary(make_boot("parametric"))))
  expect_true(any(grepl("Summary of BootstrapResult", out)))
  expect_true(any(grepl("Confidence Interval", out)))
  expect_true(any(grepl("Bootstrap Distribution", out)))
})

test_that("print.summary.BootstrapResult omits CI for the plugin method", {
  out <- capture.output(print(summary(make_boot("plugin"))))
  expect_false(any(grepl("Confidence Interval", out)))
})

test_that("show(BootstrapResult) prints the object", {
  expect_output(show(make_boot("parametric")), "BootstrapResult")
})

# ==============================================================================
# SerialMediationData: summary -> print.summary (2 and 3 mediators)
# ==============================================================================

test_that("print.summary.SerialMediationData prints for a 2-mediator chain", {
  out <- capture.output(print(summary(make_serial(2))))
  expect_true(length(out) > 0)
  expect_true(any(grepl("Serial", out)))
})

test_that("print.summary.SerialMediationData prints for a 3-mediator chain", {
  out <- capture.output(print(summary(make_serial(3))))
  expect_true(length(out) > 0)
  expect_true(any(grepl("Serial", out)))
})
