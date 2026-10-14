# V2: fixed_x = TRUE end to end, covariance-only (spec S2, S3, S6). Run the frozen gate after edits.

test_that("estimates, standard errors and df equal the free fit; the fixed moments leave the parameters", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  expect_equal(fixed@df, free@df)
  expect_equal(fixed@f, free@f, tolerance = 1e-10)
  sh <- fx_shared(free, fixed)
  expect_gt(length(sh$names), 5L)
  expect_equal(unname(sh$est[[2L]]), unname(sh$est[[1L]]), tolerance = 1e-6)
  expect_equal(unname(sh$se[[2L]]), unname(sh$se[[1L]]), tolerance = 1e-6)
  expect_identical(length(fixed@theta), length(free@theta) - fx_n_removed(fx_exo))
  expect_identical(nrow(vcov(fixed)), length(fixed@theta))
  expect_identical(length(coef(fixed)), length(fixed@theta))
  expect_identical(glance(fixed)$npar, glance(free)$npar - fx_n_removed(fx_exo))
  expect_equal(glance(fixed)$df, glance(free)$df)
})

test_that("fixed rows stay in the table at the sample moments with no standard error (S6)", {
  d <- fx_data()
  fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE)
  tab <- fixed@table
  rows <- tab[tab$fixed_x, ]
  expect_identical(nrow(rows), as.integer(fx_n_removed(fx_exo)))
  expect_false(any(rows$free))
  expect_true(all(is.na(rows$se)))
  v <- rows[rows$lhs == "covariate1" & rows$op == "~~" & rows$rhs == "covariate1", ]
  expect_equal(v$est, mean((d$covariate1 - mean(d$covariate1))^2), tolerance = 1e-12)
  cv <- rows[rows$lhs == "treatment" & rows$op == "~~" & rows$rhs == "covariate1", ]
  expect_equal(cv$est, mean((d$treatment - mean(d$treatment)) * (d$covariate1 - mean(d$covariate1))),
               tolerance = 1e-12)
  td <- tidy(fixed)
  expect_true(all(c("treatment~~treatment") %in% td$term))
  expect_true(is.na(td$std_error[td$term == "treatment~~treatment"]))
})

test_that("the frozen 0.9.0 values are untouched when fixed_x is off", {
  # the T1 fixture itself runs in test-sem-frozen-v080.R; this guards the new column and internals only
  fit <- fit_sem(fx_syntax, fx_data())
  expect_true("fixed_x" %in% names(fit@table))
  expect_false(any(fit@table$fixed_x))
})

test_that("lavaan fixed.x = TRUE agrees: rows, parameter count, df and chi-square", {
  skip_if_not_installed("lavaan")
  d <- fx_data()
  fixed <- fit_sem(fx_syntax, d, fixed_x = TRUE, information = "expected")
  ref <- lavaan::sem(fx_syntax, d, fixed.x = TRUE)
  expect_identical(length(fixed@theta), as.integer(lavaan::fitMeasures(ref, "npar")))
  expect_equal(fixed@df, unname(lavaan::fitMeasures(ref, "df")))
  expect_equal(unname(fixed@f * fixed@n_obs), unname(lavaan::fitMeasures(ref, "chisq")), tolerance = 1e-5)
  pe <- lavaan::parameterEstimates(ref)
  lab <- intersect(pe$label[nzchar(pe$label)], names(fixed@theta))
  expect_equal(unname(fixed@theta[lab]), pe$est[match(lab, pe$label)], tolerance = 1e-4)
  expect_equal(unname(sqrt(diag(fixed@vcov))[lab]), pe$se[match(lab, pe$label)], tolerance = 1e-3)
})

test_that("planted defect: counting the fixed moments as restrictions moves df", {
  fixed <- fit_sem(fx_syntax, fx_data(), fixed_x = TRUE)
  free <- fit_sem(fx_syntax, fx_data())
  ram <- fixed@internals$ram
  expect_identical(.sem_df(ram, 0L), free@df)
  # the moment count ignores the fixed block, so df grows by the number fixed
  bad <- sem_mutate(.sem_moments, "(ram$n_fixed_x %||% 0L)", "0L")
  testthat::local_mocked_bindings(.sem_moments = bad)
  expect_equal(.sem_df(ram, 0L), free@df + fx_n_removed(fx_exo))
})
