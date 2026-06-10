# Tests for lm/glm extraction of the four-way (VanderWeele 2014) decomposition
# via extract_mediation() (Extension B, PR B2a).
#
# Triggered when a single mediator's outcome model carries an X:M interaction
# term. Returns an InteractionMediationData object with CDE/INTref/INTmed/PIE and
# delta-method confint(). MVP: continuous (Gaussian) Y and M, binary treatment.

# Generate data with a known treatment-by-mediator interaction.
# Mediator:  M is beta0 plus beta1 times X plus noise.
# Outcome:   Y is theta1 times X plus theta2 times M plus theta3 times X times M.
gen_interaction <- function(n = 4000, beta0 = 0.4, beta1 = 0.5,
                            theta1 = 0.1, theta2 = 0.3, theta3 = 0.25,
                            seed = 1) {
  set.seed(seed)
  X <- rbinom(n, 1, 0.5)
  M <- beta0 + beta1 * X + rnorm(n)
  Y <- theta1 * X + theta2 * M + theta3 * X * M + rnorm(n)
  data.frame(X = X, M = M, Y = Y)
}

# ==============================================================================
# Detection and return type
# ==============================================================================

test_that("an X:M term routes to InteractionMediationData (auto)", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X",
                           mediator = "M", outcome = "Y")
  expect_s3_class(imd, "medfit::InteractionMediationData")
  expect_equal(imd@treatment, "X")
  expect_equal(imd@m_star, 0)
  expect_equal(imd@source_package, "stats::lm")
})

test_that("the reversed M:X formula ordering is also detected", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + M:X, d)   # reversed interaction order
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  expect_s3_class(imd, "medfit::InteractionMediationData")
})

test_that("no interaction term yields a plain MediationData (backward compatible)", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M, d)
  md <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  expect_s3_class(md, "medfit::MediationData")
})

# ==============================================================================
# Component fidelity vs the VanderWeele formulas
# ==============================================================================

test_that("components match the closed-form formulas (no covariates, m* = 0)", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")

  b0 <- unname(coef(fm)[["(Intercept)"]])
  b1 <- unname(coef(fm)[["X"]])
  t1 <- unname(coef(fy)[["X"]])
  t2 <- unname(coef(fy)[["M"]])
  t3 <- unname(coef(fy)[["X:M"]])

  expect_equal(imd@cde, t1)              # CDE is theta1 when m* is 0
  expect_equal(imd@int_med, t3 * b1)     # INTmed is theta3 times beta1
  expect_equal(imd@pie, t2 * b1)         # PIE is theta2 times beta1
  expect_equal(imd@int_ref, t3 * b0)     # INTref is theta3 times beta0 (no covariates)
  expect_equal(imd@total_effect, imd@nde + imd@nie)
})

test_that("m_star shifts CDE and INTref by theta3", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  t3 <- unname(coef(fy)[["X:M"]])

  imd0 <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M",
                            m_star = 0)
  imd1 <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M",
                            m_star = 1)
  expect_equal(imd1@cde - imd0@cde, t3)        # CDE gains theta3 per unit m*
  expect_equal(imd1@int_ref - imd0@int_ref, -t3)  # INTref loses theta3 per unit m*
  # The total effect is invariant to the reference level.
  expect_equal(imd0@total_effect, imd1@total_effect)
})

test_that("covariate-adjusted INTref uses E[M | X = 0] at covariate means", {
  set.seed(3)
  n <- 4000
  C <- rnorm(n, mean = 2)
  X <- rbinom(n, 1, 0.5)
  M <- 0.4 + 0.5 * X + 0.3 * C + rnorm(n)
  Y <- 0.1 * X + 0.3 * M + 0.25 * X * M + 0.2 * C + rnorm(n)
  d <- data.frame(X = X, M = M, Y = Y, C = C)
  fm <- lm(M ~ X + C, d)
  fy <- lm(Y ~ X + M + X:M + C, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")

  b0 <- unname(coef(fm)[["(Intercept)"]])
  bc <- unname(coef(fm)[["C"]])
  t3 <- unname(coef(fy)[["X:M"]])
  m_ref <- b0 + bc * mean(d$C)
  expect_equal(imd@int_ref, t3 * m_ref)
})

# ==============================================================================
# decomposition argument
# ==============================================================================

test_that("decomposition = 'four_way' errors when no interaction is present", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M, d)
  expect_error(
    extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M",
                      decomposition = "four_way"),
    "requires an interaction term"
  )
})

