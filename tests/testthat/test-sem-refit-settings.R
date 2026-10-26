# R-6 (native-defaults spec): an internal refit passes the parent fit's settings explicitly, so it never depends on
# `.sem_fit_syntax()`'s own defaults. 0.15.0 changes the user-facing defaults of `fit_sem()`; a refit that left a
# setting unset would then fit a different likelihood than its parent. Refit sites (inventory 2026-10-24): the MBCO
# refit in `mbco_sem()` and the zero-product branch fits in `.sem_fit_branches()`. `anova()` never refits, and
# `compare_lr()` refits only in lavaan and OpenMx. The `fixed_x` half of the MBCO refit is covered by
# `test-sem-fixed-x-plumbing.R`; this file covers `meanstructure` and the branch fits.

rs_syntax <- "mediator1 ~ a*treatment + covariate1\noutcome ~ b*mediator1 + cp*treatment + covariate1"

# A parent fit without a mean structure: the 0.15.0 default fits one, so these tests ask for the covariance-only
# likelihood with `meanstructure = NULL` (no `~1` in the syntax), which is what makes FALSE differ from NULL here.
rs_fit_no_mean <- function() fit_sem(rs_syntax, mediation_demo, meanstructure = NULL, fixed_x = FALSE)

# The settings `mbco_sem()` hands to each refit. Build the parent fit before the mock is installed: a mock installed
# earlier would record fit_sem()'s own call and pass vacuously.
rs_mbco_settings <- function(fit, fn = mbco_sem) {
  seen <- list()
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) {
    args <- list(...)
    seen[[length(seen) + 1L]] <<- list(meanstructure = args$meanstructure, fixed_x = args$fixed_x)
    stop("stop after capturing")
  })
  try(fn(fit, "a", "b"), silent = TRUE)
  seen
}

test_that("the MBCO refit of a fit without a mean structure passes meanstructure = FALSE, not NULL", {
  fit <- rs_fit_no_mean()
  expect_false(isTRUE(fit@internals$ram$has_mean))
  seen <- rs_mbco_settings(fit)
  expect_gt(length(seen), 0L)
  expect_true(all(vapply(seen, function(s) identical(s$meanstructure, FALSE), logical(1))))
})

test_that("the MBCO refit of a default fit (0.15.0: mean structure on) passes meanstructure = TRUE", {
  fit <- fit_sem(rs_syntax, mediation_demo)
  expect_true(isTRUE(fit@internals$ram$has_mean))
  seen <- rs_mbco_settings(fit)
  expect_gt(length(seen), 0L)
  expect_true(all(vapply(seen, function(s) identical(s$meanstructure, TRUE), logical(1))))
})

test_that("the MBCO refit of a named-subset fit passes the same subset and the mean setting", {
  fit <- fit_sem(rs_syntax, mediation_demo, fixed_x = "covariate1", meanstructure = TRUE)
  seen <- rs_mbco_settings(fit)
  expect_gt(length(seen), 0L)
  expect_true(all(vapply(seen, function(s) identical(s$fixed_x, "covariate1") && isTRUE(s$meanstructure),
                         logical(1))))
})

test_that("the MBCO statistic is the same whether the no-mean refit is told FALSE or left to the syntax", {
  # known answer: for a no-mean parent, FALSE and NULL describe the same likelihood, so the explicit setting
  # changes no number today; it only stops the refit from following a future default
  fit <- rs_fit_no_mean()
  explicit <- mbco_sem(fit, "a", "b")
  implicit <- sem_mutate(mbco_sem, "meanstructure = isTRUE(fit@internals$ram$has_mean)",
                         "meanstructure = if (isTRUE(fit@internals$ram$has_mean)) TRUE")(fit, "a", "b")
  expect_equal(explicit$statistic, implicit$statistic, tolerance = 1e-10)
})

test_that("planted defect: an MBCO refit that leaves meanstructure unset is caught", {
  fx_skip_covr()
  fit <- rs_fit_no_mean()
  bad <- sem_mutate(mbco_sem, "meanstructure = isTRUE(fit@internals$ram$has_mean)",
                    "meanstructure = if (isTRUE(fit@internals$ram$has_mean)) TRUE")
  seen <- rs_mbco_settings(fit, bad)
  expect_gt(length(seen), 0L)
  expect_false(all(vapply(seen, function(s) identical(s$meanstructure, FALSE), logical(1))))
})

test_that("zero-product branch fits receive the parent's meanstructure and fixed_x", {
  for (case in list(list(ms = TRUE, fx = "covariate1"), list(ms = FALSE, fx = FALSE), list(ms = NULL, fx = TRUE))) {
    seen <- list()
    testthat::local_mocked_bindings(.sem_fit_branches = function(...) {
      args <- list(...)
      seen[[length(seen) + 1L]] <<- list(meanstructure = args$meanstructure, fixed_x = args$fixed_x)
      stop("stop after capturing")
    })
    try(fit_sem(paste0(rs_syntax, "\na*b == 0"), mediation_demo, meanstructure = case$ms, fixed_x = case$fx),
        silent = TRUE)
    expect_length(seen, 1L)
    # the branches get the parent's settings as given; `TRUE` is resolved to names later, in completion
    expect_identical(seen[[1]]$meanstructure, case$ms)
    expect_identical(seen[[1]]$fixed_x, case$fx)
  }
})
