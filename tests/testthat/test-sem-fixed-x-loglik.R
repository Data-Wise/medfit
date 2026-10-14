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
  expect_equal(unname(sh$est[[2L]]), unname(sh$est[[1L]]), tolerance = 1e-6)
  expect_equal(unname(sh$se[[2L]]), unname(sh$se[[1L]]), tolerance = 1e-6)
})

test_that("logLik, AIC and BIC are conditional and equal lavaan's fixed.x = TRUE values", {
  skip_if_not_installed("lavaan")
  d <- fx_data()
  for (ms in c(FALSE, TRUE)) {
    fixed <- fit_sem(fx_syntax, d, meanstructure = ms, fixed_x = TRUE, information = "expected")
    # the likelihood does not depend on the `meanstructure` flag; lavaan counts no mean parameters when it is
    # FALSE, so the reference is always its mean-structure fit (the conditional intercepts are parameters)
    ref <- lavaan::sem(fx_syntax, d, meanstructure = TRUE, fixed.x = TRUE)
    expect_equal(as.numeric(logLik(fixed)), as.numeric(lavaan::logLik(ref)), tolerance = 1e-6, info = as.character(ms))
    expect_equal(AIC(fixed), AIC(ref), tolerance = 1e-6, info = as.character(ms))
    expect_equal(BIC(fixed), BIC(ref), tolerance = 1e-6, info = as.character(ms))
  }
})

test_that("the conditional logLik differs from the joint one by the exogenous block", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d, meanstructure = TRUE)
  fixed <- fit_sem(fx_syntax, d, meanstructure = TRUE, fixed_x = TRUE)
  sx <- stats::cov(d[fx_exo]) * (nrow(d) - 1) / nrow(d)
  llx <- -0.5 * nrow(d) * (log(det(sx)) + length(fx_exo) * (1 + log(2 * pi)))
  expect_equal(as.numeric(logLik(fixed)) - as.numeric(logLik(free)), -llx, tolerance = 1e-8)
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
  fx_skip_covr()
  skip_if_not_installed("lavaan")
  d <- fx_data()
  fixed <- fit_sem(fx_syntax, d, meanstructure = TRUE, fixed_x = TRUE)
  ref <- as.numeric(lavaan::logLik(lavaan::sem(fx_syntax, d, meanstructure = TRUE, fixed.x = TRUE)))
  expect_lt(abs(as.numeric(logLik(fixed)) - ref), 1e-6)
  joint <- sem_mutate(utils::getS3method("logLik", "medfit::SEMFit"), "if (length(fx)) {", "if (FALSE) {")
  expect_gt(abs(as.numeric(joint(fixed)) - ref), 1)
})