test_that("decomposition = 'two_way' forces MediationData even with an X:M term", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  md <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M",
                          decomposition = "two_way")
  expect_s3_class(md, "medfit::MediationData")
})

# ==============================================================================
# confint (delta method)
# ==============================================================================

test_that("confint paths/components/effects have the right shape and brackets", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")

  cp <- confint(imd, parm = "paths")
  expect_equal(rownames(cp), c("a", "b", "c_prime", "theta3"))

  cc <- suppressMessages(confint(imd, parm = "components"))
  expect_equal(rownames(cc), c("cde", "int_ref", "int_med", "pie"))
  expect_true(cc["int_med", 1] <= imd@int_med && cc["int_med", 2] >= imd@int_med)

  ce <- suppressMessages(confint(imd, parm = "effects"))
  expect_equal(rownames(ce), c("nde", "nie", "total"))
  expect_true(ce["total", 1] <= imd@total_effect &&
                ce["total", 2] >= imd@total_effect)
})

test_that("delta-method SE for INTmed matches the manual product-variance formula", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")

  b1 <- imd@a_path
  t3 <- imd@interaction
  var_b1 <- imd@vcov["a", "a"]
  var_t3 <- imd@vcov["theta3", "theta3"]
  # Separate equations: cov(theta3, beta1) is 0, so the product variance is
  # b1^2 Var(t3) plus t3^2 Var(b1).
  se_manual <- sqrt(b1^2 * var_t3 + t3^2 * var_b1)

  ci <- suppressMessages(confint(imd, parm = "components"))
  z <- qnorm(0.975)
  se_ci <- (ci["int_med", 2] - ci["int_med", 1]) / (2 * z)
  expect_equal(unname(se_ci), se_manual, tolerance = 1e-8)
})

test_that("lm separation zeroes cov(theta3, beta1) in the vcov", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  # a lives in the mediator equation, theta3 in the outcome equation.
  expect_equal(imd@vcov["a", "theta3"], 0)
})

test_that("confint method = 'boot' directs to bootstrap_mediation", {
  d <- gen_interaction()
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  expect_error(confint(imd, method = "boot"), "bootstrap_mediation")
})

# ==============================================================================
# Non-Gaussian guard (MVP scope)
# ==============================================================================

test_that("a non-Gaussian outcome model is rejected with a clear message", {
  set.seed(5)
  n <- 1000
  X <- rbinom(n, 1, 0.5)
  M <- 0.4 + 0.5 * X + rnorm(n)
  Yb <- rbinom(n, 1, plogis(-0.5 + 0.3 * M + 0.2 * X * M))
  d <- data.frame(X = X, M = M, Yb = Yb)
  fm <- lm(M ~ X, d)
  fyb <- glm(Yb ~ X + M + X:M, family = binomial, data = d)
  expect_error(
    extract_mediation(fm, model_y = fyb, treatment = "X", mediator = "M"),
    "Gaussian"
  )
})

# ==============================================================================
# Simulation: delta CI brackets the truth at roughly nominal rate
# ==============================================================================

test_that("delta CI for the total indirect (NIE) brackets the true value", {
  # True NIE is INTmed plus PIE. With theta3 0.25, beta1 0.5, theta2 0.3 and
  # E[M|X=0] equal to beta0 0.4, NIE is t3*b1 plus t2*b1 (the mediated pieces).
  truth_nie <- 0.25 * 0.5 + 0.3 * 0.5
  d <- gen_interaction(n = 8000)
  fm <- lm(M ~ X, d)
  fy <- lm(Y ~ X + M + X:M, d)
  imd <- extract_mediation(fm, model_y = fy, treatment = "X", mediator = "M")
  ci <- suppressMessages(confint(imd, parm = "effects"))
  expect_true(ci["nie", 1] <= truth_nie && ci["nie", 2] >= truth_nie)
})
