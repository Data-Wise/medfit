# A parameter pinned by the active set (an equality, an active bound) has a zero standard error with or without a
# mean structure. With a mean structure `.sem_vcov()` projects in centered coordinates and maps back; the pinned row
# must come back as an exact zero, not roundoff (5.6e-18 before the fix), or `tidy()` computes a z-statistic for it.
# Each cell has its own oracle: the same model with the parameter fixed in the syntax, the fit without a mean
# structure (no centering), or lavaan.

pin_base <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + cp*treatment + covariate1\n"
pin_fixed <- "mediator1 ~ a*treatment + covariate1\noutcome ~ 0*mediator1 + cp*treatment + covariate1\n"

pin_se <- function(fit) sqrt(pmax(diag(vcov(fit)), 0))
pin_common <- function(x, y) {
  keep <- intersect(names(x), names(y))
  list(x = x[keep], y = y[keep])
}

test_that("an equality-pinned parameter has an exact zero SE and no test under a mean structure", {
  fit <- fit_sem(paste0(pin_base, "b == 0"), mediation_demo, meanstructure = TRUE)
  expect_identical(unname(pin_se(fit)["b"]), 0)
  row <- generics::tidy(fit)[generics::tidy(fit)$term == "b", ]
  expect_identical(row$std_error, 0)
  expect_true(is.na(row$statistic) && is.na(row$p_value))
  # oracle: b fixed at 0 in the syntax gives the same SEs for every other parameter
  oracle <- fit_sem(pin_fixed, mediation_demo, meanstructure = TRUE)
  both <- pin_common(pin_se(fit), pin_se(oracle))
  expect_equal(both$x, both$y, tolerance = 1e-6)
})

test_that("the mean structure leaves every SE of an equality-constrained fit unchanged", {
  plain <- pin_se(fit_sem(paste0(pin_base, "b == 0"), mediation_demo))
  means <- pin_se(fit_sem(paste0(pin_base, "b == 0"), mediation_demo, meanstructure = TRUE))
  both <- pin_common(plain, means)
  expect_identical(both$x[["b"]], 0)
  expect_identical(both$y[["b"]], 0)
  expect_equal(both$x, both$y, tolerance = 1e-8)
})

test_that("a coefficient fixed in the syntax matches lavaan's SEs under a mean structure", {
  skip_if_not_installed("lavaan")
  fit <- fit_sem(pin_fixed, mediation_demo, meanstructure = TRUE)
  lav <- lavaan::sem(pin_fixed, mediation_demo, meanstructure = TRUE, fixed.x = FALSE)
  pe <- lavaan::parameterEstimates(lav)
  td <- generics::tidy(fit)
  for (lab in c("a", "cp")) {
    expect_equal(td$std_error[td$term == lab], pe$se[pe$label == lab], tolerance = 1e-5)
  }
})

test_that("a parameter on an active bound has an exact zero SE under a mean structure", {
  bound <- "mediator1 ~ a*treatment + covariate1\noutcome ~ lower(0.9)*mediator1 + cp*treatment + covariate1"
  fit <- fit_sem(bound, mediation_demo, meanstructure = TRUE)
  s <- pin_se(fit)
  expect_equal(coef(fit)[["outcome~mediator1"]], 0.9, tolerance = 1e-6)
  expect_identical(unname(s["outcome~mediator1"]), 0)
  # oracle: the path fixed at the bound in the syntax
  oracle <- fit_sem(sub("lower(0.9)", "0.9", bound, fixed = TRUE), mediation_demo, meanstructure = TRUE)
  both <- pin_common(s, pin_se(oracle))
  expect_equal(both$x, both$y, tolerance = 1e-5)
})

test_that("an active nonlinear row pins no coordinate: every SE stays positive and matches the uncentered fit", {
  m <- paste0(pin_base, "cp == a*b")
  plain <- pin_se(fit_sem(m, mediation_demo))
  means <- pin_se(fit_sem(m, mediation_demo, meanstructure = TRUE))
  both <- pin_common(plain, means)
  expect_true(all(both$y > 0))
  expect_equal(both$x, both$y, tolerance = 1e-8)
})

test_that("the sandwich covariance gives an exact zero SE to an equality-pinned parameter under a mean structure", {
  fit <- fit_sem(paste0(pin_base, "b == 0"), mediation_demo, meanstructure = TRUE, se_type = "sandwich")
  s <- pin_se(fit)
  expect_identical(unname(s["b"]), 0)
  oracle <- fit_sem(pin_fixed, mediation_demo, meanstructure = TRUE, se_type = "sandwich")
  both <- pin_common(s, pin_se(oracle))
  expect_equal(both$x, both$y, tolerance = 1e-6)
})

test_that("a coordinate with a tiny but nonzero share of a free direction keeps its positive SE", {
  # `a == 1e-9 * b` leaves one free direction with a component of about 1e-9 on `a`: a structural zero it is not,
  # so its SE (about 5e-11) must survive the centered round trip. A tolerance-based restore would erase it.
  m <- paste0(pin_base, "a == 1e-9*b")
  plain <- pin_se(fit_sem(m, mediation_demo))
  means <- pin_se(fit_sem(m, mediation_demo, meanstructure = TRUE))
  expect_gt(means[["a"]], 0)
  expect_equal(means[["a"]], plain[["a"]], tolerance = 1e-6)
})

test_that("shifting every observed mean leaves the SEs and the exact zero unchanged", {
  m <- paste0(pin_base, "b == 0")
  shifted <- mediation_demo
  vars <- c("treatment", "mediator1", "outcome", "covariate1")
  shifted[vars] <- lapply(shifted[vars], function(v) v + 25)
  s0 <- pin_se(fit_sem(m, mediation_demo, meanstructure = TRUE))
  s1 <- pin_se(fit_sem(m, shifted, meanstructure = TRUE))
  expect_identical(unname(s1["b"]), 0)
  # intercepts move with the means (their SEs depend on them); every other SE is shift invariant
  slopes <- function(s) s[!grepl("~1", names(s), fixed = TRUE)]
  both <- pin_common(slopes(s0), slopes(s1))
  expect_equal(both$x, both$y, tolerance = 1e-6)
})
