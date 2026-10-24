# Edge cases for the observed-variable guard in multi-fit AIC()/BIC() (R/methods-aic.R, `.sem_check_same_observed()`).
# Oracle: the guard compares each fit's observed variables; fits over the same set compare, any other set is refused.

# the pre-0.15.0 defaults stated (spec R-8); a test may set its own `fixed_x`
ic_fit <- function(model, fixed_x = FALSE, meanstructure = NULL) {
  suppressWarnings(fit_sem(model, medfit::mediation_demo, fixed_x = fixed_x, meanstructure = meanstructure))
}

ic_base <- "mediator1 ~ treatment + covariate1\noutcome ~ treatment + mediator1"

test_that("a single fit is never refused, and k and BIC behave as before", {
  f <- ic_fit(ic_base)
  expect_no_error(stats::AIC(f))
  expect_no_error(stats::BIC(f))
  expect_equal(stats::AIC(f, k = 3), stats::AIC(stats::logLik(f), k = 3))
})

test_that("the third fit is checked too, and the message names every fit's variables", {
  a <- ic_fit(ic_base)
  b <- ic_fit(paste0(ic_base, "\noutcome ~ covariate1"))
  with_x <- ic_fit(paste0(ic_base, " + treatment:mediator1"))
  expect_no_error(stats::AIC(a, b))
  expect_error(stats::AIC(a, b, with_x), "different observed variables")
  err <- tryCatch(stats::AIC(a, b, with_x), error = conditionMessage)
  expect_match(err, "a: ", fixed = TRUE)
  expect_match(err, "with_x: ", fixed = TRUE)
  expect_match(err, "mediator1:treatment", fixed = TRUE)
})

test_that("the order of the fits does not matter, for AIC and for BIC", {
  without <- ic_fit(ic_base)
  with_x <- ic_fit(paste0(ic_base, " + treatment:mediator1"))
  for (f in list(stats::AIC, stats::BIC)) {
    expect_error(f(with_x, without), "different observed variables")
    expect_error(f(without, with_x), "different observed variables")
  }
})

test_that("the two spellings of one product are the same observed variable, so such fits compare", {
  xm <- ic_fit(paste0(ic_base, " + treatment:mediator1"))
  mx <- ic_fit(paste0(ic_base, " + mediator1:treatment"))
  out <- stats::AIC(xm, mx)
  expect_equal(out$AIC[1], out$AIC[2], tolerance = 1e-8)
  expect_equal(out$df[1], out$df[2])
})

test_that("the order of the variables in the syntax does not change the observed set", {
  a <- ic_fit("mediator1 ~ treatment + covariate1\noutcome ~ treatment + mediator1")
  b <- ic_fit("outcome ~ mediator1 + treatment\nmediator1 ~ covariate1 + treatment")
  out <- stats::AIC(a, b)
  expect_equal(out$AIC[1], out$AIC[2], tolerance = 1e-6)
})

test_that("a different product over other variables is refused, and so is a plain extra covariate", {
  with_x <- ic_fit(paste0(ic_base, " + treatment:mediator1"))
  with_c <- ic_fit(paste0(ic_base, " + treatment:covariate1"))
  expect_error(stats::AIC(with_x, with_c), "different observed variables")
  plain <- ic_fit(paste0(ic_base, " + covariate2"))
  expect_error(stats::BIC(ic_fit(ic_base), plain), "covariate2")
})

test_that("the observed-variable refusal comes before the fixed_x refusal when both apply", {
  free <- ic_fit(ic_base)
  fixed_product <- ic_fit(paste0(ic_base, " + treatment:mediator1"), fixed_x = TRUE)
  expect_error(stats::AIC(free, fixed_product), "different observed variables")
  # same observed variables, different fixed sets: the older refusal still fires
  expect_error(stats::AIC(free, ic_fit(ic_base, fixed_x = TRUE)), "different `fixed_x` sets")
})

test_that("a SEMFit with fixed_x still cannot be compared with a model of another class", {
  fixed <- ic_fit(ic_base, fixed_x = TRUE)
  expect_error(stats::AIC(fixed, stats::lm(outcome ~ treatment, medfit::mediation_demo)), "another class")
})

test_that("planted: a guard that only checks the first and last fit misses a differing middle fit", {
  fx_skip_covr()
  a <- ic_fit(ic_base)
  with_x <- ic_fit(paste0(ic_base, " + treatment:mediator1"))
  a2 <- ic_fit(ic_base)
  mutated <- sem_mutate(.sem_check_same_observed, "obs[-1L]", "obs[length(obs)]")
  local_mocked_bindings(.sem_check_same_observed = mutated)
  expect_no_error(stats::AIC(a, with_x, a2))
})

test_that("with the real guard the same three-fit call is refused", {
  a <- ic_fit(ic_base)
  with_x <- ic_fit(paste0(ic_base, " + treatment:mediator1"))
  a2 <- ic_fit(ic_base)
  expect_error(stats::AIC(a, with_x, a2), "different observed variables")
})
