skip_if_not_installed("lavaan")

# mbco_sem() and compare_lr() refit the model without `cluster`; on a native
# two-level fit that refit reached the single-level guard and reported that
# native two-level estimation "is not implemented yet", which has been false
# since S4a. Both functions now refuse up front with a classed error.

tlr_fit <- function() {
  fit_sem(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41), cluster = "cluster")
}

test_that("mbco_sem() refuses a native two-level fit with a classed error", {
  fit <- tlr_fit()
  err <- expect_error(mbco_sem(fit, "a_w", "b_w"),
                      class = "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "mbco_sem()", fixed = TRUE)
  expect_match(conditionMessage(err), "two-level", fixed = TRUE)
  expect_no_match(conditionMessage(err), "not implemented yet", fixed = TRUE)
  expect_false(inherits(err, "medfit_error_twolevel_not_implemented"))
})

test_that("compare_lr() refuses a native two-level fit with a classed error", {
  fit <- tlr_fit()
  err <- expect_error(compare_lr(fit, c("a_w", "b_w")),
                      class = "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "compare_lr()", fixed = TRUE)
  expect_no_match(conditionMessage(err), "not implemented yet", fixed = TRUE)
})
