# V4: mean structure and the conditional logLik (spec S7).

test_that("fixed means follow the same rule and df is unchanged with a mean structure", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d, meanstructure = TRUE)
  fixed <- fit_sem(fx_syntax, d, meanstructure = TRUE, fixed_x = TRUE)
  expect_equal(fixed@df, free@df)
  expect_identical(length(fixed@theta), length(free@theta) - fx_n_removed(fx_exo, mean = TRUE))
  mu <- fixed@table[fixed@table$fixed_x & fixed@table$op == "~1", ]
  expect_setequal(mu$lhs, fx_exo)
  expect_equal(mu$est[match("treatment", mu$lhs)], mean(d$treatment), tolerance = 1e-12)
  sh <- fx_shared(free, fixed)
  expect_equal(unname(sh$est[[2L]]), unname(sh$est[[1L]]), tolerance = 1e-8)
  expect_equal(unname(sh$se[[2L]]), unname(sh$se[[1L]]), tolerance = 1e-6)
})

test_that("logLik, AIC and BIC are conditional and equal lavaan's fixed.x = TRUE values", {
  skip_if_not_installed("lavaan")
  d <- fx_data()
  for (ms in c(FALSE, TRUE)) {
    fixed <- fit_sem(fx_syntax, d, meanstructure = ms, fixed_x = TRUE, information = "expected")
    ref <- lavaan::sem(fx_syntax, d, meanstructure = ms, fixed.x = TRUE)
    expect_equal(as.numeric(logLik(fixed)), as.numeric(lavaan::logLik(ref)), tolerance = 1e-6, info = ms)
    expect_equal(AIC(fixed), AIC(ref), tolerance = 1e-6, info = ms)
    expect_equal(BIC(fixed), BIC(ref), tolerance = 1e-6, info = ms)
  }
})

test_that("the conditional logLik differs from the joint one by the exogenous block", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d, meanstructure = TRUE)
  fixed <- fit_sem(fx_syntax, d, meanstructure = TRUE, fixed_x = TRUE)
  expect_gt(as.numeric(logLik(free)), as.numeric(logLik(fixed)))
  expect_equal(attr(logLik(fixed), "df"), glance(fixed)$npar)
})

test_that("glance and the print note say what is fixed, and only when something is", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fixed <- fit_sem(fx_syntax, d, fixed_x = c("treatment", "covariate1"))
  expect_identical(glance(free)$fixed_x, "")
  expect_setequal(strsplit(glance(fixed)$fixed_x, ", ")[[1L]], c("treatment", "covariate1"))
  note <- "logLik is conditional on: "
  expect_false(any(grepl(note, utils::capture.output(print(free)), fixed = TRUE)))
  expect_true(any(grepl(note, utils::capture.output(print(fixed)), fixed = TRUE)))
  expect_true(any(grepl(note, utils::capture.output(print(summary(fixed))), fixed = TRUE)))
})

test_that("planted defect: a joint logLik for a fixed_x fit is caught by the lavaan comparison", {
  skip_if_not_installed("lavaan")
  d <- fx_data()
  joint <- fit_sem(fx_syntax, d, meanstructure = TRUE)
  ref <- lavaan::sem(fx_syntax, d, meanstructure = TRUE, fixed.x = TRUE)
  expect_gt(abs(as.numeric(logLik(joint)) - as.numeric(lavaan::logLik(ref))), 1)
})
