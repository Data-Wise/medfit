# V8: plumbing and visibility (spec S6, S9): fit_mediation, zero-product branches, the MBCO refit.

test_that("fit_mediation(engine = 'native') passes fixed_x through engine_args and keeps the default FALSE", {
  args <- list(model = fx_syntax, data = fx_data(), treatment = "treatment", mediator = "mediator1",
               engine = "native")
  off <- do.call(fit_mediation, args)
  on <- do.call(fit_mediation, c(args, list(engine_args = list(fixed_x = TRUE))))
  expect_equal(c(on@a_path, on@b_path, on@c_prime), c(off@a_path, off@b_path, off@c_prime), tolerance = 1e-6)
  expect_lt(nrow(on@vcov), nrow(off@vcov))
  expect_error(do.call(fit_mediation, c(args, list(engine_args = list(fixed_x = "outcome")))),
               "not exogenous observed variables")
})

test_that("zero-product branches and the MBCO refit keep fixed_x", {
  d <- fx_data()
  fit <- fit_sem(paste0(fx_syntax, "\na*b == 0"), d, fixed_x = TRUE)
  expect_setequal(fit@internals$fixed_x, fx_exo)
  # build the fits first: a mock installed earlier would record fit_sem()'s own call and pass vacuously
  subset_fit <- fit_sem(fx_syntax, d, fixed_x = "covariate1")
  free_fit <- fit_sem(fx_syntax, d)
  seen <- list()
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    seen[[length(seen) + 1L]] <<- list(...)$fixed_x
    stop("stop after capturing")
  })
  try(mbco_sem(subset_fit, "a", "b"), silent = TRUE)
  expect_true(length(seen) > 0L && all(vapply(seen, identical, TRUE, "covariate1")))
  seen <- list()
  try(mbco_sem(free_fit, "a", "b"), silent = TRUE)
  expect_true(length(seen) > 0L && all(vapply(seen, isFALSE, TRUE)))
})

test_that("planted defect: an MBCO refit that drops fixed_x is caught", {
  fx_skip_covr()
  subset_fit <- fit_sem(fx_syntax, fx_data(), fixed_x = "covariate1")
  bad <- sem_mutate(mbco_sem, "fixed_x = fixed_x)", "fixed_x = FALSE)")
  seen <- list()
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    seen[[length(seen) + 1L]] <<- list(...)$fixed_x
    stop("stop after capturing")
  })
  try(bad(subset_fit, "a", "b"), silent = TRUE)
  expect_true(length(seen) > 0L && !any(vapply(seen, identical, TRUE, "covariate1")))
})

test_that("tidy and summary list the fixed rows, flagged, with no standard error", {
  fixed <- fit_sem(fx_syntax, fx_data(), fixed_x = "covariate1")
  td <- tidy(fixed)
  expect_true("fixed_x" %in% names(td))
  expect_true(all(td$fixed_x[td$term == "covariate1~~covariate1"]))
  expect_true(is.na(td$std_error[td$term == "covariate1~~covariate1"]))
  expect_false(any(td$fixed_x[td$term == "a"]))
  expect_false("covariate1~~covariate1" %in% names(coef(fixed)))
  expect_false("covariate1~~covariate1" %in% rownames(vcov(fixed)))
})
