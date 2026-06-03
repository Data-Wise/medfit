# Tests for parallel mediation extraction via extract_mediation() on lavaan models
#
# Triggered by passing a character VECTOR (length >= 2) as `mediator` to a lavaan
# fit whose mediators are NOT regressed on one another. Detection routes through
# the internal parallel extractor and returns a ParallelMediationData object for
# X -> {M1, ..., Mk} -> Y, with total indirect effect sum_j a_j * b_j.
#
# Test categories:
# 1. Structure and return type (2 and 3 mediators)
# 2. Extraction fidelity vs lavaan's own coefficients
# 3. vcov aliases + FULL joint covariance (lm-vs-lavaan divergence: here
#    cov(a_j, b_j) != 0 because the SEM is estimated jointly)
# 4. Outcome auto-detection
# 5. structure = "auto" detection (parallel vs serial); explicit override
# 6. confint() effects brackets the true indirect effect
#
# Skipped entirely if lavaan is not installed.

skip_if_not_installed("lavaan")

# --- Test data generators (defined locally, matching sibling test files) ---

generate_parallel_mediation_data <- function(n = 300,
                                             a1 = 0.5, a2 = 0.4,
                                             b1 = 0.3, b2 = 0.45,
                                             c_prime = 0.1, seed = 123) {
  set.seed(seed)
  X  <- rnorm(n)
  M1 <- a1 * X + rnorm(n)
  M2 <- a2 * X + rnorm(n)
  Y  <- b1 * M1 + b2 * M2 + c_prime * X + rnorm(n)
  data.frame(X = X, M1 = M1, M2 = M2, Y = Y)
}

generate_parallel_mediation_data_3med <- function(n = 300, seed = 123) {
  set.seed(seed)
  X  <- rnorm(n)
  M1 <- 0.5 * X + rnorm(n)
  M2 <- 0.4 * X + rnorm(n)
  M3 <- 0.35 * X + rnorm(n)
  Y  <- 0.3 * M1 + 0.45 * M2 + 0.25 * M3 + 0.1 * X + rnorm(n)
  data.frame(X = X, M1 = M1, M2 = M2, M3 = M3, Y = Y)
}

# Two-mediator parallel lavaan model (mediators each on X only).
fit_parallel_2med <- function(data = generate_parallel_mediation_data()) {
  model <- "
    M1 ~ X
    M2 ~ X
    Y  ~ M1 + M2 + X
  "
  lavaan::sem(model, data = data)
}

# Three-mediator parallel lavaan model.
fit_parallel_3med <- function(data = generate_parallel_mediation_data_3med()) {
  model <- "
    M1 ~ X
    M2 ~ X
    M3 ~ X
    Y  ~ M1 + M2 + M3 + X
  "
  lavaan::sem(model, data = data)
}

# ==============================================================================
# Structure and return type
# ==============================================================================

test_that("vector mediator returns a ParallelMediationData object (2 mediators)", {
  skip_if_not_installed("lavaan")

  par <- extract_mediation_lavaan(
    fit_parallel_2med(),
    treatment = "X",
    mediator  = c("M1", "M2"),
    outcome   = "Y"
  )

  expect_s3_class(par, "medfit::ParallelMediationData")
  expect_equal(par@treatment, "X")
  expect_equal(par@mediators, c("M1", "M2"))
  expect_equal(par@outcome, "Y")

  # Parallel paths: a_paths / b_paths vectors of length k; c' scalar.
  expect_length(par@a_paths, 2)
  expect_length(par@b_paths, 2)
  expect_length(par@c_prime, 1)

  expect_type(par@mediator_predictors, "list")
  expect_length(par@mediator_predictors, 2)

  expect_length(par@sigma_mediators, 2)
  expect_length(par@sigma_y, 1)

  expect_true(par@converged)
  expect_equal(par@source_package, "lavaan")
})

test_that("three-mediator parallel model yields length-3 path vectors", {
  skip_if_not_installed("lavaan")

  par <- extract_mediation_lavaan(
    fit_parallel_3med(),
    treatment = "X",
    mediator  = c("M1", "M2", "M3"),
    outcome   = "Y"
  )

  expect_s3_class(par, "medfit::ParallelMediationData")
  expect_equal(par@mediators, c("M1", "M2", "M3"))
  expect_length(par@a_paths, 3)
  expect_length(par@b_paths, 3)
  expect_length(par@mediator_predictors, 3)
})

# ==============================================================================
# Extraction fidelity vs lavaan coefficients
# ==============================================================================

test_that("a/b/c' paths match lavaan parameter estimates", {
  skip_if_not_installed("lavaan")

  fit <- fit_parallel_2med()
  par <- extract_mediation_lavaan(
    fit, treatment = "X", mediator = c("M1", "M2"), outcome = "Y"
  )

  pe <- lavaan::parameterEstimates(fit)
  get <- function(lhs, rhs) {
    pe$est[pe$lhs == lhs & pe$op == "~" & pe$rhs == rhs][1]
  }

  expect_equal(par@a_paths[1], get("M1", "X"))
  expect_equal(par@a_paths[2], get("M2", "X"))
  expect_equal(par@b_paths[1], get("Y", "M1"))
  expect_equal(par@b_paths[2], get("Y", "M2"))
  expect_equal(par@c_prime, get("Y", "X"))
})

