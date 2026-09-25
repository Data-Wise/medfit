# confint(parm = "paths") locates each path's @vcov row by name (alias first,
# then the lm-style m_/y_ row) and errors rather than guessing by position.

# A hand-built MediationData whose path rows sit at positions 3-5, so a
# position-based guess (rows 1-3) would give the wrong SEs.
hand_built <- function(nm, dimnamed = TRUE) {
  v <- diag(c(0.09, 0.01, 0.04, 0.16, 0.25))
  if (dimnamed) dimnames(v) <- list(nm, nm)
  MediationData(
    a_path = 0.5, b_path = 0.3, c_prime = 0.2,
    treatment = "X", mediator = "M", outcome = "Y",
    estimates = stats::setNames(c(1, 2, 0.5, 0.3, 0.2), nm), vcov = v,
    sigma_m = 1, sigma_y = 1,
    mediator_predictors = "X", outcome_predictors = c("X", "M"),
    data = NULL, n_obs = 100L, converged = TRUE, source_package = "medfit"
  )
}

expected_ci <- function(se, level = 0.95) {
  z <- stats::qnorm(1 - (1 - level) / 2)
  est <- c(a = 0.5, b = 0.3, c_prime = 0.2)
  unname(cbind(est - z * se, est + z * se))
}

alias_names <- c("m_(Intercept)", "y_(Intercept)", "a", "b", "c_prime")
source_names <- c("m_(Intercept)", "y_(Intercept)", "m_X", "y_M", "y_X")

test_that("alias rows give the right path SEs without a warning", {
  obj <- hand_built(alias_names)
  expect_no_warning(ci <- confint(obj))
  expect_equal(unname(ci), expected_ci(c(0.2, 0.4, 0.5)))
  expect_identical(rownames(ci), c("a", "b", "c_prime"))
})

test_that("alias rows resolve through @estimates when @vcov has no dimnames", {
  obj <- hand_built(alias_names, dimnamed = FALSE)
  expect_no_warning(ci <- confint(obj))
  expect_equal(unname(ci), expected_ci(c(0.2, 0.4, 0.5)))
})

test_that("lm-style m_/y_ rows are the fallback", {
  obj <- hand_built(source_names)
  expect_no_warning(ci <- confint(obj))
  expect_equal(unname(ci), expected_ci(c(0.2, 0.4, 0.5)))
})

test_that("neither alias nor m_/y_ rows is an error, not a position guess", {
  obj <- hand_built(paste0("p", 1:5))
  expect_error(confint(obj), "vcov has no row for path: a \\(or m_X\\)")
})

test_that("lavaan-extracted paths use the alias rows, not the first three", {
  skip_if_not_installed("lavaan")
  fit <- lavaan::sem("mediator1 ~ treatment\n outcome ~ treatment + mediator1",
                     data = mediation_demo)
  med <- extract_mediation(fit, treatment = "treatment", mediator = "mediator1",
                           outcome = "outcome")
  expect_no_warning(ci <- confint(med))
  z <- stats::qnorm(0.975)
  se <- (ci[, 2] - ci[, 1]) / (2 * z)
  expect_equal(unname(se), unname(sqrt(diag(med@vcov))[c("a", "b", "c_prime")]))
})

# Strip every row name, so no class's path rows can be found by name
strip_names <- function(obj) {
  S7::set_props(obj, estimates = unname(obj@estimates), vcov = unname(obj@vcov))
}

demo_formula <- function(lhs_rhs) {
  stats::as.formula(paste(lhs_rhs, "+ covariate1 + covariate2"))
}

test_that("serial paths without named rows error rather than return NA", {
  obj <- extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1 + mediator2"),
                 data = mediation_demo),
    treatment = "treatment", mediator = c("mediator1", "mediator2"),
    mediator_models = list(lm(demo_formula("mediator2 ~ treatment + mediator1"),
                              data = mediation_demo))
  )
  expect_false(anyNA(confint(obj)))
  expect_error(confint(strip_names(obj)), "vcov has no row for path: a, d1, b, c_prime")
})

test_that("parallel paths without named rows error rather than return NA", {
  obj <- extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome ~ treatment + mediator1 + mediator3"),
                 data = mediation_demo),
    treatment = "treatment", mediator = c("mediator1", "mediator3"),
    mediator_models = list(lm(demo_formula("mediator3 ~ treatment"), data = mediation_demo))
  )
  expect_false(anyNA(confint(obj)))
  expect_error(confint(strip_names(obj)), "vcov has no row for path: a1")
})

test_that("interaction paths without named rows error rather than return NA", {
  obj <- extract_mediation(
    lm(demo_formula("mediator1 ~ treatment"), data = mediation_demo),
    model_y = lm(demo_formula("outcome_int ~ treatment * mediator1"), data = mediation_demo),
    treatment = "treatment", mediator = "mediator1"
  )
  expect_false(anyNA(confint(obj, parm = "paths")))
  expect_error(confint(strip_names(obj), parm = "paths"),
               "vcov has no row for path: a, b, c_prime, theta3")
})
