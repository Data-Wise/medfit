# Known-answer tests for the bundled `mediation_demo` dataset
#
# Targets are the reduced-form limits of each demo's fitted model (GRILL D9-R2),
# derived from the generating equations in data-raw/mediation_demo.R. That
# directory is excluded from the built package, so the values are hard-coded
# here and must be kept in sync with the script. A demo that omits a
# downstream mediator absorbs that mediator's path, so its coefficients differ
# from the structural ones; the mediator-equation paths (a, a3, d) are
# structural in every demo.
#
# Each estimate must fall within 3 standard errors of its target. At n = 400
# every named path is at least 4 SE from zero (recorded in data-raw), so a
# sign error or a missing interaction term fails the check.

demo_fit_lm <- function(rhs, lhs) {
  stats::lm(stats::as.formula(paste(lhs, "~", rhs, "+ covariate1 + covariate2")),
            data = medfit::mediation_demo)
}

expect_near_target <- function(fit, term, target) {
  est <- unname(stats::coef(fit)[term])
  se <- unname(sqrt(diag(stats::vcov(fit)))[term])
  expect_true(abs(est - target) <= 3 * se, # nolint: object_usage_linter.
              info = sprintf("%s: estimate %.3f, target %.3f, SE %.3f",
                             term, est, target, se))
}

test_that("mediation_demo has the documented shape", {
  expect_s3_class(mediation_demo, "data.frame")
  expect_identical(dim(mediation_demo), c(400L, 8L))
  expect_named(mediation_demo, c("treatment", "mediator1", "mediator2",
                                 "mediator3", "covariate1", "covariate2",
                                 "outcome", "outcome_int"))
  expect_true(all(mediation_demo$treatment %in% c(0L, 1L)))
  expect_true(all(mediation_demo$covariate2 %in% c(0L, 1L)))
  expect_false(anyNA(mediation_demo))
})

test_that("mediator-equation paths recover their structural values", {
  expect_near_target(demo_fit_lm("treatment", "mediator1"), "treatment", 0.5)
  expect_near_target(demo_fit_lm("treatment", "mediator3"), "treatment", 0.5)
  m2 <- demo_fit_lm("treatment + mediator1", "mediator2")
  expect_near_target(m2, "mediator1", 0.5)
  expect_near_target(m2, "treatment", 0.2)
})

test_that("simple demo recovers its reduced-form targets", {
  fy <- demo_fit_lm("treatment + mediator1", "outcome")
  expect_near_target(fy, "mediator1", 0.55)
  expect_near_target(fy, "treatment", 0.41)
})

test_that("serial demo (mediator1 in the outcome model) recovers its targets", {
  fy <- demo_fit_lm("treatment + mediator1 + mediator2", "outcome")
  expect_near_target(fy, "mediator2", 0.30)
  expect_near_target(fy, "mediator1", 0.40)
  expect_near_target(fy, "treatment", 0.35)

  sm <- extract_mediation(
    demo_fit_lm("treatment", "mediator1"),
    model_y = fy,
    treatment = "treatment",
    mediator = c("mediator1", "mediator2"),
    mediator_models = list(demo_fit_lm("treatment + mediator1", "mediator2"))
  )
  expect_s3_class(sm, "medfit::SerialMediationData")
  expect_equal(sm@b_path, unname(stats::coef(fy)["mediator2"]))
})

test_that("parallel demo recovers its reduced-form targets", {
  fy <- demo_fit_lm("treatment + mediator1 + mediator3", "outcome")
  expect_near_target(fy, "mediator1", 0.55)
  expect_near_target(fy, "mediator3", 0.30)
  expect_near_target(fy, "treatment", 0.26)
})

test_that("interaction demo recovers its reduced-form targets", {
  fy <- demo_fit_lm("treatment * mediator1", "outcome_int")
  expect_near_target(fy, "treatment:mediator1", 0.50)
  expect_near_target(fy, "mediator1", 0.55)
  expect_near_target(fy, "treatment", 0.41)
})

test_that("serial extraction of outcome_int routes to the joint effects", {
  fy <- demo_fit_lm("treatment * mediator1 + mediator2", "outcome_int")
  obj <- extract_mediation(
    demo_fit_lm("treatment", "mediator1"),
    model_y = fy,
    treatment = "treatment",
    mediator = c("mediator1", "mediator2"),
    mediator_models = list(demo_fit_lm("treatment + mediator1", "mediator2"))
  )
  expect_true(S7::S7_inherits(obj, JointMediationData))
})
