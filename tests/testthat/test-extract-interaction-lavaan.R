# Tests for lavaan extraction of the four-way (VanderWeele 2014) decomposition
# via extract_mediation() (Extension B, PR B2b).
#
# In lavaan the X*M interaction enters as a product predictor (a data column),
# named via the `interaction` argument. The model must be fit with
# meanstructure = TRUE so the mediator intercept (needed for INTref) is
# available. Returns an InteractionMediationData object.
#
# Skipped entirely if lavaan is not installed.

skip_if_not_installed("lavaan")

gen_lav_interaction <- function(n = 4000, beta0 = 0.4, beta1 = 0.5,
                                theta1 = 0.1, theta2 = 0.3, theta3 = 0.25,
                                seed = 1) {
  set.seed(seed)
  X <- rbinom(n, 1, 0.5)
  M <- beta0 + beta1 * X + rnorm(n)
  Y <- theta1 * X + theta2 * M + theta3 * X * M + rnorm(n)
  data.frame(X = X, M = M, Y = Y, XM = X * M)
}

fit_lav_interaction <- function(data = gen_lav_interaction(), meanstructure = TRUE) {
  lavaan::sem("M ~ X\n Y ~ M + X + XM", data = data, meanstructure = meanstructure)
}

# ==============================================================================
# Detection and return type
# ==============================================================================

test_that("the interaction argument routes to InteractionMediationData", {
  skip_if_not_installed("lavaan")
  imd <- extract_mediation(fit_lav_interaction(), treatment = "X",
                           mediator = "M", outcome = "Y", interaction = "XM")
  expect_s3_class(imd, "medfit::InteractionMediationData")
  expect_equal(imd@treatment, "X")
  expect_equal(imd@source_package, "lavaan")
  expect_equal(imd@m_star, 0)
})

test_that("the outcome is auto-detected when omitted", {
  skip_if_not_installed("lavaan")
  imd <- extract_mediation(fit_lav_interaction(), treatment = "X",
                           mediator = "M", interaction = "XM")
  expect_equal(imd@outcome, "Y")
})

# ==============================================================================
# Component fidelity vs lavaan parameter estimates
# ==============================================================================

test_that("components match the closed-form formulas from parameterEstimates", {
  skip_if_not_installed("lavaan")
  fit <- fit_lav_interaction()
  imd <- extract_mediation(fit, treatment = "X", mediator = "M",
                           outcome = "Y", interaction = "XM")

  pe <- lavaan::parameterEstimates(fit)
  g <- function(l, r) pe$est[pe$lhs == l & pe$op == "~" & pe$rhs == r][1]
  b0 <- pe$est[pe$lhs == "M" & pe$op == "~1"][1]
  b1 <- g("M", "X")
  t1 <- g("Y", "X")
  t2 <- g("Y", "M")
  t3 <- g("Y", "XM")

  expect_equal(imd@cde, t1)              # CDE is theta1 at m* equal to 0
  expect_equal(imd@int_med, t3 * b1)     # INTmed is theta3 times beta1
  expect_equal(imd@pie, t2 * b1)         # PIE is theta2 times beta1
  expect_equal(imd@int_ref, t3 * b0)     # INTref is theta3 times beta0 (no covariates)
  expect_equal(imd@total_effect, imd@nde + imd@nie)
})

test_that("m_star shifts CDE and INTref by theta3, leaving the total invariant", {
  skip_if_not_installed("lavaan")
  fit <- fit_lav_interaction()
  pe <- lavaan::parameterEstimates(fit)
  t3 <- pe$est[pe$lhs == "Y" & pe$op == "~" & pe$rhs == "XM"][1]

  imd0 <- extract_mediation(fit, treatment = "X", mediator = "M",
                            outcome = "Y", interaction = "XM", m_star = 0)
  imd1 <- extract_mediation(fit, treatment = "X", mediator = "M",
                            outcome = "Y", interaction = "XM", m_star = 1)
  expect_equal(imd1@cde - imd0@cde, t3)
  expect_equal(imd1@int_ref - imd0@int_ref, -t3)
  expect_equal(imd0@total_effect, imd1@total_effect)
})

# ==============================================================================
# meanstructure requirement and detection edge cases
# ==============================================================================

test_that("a model without meanstructure errors with a directed message", {
  skip_if_not_installed("lavaan")
  fit <- fit_lav_interaction(meanstructure = FALSE)
  expect_error(
    extract_mediation(fit, treatment = "X", mediator = "M",
                      outcome = "Y", interaction = "XM"),
    "meanstructure"
  )
})

test_that("decomposition = 'four_way' errors when no interaction is found", {
  skip_if_not_installed("lavaan")
  fit <- lavaan::sem("M ~ X\n Y ~ M + X", data = gen_lav_interaction(),
                     meanstructure = TRUE)
  expect_error(
    extract_mediation(fit, treatment = "X", mediator = "M", outcome = "Y",
                      decomposition = "four_way"),
    "requires an interaction term"
  )
})

test_that("decomposition = 'two_way' ignores the XM term and returns MediationData", {
  skip_if_not_installed("lavaan")
  md <- extract_mediation(fit_lav_interaction(), treatment = "X", mediator = "M",
                          outcome = "Y", interaction = "XM",
                          decomposition = "two_way")
  expect_s3_class(md, "medfit::MediationData")
})

# ==============================================================================
# confint (delta method over the joint SEM covariance)
# ==============================================================================

test_that("confint components/effects have the right shape and bracket the estimates", {
  skip_if_not_installed("lavaan")
  imd <- extract_mediation(fit_lav_interaction(), treatment = "X", mediator = "M",
                           outcome = "Y", interaction = "XM")

  cc <- suppressMessages(confint(imd, parm = "components"))
  expect_equal(rownames(cc), c("cde", "int_ref", "int_med", "pie"))
  expect_true(cc["pie", 1] <= imd@pie && cc["pie", 2] >= imd@pie)

  ce <- suppressMessages(confint(imd, parm = "effects"))
  expect_equal(rownames(ce), c("nde", "nie", "total"))
  expect_true(ce["nie", 1] <= imd@nie && ce["nie", 2] >= imd@nie)

  cp <- confint(imd, parm = "paths")
  expect_equal(rownames(cp), c("a", "b", "c_prime", "theta3"))
})

# ==============================================================================
# Covariate-adjusted INTref (uses E[M | X = 0] at covariate means)
# ==============================================================================

test_that("covariate-adjusted INTref uses the mediator intercept plus covariate means", {
  skip_if_not_installed("lavaan")
  set.seed(4)
  n <- 4000
  C <- rnorm(n, mean = 2)
  X <- rbinom(n, 1, 0.5)
  M <- 0.4 + 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.1 * X + 0.3 * M + 0.25 * X * M + 0.2 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C, XM = X * M)
  fit <- lavaan::sem("M ~ X + C\n Y ~ M + X + XM + C", data = d, meanstructure = TRUE)
  imd <- extract_mediation(fit, treatment = "X", mediator = "M",
                           outcome = "Y", interaction = "XM")

  pe <- lavaan::parameterEstimates(fit)
  g <- function(l, r) pe$est[pe$lhs == l & pe$op == "~" & pe$rhs == r][1]
  b0 <- pe$est[pe$lhs == "M" & pe$op == "~1"][1]
  bc <- g("M", "C")
  t3 <- g("Y", "XM")
  m_ref <- b0 + bc * mean(d$C)
  expect_equal(imd@int_ref, t3 * m_ref)
})
