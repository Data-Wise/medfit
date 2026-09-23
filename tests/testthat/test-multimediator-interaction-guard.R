# Tests for the multi-mediator product-term guard
#
# Serial and parallel extraction estimate main-effect paths only. A product
# term involving the treatment or a mediator (e.g. X:M1 in the outcome model)
# used to be ignored silently: extraction returned before the single-mediator
# interaction check, so the result reported main effects as if no interaction
# existed. The guard turns that into an error on both the lm and lavaan paths.

generate_guard_data <- function(n = 500, seed = 42) {
  set.seed(seed)
  X  <- rbinom(n, 1, 0.5)
  C  <- rnorm(n)
  M1 <- 0.5 * X + 0.3 * C + rnorm(n)
  M2 <- 0.2 * X + 0.5 * M1 + rnorm(n)
  Y  <- 0.2 * X + 0.4 * M1 + 0.3 * M2 + 0.5 * X * M1 + 0.3 * C + rnorm(n)
  data.frame(X = X, C = C, M1 = M1, M2 = M2, Y = Y)
}

# ==============================================================================
# lm / glm path
# ==============================================================================

test_that("serial lm extraction errors on an X:M1 term in the outcome model", {
  d <- generate_guard_data()
  expect_error(
    extract_mediation(
      lm(M1 ~ X + C, d),
      model_y = lm(Y ~ X * M1 + M2 + C, d),
      treatment = "X", mediator = c("M1", "M2"),
      mediator_models = list(lm(M2 ~ X + M1 + C, d))
    ),
    "product term.*X:M1"
  )
})

test_that("parallel lm extraction errors on a mediator product term", {
  d <- generate_guard_data()
  expect_error(
    extract_mediation(
      lm(M1 ~ X + C, d),
      model_y = lm(Y ~ X + M1 * M2 + C, d),
      treatment = "X", mediator = c("M1", "M2"),
      mediator_models = list(lm(M2 ~ X + C, d)),
      structure = "parallel"
    ),
    "product term.*M1:M2"
  )
})

test_that("lm guard also inspects the mediator models", {
  d <- generate_guard_data()
  expect_error(
    extract_mediation(
      lm(M1 ~ X + C, d),
      model_y = lm(Y ~ X + M1 + M2 + C, d),
      treatment = "X", mediator = c("M1", "M2"),
      mediator_models = list(lm(M2 ~ X * M1 + C, d)),
      structure = "serial"
    ),
    "product term.*X:M1"
  )
})

test_that("lm guard ignores products that involve only covariates", {
  d <- generate_guard_data()
  d$C2 <- rnorm(nrow(d))
  sm <- extract_mediation(
    lm(M1 ~ X + C, d),
    model_y = lm(Y ~ X + M1 + M2 + C * C2, d),
    treatment = "X", mediator = c("M1", "M2"),
    mediator_models = list(lm(M2 ~ X + M1 + C, d))
  )
  expect_s3_class(sm, "medfit::SerialMediationData")
})

# ==============================================================================
# lavaan path
# ==============================================================================

test_that("serial lavaan extraction errors on an X:M1 regressor", {
  skip_if_not_installed("lavaan")
  d <- generate_guard_data()
  fit <- lavaan::sem("
    M1 ~ X + C
    M2 ~ X + M1 + C
    Y  ~ X + M1 + M2 + X:M1 + C
  ", data = d)
  expect_error(
    extract_mediation(fit, treatment = "X", mediator = c("M1", "M2")),
    "product term.*X:M1"
  )
})

test_that("parallel lavaan extraction errors on a named product column", {
  skip_if_not_installed("lavaan")
  d <- generate_guard_data()
  d$XM1 <- d$X * d$M1
  fit <- lavaan::sem("
    M1 ~ X + C
    M2 ~ X + C
    Y  ~ X + M1 + M2 + XM1 + C
  ", data = d)
  expect_error(
    extract_mediation(fit, treatment = "X", mediator = c("M1", "M2"),
                      structure = "parallel", interaction = "XM1"),
    "product term.*XM1"
  )
})

test_that("lavaan guard passes a product-free multi-mediator model", {
  skip_if_not_installed("lavaan")
  d <- generate_guard_data()
  fit <- lavaan::sem("
    M1 ~ X + C
    M2 ~ X + M1 + C
    Y  ~ X + M1 + M2 + C
  ", data = d)
  expect_length(.find_product_terms_lavaan(fit, c("X", "M1", "M2")), 0L)
  sm <- extract_mediation(fit, treatment = "X", mediator = c("M1", "M2"))
  expect_s3_class(sm, "medfit::SerialMediationData")
})
