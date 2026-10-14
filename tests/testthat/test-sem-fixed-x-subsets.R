# V3: subsets and the pairing rule (spec S1, S4). Every subset leaves the structural fit unchanged.

fx_subsets <- list("treatment", "covariate1", "covariate2", c("treatment", "covariate1"),
                   c("treatment", "covariate2"), c("covariate1", "covariate2"), fx_exo)

test_that("every subset of the exogenous variables equals the free fit", {
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  for (sel in fx_subsets) {
    fixed <- fit_sem(fx_syntax, d, fixed_x = sel)
    tag <- paste(sel, collapse = ",")
    expect_equal(fixed@df, free@df, info = tag)
    expect_identical(length(fixed@theta), length(free@theta) - fx_n_removed(sel), info = tag)
    sh <- fx_shared(free, fixed)
    expect_equal(unname(sh$est[[2L]]), unname(sh$est[[1L]]), tolerance = 1e-6, info = tag)
    expect_equal(unname(sh$se[[2L]]), unname(sh$se[[1L]]), tolerance = 1e-6, info = tag)
  }
})

test_that("a pair among the unselected variables stays free even when an explicit statement names a selected one", {
  d <- fx_data()
  # `covariate1 ~~ covariate2` is not allowed with covariate1 selected (S5), so select treatment only; the
  # explicit statement on covariate1 must not make the engine drop its other free pairs (T-2)
  syn <- paste0(fx_syntax, "\ncovariate1 ~~ v*covariate1")
  fixed <- fit_sem(syn, d, fixed_x = "treatment")
  free <- fit_sem(syn, d)
  pair <- fixed@table$op == "~~" & ((fixed@table$lhs == "covariate2" & fixed@table$rhs == "treatment") |
                                      (fixed@table$lhs == "treatment" & fixed@table$rhs == "covariate2"))
  expect_true(any(pair))
  keep <- fixed@table[fixed@table$free & fixed@table$op == "~~" & fixed@table$lhs != fixed@table$rhs &
                        fixed@table$lhs %in% c("covariate1", "covariate2") &
                        fixed@table$rhs %in% c("covariate1", "covariate2"), ]
  expect_identical(nrow(keep), as.integer(sum(free@table$free & free@table$op == "~~" &
                                                free@table$lhs %in% c("covariate1", "covariate2") &
                                                free@table$rhs %in% c("covariate1", "covariate2") &
                                                free@table$lhs != free@table$rhs)))
  expect_equal(fixed@df, free@df)
})

test_that("a precomputed product column is an ordinary exogenous variable and can be selected by name", {
  d <- fx_data()
  d$tm <- d$treatment * d$mediator1
  syn <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment + tm"
  free <- fit_sem(syn, d)
  all_x <- fit_sem(syn, d, fixed_x = TRUE)
  expect_setequal(all_x@internals$fixed_x, c("treatment", "tm"))
  only_tm <- fit_sem(syn, d, fixed_x = "tm")
  expect_identical(only_tm@internals$fixed_x, "tm")
  for (fit in list(all_x, only_tm)) {
    expect_equal(fit@df, free@df)
    sh <- fx_shared(free, fit, exo = c("treatment", "tm"))
    # a product column makes the fit nonlinear in the data: the optimizer's tolerance shows at about 1e-8
    expect_equal(unname(sh$est[[2L]]), unname(sh$est[[1L]]), tolerance = 1e-6)
    expect_equal(unname(sh$se[[2L]]), unname(sh$se[[1L]]), tolerance = 1e-6)
  }
})

test_that("planted defect: dropping the free pairs among unselected variables changes the parameter count", {
  fx_skip_covr()
  d <- fx_data()
  free <- fit_sem(fx_syntax, d)
  fixed <- fit_sem(fx_syntax, d, fixed_x = "treatment")
  expect_equal(fixed@df, free@df)
  bad <- sem_mutate(.sem_complete, "if (r$ov_x[i] %in% paired && r$ov_x[j] %in% paired)", "if (FALSE)")
  testthat::local_mocked_bindings(.sem_complete = bad)
  dropped <- fit_sem(fx_syntax, d, fixed_x = "treatment")
  expect_gt(dropped@df, free@df)
})
