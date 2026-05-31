# Tests for serial mediation extraction via extract_mediation() on lavaan models
#
# Triggered by passing a character VECTOR (length >= 2) as `mediator`, which
# routes through .extract_serial_mediation_lavaan() and returns a
# SerialMediationData object (X -> M1 -> M2 -> ... -> Mk -> Y).
#
# Test categories:
# 1. Structure and return type (2 and 3 mediators)
# 2. Point estimates recover the data-generating paths
# 3. vcov aliases + off-diagonal covariance preservation
# 4. Outcome auto-detection
# 5. Overload safety: scalar mediator still yields MediationData
#
# Skipped entirely if lavaan is not installed.

skip_if_not_installed("lavaan")

# Two-mediator serial lavaan model (unlabeled -> extracted by variable name).
fit_serial_2med <- function(data = generate_serial_mediation_data()) {
  model <- "
    M1 ~ X
    M2 ~ M1
    Y  ~ M2 + X
  "
  lavaan::sem(model, data = data)
}

# Three-mediator serial lavaan model.
fit_serial_3med <- function(data = generate_serial_mediation_data_3med()) {
  model <- "
    M1 ~ X
    M2 ~ M1
    M3 ~ M2
    Y  ~ M3 + X
  "
  lavaan::sem(model, data = data)
}

# ==============================================================================
# Structure and return type
# ==============================================================================

test_that("vector mediator returns a SerialMediationData object (2 mediators)", {
  skip_if_not_installed("lavaan")

  serial <- extract_mediation_lavaan(
    fit_serial_2med(),
    treatment = "X",
    mediator  = c("M1", "M2"),
    outcome   = "Y"
  )

  expect_s3_class(serial, "medfit::SerialMediationData")
  expect_equal(serial@treatment, "X")
  expect_equal(serial@mediators, c("M1", "M2"))
  expect_equal(serial@outcome, "Y")

  # Path arities: a/b/c' scalar, d vector of length k - 1 = 1
  expect_length(serial@a_path, 1)
  expect_length(serial@b_path, 1)
  expect_length(serial@c_prime, 1)
  expect_length(serial@d_path, 1)

  # mediator_predictors is a list, one entry per mediator
  expect_type(serial@mediator_predictors, "list")
  expect_length(serial@mediator_predictors, 2)

  # Residual SDs: one per mediator, scalar for outcome
  expect_length(serial@sigma_mediators, 2)
  expect_length(serial@sigma_y, 1)

  expect_true(serial@converged)
  expect_equal(serial@source_package, "lavaan")
})

test_that("three-mediator chain yields d_path of length 2", {
  skip_if_not_installed("lavaan")

  serial <- extract_mediation_lavaan(
    fit_serial_3med(),
    treatment = "X",
    mediator  = c("M1", "M2", "M3"),
    outcome   = "Y"
  )

  expect_s3_class(serial, "medfit::SerialMediationData")
  expect_equal(serial@mediators, c("M1", "M2", "M3"))
  expect_length(serial@d_path, 2)       # M1->M2, M2->M3
  expect_length(serial@mediator_predictors, 3)
  expect_length(serial@sigma_mediators, 3)
})

# ==============================================================================
# Point estimates recover the data-generating paths
# ==============================================================================

test_that("extracted paths faithfully reproduce lavaan's coefficients", {
  skip_if_not_installed("lavaan")

  # Extraction fidelity: the paths must EXACTLY match what lavaan estimated
  # (this is the extractor's contract -- not whether lavaan recovers the DGP,
  # which is a separate statistical question subject to sampling error).
  data <- generate_serial_mediation_data(n = 5000, a = 0.5, d = 0.4,
                                          b = 0.3, c_prime = 0.1, seed = 7)
  fit <- fit_serial_2med(data)
  serial <- extract_mediation_lavaan(
    fit,
    treatment = "X",
    mediator  = c("M1", "M2"),
    outcome   = "Y"
  )

  pe <- lavaan::parameterEstimates(fit)
  get <- function(lhs, rhs) {
    pe$est[pe$lhs == lhs & pe$op == "~" & pe$rhs == rhs][1]
  }

  expect_equal(serial@a_path,      get("M1", "X"))
  expect_equal(serial@d_path[[1]], get("M2", "M1"))
  expect_equal(serial@b_path,      get("Y", "M2"))
  expect_equal(serial@c_prime,     get("Y", "X"))

  # Sanity: the estimates are at least in the neighbourhood of the truth.
  expect_equal(serial@a_path, 0.5, tolerance = 0.1)
  expect_equal(serial@d_path[[1]], 0.4, tolerance = 0.1)
})

# ==============================================================================
# vcov aliases + off-diagonal covariance preservation
# ==============================================================================

test_that("vcov exposes named structural aliases and matches estimates", {
  skip_if_not_installed("lavaan")

  serial <- extract_mediation_lavaan(
    fit_serial_2med(),
    treatment = "X",
    mediator  = c("M1", "M2"),
    outcome   = "Y"
  )

  # Square, symmetric, and conformable with estimates.
  expect_equal(nrow(serial@vcov), ncol(serial@vcov))
  expect_equal(length(serial@estimates), nrow(serial@vcov))
  expect_equal(serial@vcov, t(serial@vcov))

  # Structural aliases are present and addressable by name.
  alias_names <- c("a", "d1", "b", "c_prime")
  expect_true(all(alias_names %in% rownames(serial@vcov)))
  expect_true(all(alias_names %in% names(serial@estimates)))

  # The alias estimates equal the structural path properties.
  expect_equal(unname(serial@estimates[["a"]]),  serial@a_path)
  expect_equal(unname(serial@estimates[["d1"]]), serial@d_path[[1]])
  expect_equal(unname(serial@estimates[["b"]]),  serial@b_path)

  # Off-diagonal covariance among chain paths is preserved (a finite, symmetric
  # submatrix) -- this is what serial indirect-effect SEs depend on.
  sub <- serial@vcov[c("a", "d1", "b"), c("a", "d1", "b")]
  expect_true(all(is.finite(sub)))
  expect_equal(sub["a", "d1"], sub["d1", "a"])
  expect_true(all(diag(sub) > 0))   # variances are positive
})

# ==============================================================================
# Outcome auto-detection
# ==============================================================================

test_that("outcome is auto-detected from the last mediator when NULL", {
  skip_if_not_installed("lavaan")

  serial <- extract_mediation_lavaan(
    fit_serial_2med(),
    treatment = "X",
    mediator  = c("M1", "M2")
    # outcome omitted -> auto-detected from `Y ~ M2`
  )

  expect_equal(serial@outcome, "Y")
})

# ==============================================================================
# Overload safety: scalar mediator path is unchanged
# ==============================================================================

test_that("scalar mediator still returns a MediationData object", {
  skip_if_not_installed("lavaan")

  data <- generate_mediation_data()
  fit  <- lavaan::sem("M ~ a*X\n Y ~ b*M + cp*X", data = data)

  med <- extract_mediation_lavaan(fit, treatment = "X", mediator = "M")
  expect_s3_class(med, "medfit::MediationData")
})

# ==============================================================================
# Input validation
# ==============================================================================

test_that("a missing required path raises an informative error", {
  skip_if_not_installed("lavaan")

  # Model omits the M2 ~ M1 (d) path, breaking the serial chain.
  data <- generate_serial_mediation_data()
  fit  <- lavaan::sem("M1 ~ X\n M2 ~ X\n Y ~ M2 + X", data = data)

  expect_error(
    extract_mediation_lavaan(fit, treatment = "X",
                             mediator = c("M1", "M2"), outcome = "Y"),
    "d path"
  )
})
