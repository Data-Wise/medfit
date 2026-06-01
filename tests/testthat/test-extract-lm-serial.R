# Tests for serial mediation extraction via extract_mediation() on lm/glm models
#
# Triggered by passing a character VECTOR (length >= 2) as `mediator` together
# with `mediator_models` (the M2..Mk regressions), which routes through the
# internal serial worker and returns a SerialMediationData object for a chain
# running from the treatment through ordered mediators to the outcome.
#
# Test categories:
# 1. Structure and return type (2 and 3 mediators)
# 2. Extraction fidelity vs the models' own coef()
# 3. vcov contract: block-diagonal across equations + cov(b, c_prime) preserved
# 4. glm engines (link-scale paths, per-mediator NA sigma)
# 5. Order cross-check errors (one test per failure mode)
# 6. Covariate tolerance (d_i read regardless of extra covariates)

# --- Test data generators (local, matching sibling test files) ---

generate_serial_lm_data <- function(n = 300, seed = 123) {
  set.seed(seed)
  X  <- rnorm(n)
  M1 <- 0.5 * X  + rnorm(n)
  M2 <- 0.4 * M1 + rnorm(n)
  Y  <- 0.3 * M2 + 0.2 * X + rnorm(n)
  data.frame(X = X, M1 = M1, M2 = M2, Y = Y)
}

generate_serial_lm_data_3med <- function(n = 400, seed = 456) {
  set.seed(seed)
  X  <- rnorm(n)
  M1 <- 0.5 * X   + rnorm(n)
  M2 <- 0.4 * M1  + rnorm(n)
  M3 <- 0.35 * M2 + rnorm(n)
  Y  <- 0.3 * M3 + 0.2 * X + rnorm(n)
  data.frame(X = X, M1 = M1, M2 = M2, M3 = M3, Y = Y)
}


# ==============================================================================
# Structure and return type
# ==============================================================================

test_that("serial lm extraction returns SerialMediationData (2 mediators)", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(f2)
  )

  expect_s3_class(sm, "medfit::SerialMediationData")
  expect_equal(sm@mediators, c("M1", "M2"))
  expect_equal(sm@outcome, "Y")
  expect_equal(length(sm@d_path), 1L)
})

test_that("serial lm extraction handles a 3-mediator chain", {
  d <- generate_serial_lm_data_3med()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  f3 <- lm(M3 ~ M2, data = d)
  fy <- lm(Y ~ M3 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2", "M3"),
    mediator_models = list(f2, f3)
  )

  expect_s3_class(sm, "medfit::SerialMediationData")
  expect_equal(length(sm@d_path), 2L)
  expect_true(all(c("d1", "d2") %in% names(sm@estimates)))
})


# ==============================================================================
# Extraction fidelity vs coef()
# ==============================================================================

test_that("serial paths equal the source-model coefficients", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(f2)
  )

  expect_equal(sm@a_path, unname(coef(f1)["X"]))
  expect_equal(sm@d_path, unname(coef(f2)["M1"]))
  expect_equal(sm@b_path, unname(coef(fy)["M2"]))
  expect_equal(sm@c_prime, unname(coef(fy)["X"]))

  # Aliases in @estimates mirror the path scalars.
  expect_equal(unname(sm@estimates["a"]), sm@a_path)
  expect_equal(unname(sm@estimates["d1"]), sm@d_path)
  expect_equal(unname(sm@estimates["b"]), sm@b_path)
  expect_equal(unname(sm@estimates["c_prime"]), sm@c_prime)
})


# ==============================================================================
# vcov contract: block-diagonal across equations + cov(b, c_prime) preserved
# ==============================================================================

test_that("serial vcov is named, square, symmetric, and dim-matched", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(f2)
  )
  v <- sm@vcov

  expect_equal(nrow(v), ncol(v))
  expect_equal(nrow(v), length(sm@estimates))
  expect_equal(rownames(v), names(sm@estimates))
  expect_equal(v, t(v))
  expect_true(all(c("a", "d1", "b", "c_prime") %in% rownames(v)))
})

test_that("serial vcov is block-diagonal across chain paths", {
  d <- generate_serial_lm_data_3med()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  f3 <- lm(M3 ~ M2, data = d)
  fy <- lm(Y ~ M3 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2", "M3"),
    mediator_models = list(f2, f3)
  )
  v <- sm@vcov

  # Chain paths come from separate regressions -> independent by construction.
  expect_equal(v["a", "d1"], 0)
  expect_equal(v["a", "d2"], 0)
  expect_equal(v["d1", "d2"], 0)
  expect_equal(v["d1", "b"], 0)
  expect_equal(v["d2", "b"], 0)
  expect_equal(v["a", "b"], 0)
})

test_that("serial vcov preserves cov(b, c_prime) from the outcome equation", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(f2)
  )

  # b and c_prime are both from the outcome equation: covariance must survive.
  expect_equal(sm@vcov["b", "c_prime"], unname(vcov(fy)["M2", "X"]))
  expect_true(abs(sm@vcov["b", "c_prime"]) > 0)

  # The full alias block reproduces the outcome-model source block.
  alias_block <- sm@vcov[c("b", "c_prime"), c("b", "c_prime")]
  source_block <- vcov(fy)[c("M2", "X"), c("M2", "X")]
  expect_equal(unname(alias_block), unname(source_block))
})


# ==============================================================================
# glm engines
# ==============================================================================