test_that("aliased estimates carry interleaved a1,b1,...,c_prime names", {
  skip_if_not_installed("lavaan")

  par <- extract_mediation_lavaan(
    fit_parallel_2med(), treatment = "X",
    mediator = c("M1", "M2"), outcome = "Y"
  )

  for (nm in c("a1", "b1", "a2", "b2", "c_prime")) {
    expect_true(nm %in% names(par@estimates), info = nm)
    expect_true(nm %in% rownames(par@vcov), info = nm)
  }
  expect_equal(unname(par@estimates["a1"]), par@a_paths[1])
  expect_equal(unname(par@estimates["b2"]), par@b_paths[2])
})

# ==============================================================================
# vcov: FULL joint covariance (lm-vs-lavaan divergence)
# ==============================================================================

test_that("single-SEM vcov preserves cross-path off-diagonals", {
  skip_if_not_installed("lavaan")

  par <- extract_mediation_lavaan(
    fit_parallel_2med(), treatment = "X",
    mediator = c("M1", "M2"), outcome = "Y"
  )
  vc <- par@vcov

  # b1, b2, c' share the single outcome equation -> non-zero covariances.
  expect_true(abs(vc["b1", "b2"]) > 0)
  expect_true(abs(vc["b1", "c_prime"]) > 0)

  # KEY lavaan divergence from lm: the whole system is estimated jointly, so
  # cov(a_j, b_j) need not be zero (it IS zero for the lm/glm engine).
  # We assert the alias block is well-formed and symmetric rather than hardcode
  # any cell to zero (which would be wrong for SEM).
  expect_equal(vc["a1", "b1"], vc["b1", "a1"])
  expect_true(is.finite(vc["a1", "b1"]))

  # Variances are positive.
  for (nm in c("a1", "a2", "b1", "b2", "c_prime")) {
    expect_true(vc[nm, nm] > 0, info = nm)
  }
})

# ==============================================================================
# Outcome auto-detection
# ==============================================================================

test_that("outcome is auto-detected when omitted", {
  skip_if_not_installed("lavaan")

  par <- extract_mediation_lavaan(
    fit_parallel_2med(), treatment = "X", mediator = c("M1", "M2")
  )
  expect_equal(par@outcome, "Y")
})

# ==============================================================================
# structure = "auto" detection and explicit override
# ==============================================================================

test_that("auto detection classifies a parallel SEM as parallel", {
  skip_if_not_installed("lavaan")

  par <- extract_mediation_lavaan(
    fit_parallel_2med(), treatment = "X",
    mediator = c("M1", "M2"), outcome = "Y", structure = "auto"
  )
  expect_s3_class(par, "medfit::ParallelMediationData")
})

test_that("auto detection classifies a serial SEM as serial", {
  skip_if_not_installed("lavaan")

  # Serial chain: M2 regressed on M1 -> chain edge -> serial.
  serial_model <- "
    M1 ~ X
    M2 ~ M1
    Y  ~ M2 + X
  "
  set.seed(7)
  X  <- rnorm(200)
  M1 <- 0.5 * X + rnorm(200)
  M2 <- 0.4 * M1 + rnorm(200)
  Y  <- 0.3 * M2 + 0.1 * X + rnorm(200)
  fit <- lavaan::sem(serial_model, data = data.frame(X, M1, M2, Y))

  res <- extract_mediation_lavaan(
    fit, treatment = "X", mediator = c("M1", "M2"), outcome = "Y",
    structure = "auto"
  )
  expect_s3_class(res, "medfit::SerialMediationData")
})

test_that("explicit structure overrides detection", {
  skip_if_not_installed("lavaan")

  par <- extract_mediation_lavaan(
    fit_parallel_2med(), treatment = "X",
    mediator = c("M1", "M2"), outcome = "Y", structure = "parallel"
  )
  expect_s3_class(par, "medfit::ParallelMediationData")
})

# ==============================================================================
# confint() effects brackets the true indirect effect
# ==============================================================================

test_that("confint effects brackets the simulated indirect effect", {
  skip_if_not_installed("lavaan")

  # True indirect effect is a1 times b1 plus a2 times b2 (0.33 here).
  true_nie <- 0.5 * 0.3 + 0.4 * 0.45

  par <- extract_mediation_lavaan(
    fit_parallel_2med(generate_parallel_mediation_data(n = 4000)),
    treatment = "X", mediator = c("M1", "M2"), outcome = "Y"
  )

  ci <- suppressWarnings(confint(par, parm = "effects"))
  # The indirect effect is the first effects row.
  expect_true(ci["indirect", 1] <= true_nie)
  expect_true(ci["indirect", 2] >= true_nie)
})
