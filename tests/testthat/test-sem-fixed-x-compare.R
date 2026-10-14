# V7: comparisons across fixed sets or data are refused (spec S8, grill F-G7).

test_that("anova refuses different fixed sets and different data, and allows the same set", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  restricted <- fit_sem(paste0(fx_syntax, "\ncp == 0"), d, fixed_x = TRUE)
  expect_error(anova(fixed, free), "fixed_x|fixed set|conditional")
  expect_no_error(anova(fixed, restricted))
  d2 <- d
  d2$outcome <- d2$outcome + 1
  other <- fit_sem(paste0(fx_syntax, "\ncp == 0"), d2, fixed_x = TRUE)
  expect_error(anova(fixed, other), "different data")
})

test_that("mbco_sem refits with the fit's fixed set, so its statistic is unchanged", {
  d <- fx_data()
  free <- mbco_sem(fit_sem(fx_syntax, d), "a", "b")
  fixed <- mbco_sem(fit_sem(fx_syntax, d, fixed_x = TRUE), "a", "b")
  expect_equal(unname(fixed$statistic), unname(free$statistic), tolerance = 1e-5)
})

test_that("multi-fit AIC and BIC error across fixed sets or data and name the difference", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fx1 <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  fx2 <- fit_sem(paste0(fx_syntax, "\ncp == 0"), d, fixed_x = TRUE)
  expect_error(AIC(free, fx1), "treatment")
  expect_error(BIC(fx1, free), "fixed")
  d2 <- d
  d2$outcome <- d2$outcome + 1
  expect_error(AIC(fx1, fit_sem(fx_syntax, d2, fixed_x = TRUE)), "data")
  out <- AIC(fx1, fx2)
  expect_identical(nrow(out), 2L)
  expect_no_error(BIC(fx1, fx2))
  expect_no_error(AIC(fx1))
})

test_that("planted defect: AIC across fixed sets must not just return a number", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  expect_error(AIC(fixed, free), "fixed")
  bad <- sem_mutate(.sem_check_comparable, "!all(vapply(sets[-1L], identical, logical(1), sets[[1L]]))", "FALSE")
  testthat::local_mocked_bindings(.sem_check_comparable = bad)
  expect_s3_class(AIC(fixed, free), "data.frame") # the defect: a ranking of incompatible likelihoods
})
