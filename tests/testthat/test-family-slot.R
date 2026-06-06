# Tests for the family_m / family_y slots on MediationData
#
# These ensure the extractors carry the GLM family/link forward so downstream
# scale-free estimands (e.g. probmed::pmed) can simulate non-Gaussian potential
# outcomes on the correct scale.

# --- Test Data Generators ---

gen_gaussian <- function(n = 200, a = 0.5, b = 0.3, c_prime = 0.2, seed = 123) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  Y <- b * M + c_prime * X + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}

gen_binary_outcome <- function(n = 400, a = 0.5, b = 0.8, c_prime = 0.3, seed = 42) {
  set.seed(seed)
  X <- rnorm(n)
  M <- a * X + rnorm(n)
  eta <- b * M + c_prime * X
  Y <- rbinom(n, 1, plogis(eta))
  data.frame(X = X, M = M, Y = Y)
}

# ==============================================================================
# Family is populated from lm / glm fits
# ==============================================================================

test_that("lm extraction records Gaussian families on identity link", {
  data <- gen_gaussian()
  fit_m <- lm(M ~ X, data = data)
  fit_y <- lm(Y ~ X + M, data = data)

  md <- extract_mediation(fit_m, model_y = fit_y, treatment = "X", mediator = "M", outcome = "Y")

  expect_s3_class(md@family_m, "family")
  expect_s3_class(md@family_y, "family")
  expect_identical(md@family_m$family, "gaussian")
  expect_identical(md@family_y$family, "gaussian")
  expect_identical(md@family_y$link, "identity")
})

test_that("glm extraction records the binomial outcome family and link", {
  data <- gen_binary_outcome()
  fit_m <- glm(M ~ X, data = data)                       # gaussian mediator
  fit_y <- glm(Y ~ X + M, data = data, family = binomial())

  md <- extract_mediation(fit_m, model_y = fit_y, treatment = "X", mediator = "M", outcome = "Y")

  expect_identical(md@family_m$family, "gaussian")
  expect_identical(md@family_y$family, "binomial")
  expect_identical(md@family_y$link, "logit")
})

# ==============================================================================
# Backward compatibility + validation
# ==============================================================================

test_that("MediationData constructs without families (defaults to gaussian)", {
  md <- MediationData(
    a_path = 0.5, b_path = 0.3, c_prime = 0.2,
    estimates = c(0.5, 0.3, 0.2), vcov = diag(3) * 0.01,
    sigma_m = 1.0, sigma_y = 1.2,
    treatment = "X", mediator = "M", outcome = "Y",
    mediator_predictors = "X", outcome_predictors = c("X", "M"),
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "stats"
  )
  expect_identical(md@family_m$family, "gaussian")
  expect_identical(md@family_y$family, "gaussian")
})

test_that("MediationData accepts an explicit NULL family", {
  md <- MediationData(
    a_path = 0.5, b_path = 0.3, c_prime = 0.2,
    estimates = c(0.5, 0.3, 0.2), vcov = diag(3) * 0.01,
    sigma_m = 1.0, sigma_y = 1.2,
    treatment = "X", mediator = "M", outcome = "Y",
    mediator_predictors = "X", outcome_predictors = c("X", "M"),
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "stats",
    family_y = NULL
  )
  expect_null(md@family_y)
})

test_that("a non-family object is rejected", {
  # S7's property type system rejects this at assignment (before the validator),
  # so we only assert that construction errors.
  expect_error(
    MediationData(
      a_path = 0.5, b_path = 0.3, c_prime = 0.2,
      estimates = c(0.5, 0.3, 0.2), vcov = diag(3) * 0.01,
      treatment = "X", mediator = "M", outcome = "Y",
      mediator_predictors = "X", outcome_predictors = c("X", "M"),
      n_obs = 100L, converged = TRUE, source_package = "stats",
      family_y = "binomial"
    )
  )
})
