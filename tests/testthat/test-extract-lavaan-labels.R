# Tests for alias vcov resolution when lavaan paths carry custom labels
#
# lavaan names a labeled free parameter by its label ("aa"), not by the
# variable-name form ("M~X"). The alias rows (a, b, c_prime, d*, a*/b*, ...)
# in @vcov must be copied from that parameter regardless of how it is named,
# so a custom-labeled fit must yield the same alias block as the unlabeled fit
# of the same model.
#
# Skipped entirely if lavaan is not installed.

skip_if_not_installed("lavaan")

alias_block <- function(x, aliases) x@vcov[aliases, aliases]

expect_same_alias_block <- function(unlabeled, labeled, aliases) {
  vu <- alias_block(unlabeled, aliases)
  vl <- alias_block(labeled, aliases)
  testthat::expect_true(all(diag(vl) > 0))
  testthat::expect_equal(vl, vu, tolerance = 1e-10)
}

test_that("simple: custom labels give the unlabeled alias vcov block", {
  plain <- "mediator1 ~ treatment + covariate1 + covariate2
            outcome ~ treatment + mediator1 + covariate1 + covariate2"
  labeled <- "mediator1 ~ aa*treatment + covariate1 + covariate2
              outcome ~ cc*treatment + bb*mediator1 + covariate1 + covariate2"
  args <- list(treatment = "treatment", mediator = "mediator1",
               outcome = "outcome")
  xu <- do.call(extract_mediation,
                c(list(lavaan::sem(plain, data = mediation_demo)), args))
  xl <- do.call(extract_mediation,
                c(list(lavaan::sem(labeled, data = mediation_demo)), args))

  expect_same_alias_block(xu, xl, c("a", "b", "c_prime"))
  expect_equal(xl@a_path, xu@a_path, tolerance = 1e-10)
})

test_that("simple: default labels still resolve (label equals alias name)", {
  m <- "mediator1 ~ a*treatment
        outcome ~ cp*treatment + b*mediator1"
  plain <- "mediator1 ~ treatment
            outcome ~ treatment + mediator1"
  args <- list(treatment = "treatment", mediator = "mediator1",
               outcome = "outcome")
  xu <- do.call(extract_mediation,
                c(list(lavaan::sem(plain, data = mediation_demo)), args))
  xl <- do.call(extract_mediation,
                c(list(lavaan::sem(m, data = mediation_demo)), args))

  expect_same_alias_block(xu, xl, c("a", "b", "c_prime"))
})

test_that("serial (2 mediators): custom labels give the unlabeled block", {
  plain <- "mediator1 ~ treatment
            mediator2 ~ mediator1 + treatment
            outcome ~ mediator2 + mediator1 + treatment"
  labeled <- "mediator1 ~ p1*treatment
              mediator2 ~ p2*mediator1 + treatment
              outcome ~ p3*mediator2 + mediator1 + p4*treatment"
  args <- list(treatment = "treatment",
               mediator = c("mediator1", "mediator2"), outcome = "outcome",
               structure = "serial")
  xu <- do.call(extract_mediation,
                c(list(lavaan::sem(plain, data = mediation_demo)), args))
  xl <- do.call(extract_mediation,
                c(list(lavaan::sem(labeled, data = mediation_demo)), args))

  expect_true(S7::S7_inherits(xl, SerialMediationData))
  expect_same_alias_block(xu, xl, c("a", "d1", "b", "c_prime"))
})

test_that("serial (3 mediators): custom labels give the unlabeled block", {
  plain <- "mediator1 ~ treatment
            mediator2 ~ mediator1 + treatment
            mediator3 ~ mediator2 + treatment
            outcome ~ mediator3 + treatment"
  labeled <- "mediator1 ~ p1*treatment
              mediator2 ~ p2*mediator1 + treatment
              mediator3 ~ p3*mediator2 + treatment
              outcome ~ p4*mediator3 + p5*treatment"
  args <- list(treatment = "treatment",
               mediator = c("mediator1", "mediator2", "mediator3"),
               outcome = "outcome", structure = "serial")
  xu <- do.call(extract_mediation,
                c(list(lavaan::sem(plain, data = mediation_demo)), args))
  xl <- do.call(extract_mediation,
                c(list(lavaan::sem(labeled, data = mediation_demo)), args))

  expect_true(S7::S7_inherits(xl, SerialMediationData))
  expect_same_alias_block(xu, xl, c("a", "d1", "d2", "b", "c_prime"))
})

test_that("parallel: custom labels give the unlabeled block", {
  plain <- "mediator1 ~ treatment
            mediator3 ~ treatment
            outcome ~ mediator1 + mediator3 + treatment"
  labeled <- "mediator1 ~ a1x*treatment
              mediator3 ~ a2x*treatment
              outcome ~ b1x*mediator1 + b2x*mediator3 + cpx*treatment"
  args <- list(treatment = "treatment",
               mediator = c("mediator1", "mediator3"), outcome = "outcome",
               structure = "parallel")
  xu <- do.call(extract_mediation,
                c(list(lavaan::sem(plain, data = mediation_demo)), args))
  xl <- do.call(extract_mediation,
                c(list(lavaan::sem(labeled, data = mediation_demo)), args))

  expect_true(S7::S7_inherits(xl, ParallelMediationData))
  expect_same_alias_block(xu, xl, c("a1", "b1", "a2", "b2", "c_prime"))
})

test_that("interaction: custom labels give the unlabeled block", {
  d <- mediation_demo
  d$tm <- d$treatment * d$mediator1
  plain <- "mediator1 ~ treatment
            outcome_int ~ mediator1 + treatment + tm"
  labeled <- "mediator1 ~ aa*treatment
              outcome_int ~ bb*mediator1 + cc*treatment + ii*tm"
  args <- list(treatment = "treatment", mediator = "mediator1",
               outcome = "outcome_int", interaction = "tm")
  xu <- do.call(extract_mediation,
                c(list(lavaan::sem(plain, data = d, meanstructure = TRUE)),
                  args))
  xl <- do.call(extract_mediation,
                c(list(lavaan::sem(labeled, data = d, meanstructure = TRUE)),
                  args))

  expect_same_alias_block(xu, xl, c("a", "b", "c_prime", "theta3", "b0"))
})

test_that("parametric bootstrap on a labeled fit is non-degenerate", {
  skip_if_not_installed("MASS")
  labeled <- "mediator1 ~ aa*treatment + covariate1 + covariate2
              outcome ~ cc*treatment + bb*mediator1 + covariate1 + covariate2"
  x <- extract_mediation(lavaan::sem(labeled, data = mediation_demo),
                         treatment = "treatment", mediator = "mediator1",
                         outcome = "outcome")
  boot <- bootstrap_mediation(
    statistic_fn = function(theta) theta["a"] * theta["b"],
    method = "parametric", mediation_data = x, n_boot = 200, seed = 1
  )

  expect_gt(stats::sd(boot@boot_estimates), 0)
  expect_lt(boot@ci_lower, boot@ci_upper)
})
