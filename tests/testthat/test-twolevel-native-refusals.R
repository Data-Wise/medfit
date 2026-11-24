skip_if_not_installed("lavaan")

# compare_lr() refit the model without `cluster`; on a native two-level fit that
# refit reached the single-level guard and reported that native two-level
# estimation "is not implemented yet", which has been false since S4a. It now
# refuses up front with a classed error (IG3 D6: two-level compare_lr() is
# deferred). mbco_sem() routes the cluster into its refits (IG3 T-A,
# test-sem-mbco-twolevel.R), so it no longer refuses.

tlr_fit <- function() {
  fit_sem(tl_lavaan_model, tl_simulate(rep(5, 40), seed = 41), cluster = "cluster")
}

test_that("mbco_sem() runs on a native two-level fit instead of refusing it", {
  res <- mbco_sem(tlr_fit(), "a_w", "b_w")
  expect_s3_class(res, "mbco_sem")
  expect_identical(res$level, "within")
  expect_true(is.finite(unname(res$statistic)))
})

test_that("compare_lr() refuses a native two-level fit with a classed error", {
  fit <- tlr_fit()
  err <- expect_error(compare_lr(fit, c("a_w", "b_w")),
                      class = "medfit_error_twolevel_unsupported")
  expect_match(conditionMessage(err), "compare_lr()", fixed = TRUE)
  expect_no_match(conditionMessage(err), "not implemented yet", fixed = TRUE)
})
