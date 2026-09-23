# Delta-method effect standard errors (SPEC-tidy-effect-se-2026-09-23.md)
#
# Regression pins were captured from dev (2f882a5) before the helper refactor.
# Every confint() number must survive the refactor unchanged, except the Simple
# TE interval, which the old formula computed without Cov(ab, c') (GRILL D2).

demo_formula <- function(lhs_rhs) {
  stats::as.formula(paste(lhs_rhs, "+ covariate1 + covariate2"))
}

demo_simple <- function() {
  extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1"), data = mediation_demo),
    treatment = "treatment", mediator = "mediator1"
  )
}

demo_parallel <- function() {
  extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1 + mediator3"),
                 data = mediation_demo),
    treatment = "treatment", mediator = c("mediator1", "mediator3"),
    mediator_models = list(lm(demo_formula("mediator3 ~ treatment"), data = mediation_demo))
  )
}

demo_interaction <- function() {
  extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome_int ~ treatment * mediator1"), data = mediation_demo),
    treatment = "treatment", mediator = "mediator1"
  )
}

demo_regmedint <- function() {
  fit_mediation(
    formula_y = demo_formula("outcome_int ~ treatment * mediator1"),
    formula_m = demo_formula("mediator1 ~ treatment"),
    data = mediation_demo, treatment = "treatment", mediator = "mediator1",
    engine = "regmedint"
  )
}

quiet_confint <- function(...) suppressWarnings(suppressMessages(confint(...)))

# Pinned values are column-major: all lower bounds, then all upper bounds.
expect_pinned_ci <- function(ci, rows, values) {
  expect_identical(rownames(ci), rows)
  expect_equal(as.vector(ci), values, tolerance = 1e-10)
}

# ==============================================================================
# Regression pins (T1)
# ==============================================================================

test_that("Simple confint() NIE and NDE intervals are unchanged", {
  ci <- quiet_confint(demo_simple(), parm = "effects")
  expect_identical(rownames(ci), c("nie", "nde", "te"))
  expect_equal(unname(ci["nie", ]), c(0.20635638474977949, 0.45918261323975096),
               tolerance = 1e-10)
  expect_equal(unname(ci["nde", ]), c(-0.0093614097508007699, 0.42095792516676489),
               tolerance = 1e-10)
})

test_that("Simple confint() TE SE includes Cov(ab, c') (GRILL D2)", {
  ci <- quiet_confint(demo_simple(), parm = "effects")
  te_se <- unname(ci["te", 2] - ci["te", 1]) / (2 * stats::qnorm(0.975))
  # Full delta-method gradient: 0.1194. The old formula gave 0.1273.
  expect_equal(te_se, 0.1194, tolerance = 5e-4 / 0.1194)
})

test_that("Parallel confint() effects are unchanged", {
  expect_pinned_ci(
    quiet_confint(demo_parallel(), parm = "effects"),
    c("indirect", "direct", "total"),
    c(0.29207642124965916, -0.10943170422557466, 0.30448060555360812,
      0.57270087554619786, 0.32178992083521207, 0.7726549078518864)
  )
})

test_that("Interaction (glm) confint() effects and components are unchanged", {
  med <- demo_interaction()
  expect_pinned_ci(
    quiet_confint(med, parm = "effects"),
    c("nde", "nie", "total"),
    c(0.026845486714029226, 0.39612312661770732, 0.61128241699995989,
      0.49065825829040755, 0.83810302010039461, 1.1404474747225786)
  )
  expect_pinned_ci(
    quiet_confint(med, parm = "components"),
    c("cde", "int_ref", "int_med", "pie"),
    c(-0.012427515752339385, -0.023784091779779783, 0.13266954660767988,
      0.19952256747799985, 0.44285307516846495, 0.1108622773680909,
      0.42152143721103291, 0.4805125954213893)
  )
})

test_that("Interaction (regmedint) confint() effects and components are unchanged", {
  skip_if_not_installed("regmedint")
  med <- demo_regmedint()
  expect_pinned_ci(
    quiet_confint(med, parm = "effects"),
    c("nde", "nie", "total"),
    c(0.026845486714029254, 0.39612312661770732, 0.61128241699995989,
      0.49065825829040749, 0.83810302010039461, 1.1404474747225786)
  )
  expect_pinned_ci(
    quiet_confint(med, parm = "components"),
    c("cde", "int_ref", "int_med", "pie"),
    c(-0.012427515752339385, -0.023784091779779762, 0.13266954660767988,
      0.19952256747799985, 0.44285307516846495, 0.11086227736809091,
      0.42152143721103291, 0.4805125954213893)
  )
})