test_that("serial extraction works with a glm mediator (NA sigma, link scale)", {
  set.seed(789)
  n <- 600
  X <- rnorm(n)
  M1 <- 0.5 * X + rnorm(n)
  M2 <- rbinom(n, 1, plogis(0.6 * M1))
  Y <- 0.3 * M2 + 0.2 * X + rnorm(n)
  d <- data.frame(X = X, M1 = M1, M2 = M2, Y = Y)

  f1 <- lm(M1 ~ X, data = d)
  g2 <- glm(M2 ~ M1, family = binomial, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(g2)
  )

  expect_s3_class(sm, "medfit::SerialMediationData")
  # d1 is read on the link (logit) scale: the M1 coefficient in the glm.
  expect_equal(sm@d_path, unname(coef(g2)["M1"]))
  # Per-mediator sigma: real for the Gaussian M1, NA for the binomial M2.
  expect_false(is.na(sm@sigma_mediators[1]))
  expect_true(is.na(sm@sigma_mediators[2]))
  expect_equal(sm@source_package, "stats::glm")
})

test_that("sigma_mediators is NULL when every mediator is non-Gaussian", {
  set.seed(101)
  n <- 700
  X <- rnorm(n)
  M1 <- rbinom(n, 1, plogis(0.5 * X))
  M2 <- rbinom(n, 1, plogis(0.6 * M1))
  Y <- 0.3 * M2 + 0.2 * X + rnorm(n)
  d <- data.frame(X = X, M1 = M1, M2 = M2, Y = Y)

  g1 <- glm(M1 ~ X, family = binomial, data = d)
  g2 <- glm(M2 ~ M1, family = binomial, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  sm <- extract_mediation(
    g1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(g2)
  )

  expect_null(sm@sigma_mediators)
})

test_that("sigma_y is NULL for a non-Gaussian outcome", {
  set.seed(202)
  n <- 700
  X <- rnorm(n)
  M1 <- 0.5 * X + rnorm(n)
  M2 <- 0.4 * M1 + rnorm(n)
  Y <- rbinom(n, 1, plogis(0.3 * M2 + 0.2 * X))
  d <- data.frame(X = X, M1 = M1, M2 = M2, Y = Y)

  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  gy <- glm(Y ~ M2 + X, family = binomial, data = d)

  sm <- extract_mediation(
    f1,
    model_y = gy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(f2)
  )

  expect_null(sm@sigma_y)
})


# ==============================================================================
# Order cross-check errors (one per failure mode)
# ==============================================================================

test_that("wrong mediator_models length errors", {
  d <- generate_serial_lm_data_3med()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  fy <- lm(Y ~ M3 + X, data = d)

  expect_error(
    extract_mediation(
      f1, model_y = fy, treatment = "X",
      mediator = c("M1", "M2", "M3"),
      mediator_models = list(f2)  # should be length 2
    ),
    "length 2"
  )
})

test_that("mis-ordered mediator_models errors with an informative message", {
  d <- generate_serial_lm_data_3med()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  f3 <- lm(M3 ~ M2, data = d)
  fy <- lm(Y ~ M3 + X, data = d)

  expect_error(
    extract_mediation(
      f1, model_y = fy, treatment = "X",
      mediator = c("M1", "M2", "M3"),
      mediator_models = list(f3, f2)  # swapped
    ),
    "must be the model for mediator 2"
  )
})

test_that("treatment absent from object errors", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  expect_error(
    extract_mediation(
      f1, model_y = fy, treatment = "Z",
      mediator = c("M1", "M2"),
      mediator_models = list(f2)
    ),
    "Treatment 'Z' is not a predictor"
  )
})

test_that("last mediator absent from model_y errors", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  f2 <- lm(M2 ~ M1, data = d)
  fy_bad <- lm(Y ~ X, data = d)  # M2 missing from outcome model

  expect_error(
    extract_mediation(
      f1, model_y = fy_bad, treatment = "X",
      mediator = c("M1", "M2"),
      mediator_models = list(f2)
    ),
    "Last mediator 'M2' is not a predictor"
  )
})

test_that("predecessor mediator absent from its model errors", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  # M2 regressed on X instead of M1: response is right, predictor wrong.
  f2_bad <- lm(M2 ~ X, data = d)
  fy <- lm(Y ~ M2 + X, data = d)

  expect_error(
    extract_mediation(
      f1, model_y = fy, treatment = "X",
      mediator = c("M1", "M2"),
      mediator_models = list(f2_bad)
    ),
    "Predecessor mediator 'M1' is not a predictor"
  )
})


# ==============================================================================
# Covariate tolerance (Q1): d_i is the predecessor coefficient regardless
# ==============================================================================

test_that("extra covariates in a mediator equation are tolerated (M2 ~ M1 + X)", {
  d <- generate_serial_lm_data()
  f1 <- lm(M1 ~ X, data = d)
  f2_cov <- lm(M2 ~ M1 + X, data = d)  # extra covariate X
  fy <- lm(Y ~ M2 + X, data = d)

  sm <- extract_mediation(
    f1,
    model_y = fy,
    treatment = "X",
    mediator = c("M1", "M2"),
    mediator_models = list(f2_cov)
  )

  # d1 is still the M1 coefficient, read regardless of the X covariate.
  expect_equal(sm@d_path, unname(coef(f2_cov)["M1"]))
  expect_true("X" %in% sm@mediator_predictors[[2]])
})
