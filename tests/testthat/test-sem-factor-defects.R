# T9: planted defects for the factor-covariate pre-pass. Each mutation rebuilds one internal function with a single
# source pattern changed (`sem_mutate()` insists the pattern matches once). Every case first shows the unmutated code
# passes the check, so the check is not vacuous, then shows the defect fails it. The check is the one a reviewer
# would run: the fit equals the hand-coded twin, or the model is refused.

fd_data <- function(n = 160L, seed = 17L) {
  set.seed(seed)
  g <- factor(sample(c("a", "b", "c"), n, replace = TRUE))
  x <- rnorm(n)
  m <- 0.5 * x + 0.5 * (g == "b") + rnorm(n)
  y <- 0.4 * m + 0.3 * (g == "c") + rnorm(n)
  data.frame(y = y, m = m, x = x, g = g)
}
fd_twin <- function(d) {
  d$g_b <- as.numeric(d$g == "b")
  d$g_c <- as.numeric(d$g == "c")
  d
}
fd_model <- "m ~ x + g\ny ~ m + g"
fd_twin_model <- "m ~ x + g_b + g_c\ny ~ m + g_b + g_c"

# TRUE when the factor model fits and equals the twin (names, estimates, rows used); an error or a mismatch is FALSE.
fd_equals_twin <- function(d = fd_data()) {
  ok <- tryCatch({
    f <- fit_sem(fd_model, d)
    ft <- fit_sem(fd_twin_model, fd_twin(d))
    f@n_obs == ft@n_obs &&
      identical(f@table$rhs, ft@table$rhs) &&
      isTRUE(all.equal(unname(f@table$est), unname(ft@table$est), tolerance = 1e-8))
  }, error = function(e) FALSE)
  isTRUE(ok)
}

test_that("the check passes on the real code (the defect tests below are not vacuous)", {
  expect_true(fd_equals_twin())
  d <- fd_data()
  d$g[c(4, 50)] <- NA
  expect_true(fd_equals_twin(d))
})

test_that("planted: the wrong reference level is caught", {
  fx_skip_covr()
  bad <- sem_mutate(.sem_factor_dummy_names, "info$levels[-1L]", "info$levels[-length(info$levels)]")
  testthat::local_mocked_bindings(.sem_factor_dummy_names = bad)
  expect_false(fd_equals_twin())
})

test_that("planted: dummies that turn an NA factor into 0 (rows no longer dropped) are caught", {
  fx_skip_covr()
  d <- fd_data()
  d$g[c(4, 50)] <- NA
  bad <- sem_mutate(.sem_add_dummies, "as.numeric(x == info$levels[match(d, info$all) + 1L])",
                    "as.numeric(x %in% info$levels[match(d, info$all) + 1L])")
  testthat::local_mocked_bindings(.sem_add_dummies = bad)
  expect_false(fd_equals_twin(d))
})

test_that("planted: a label accepted on a bare factor is caught", {
  fx_skip_covr()
  d <- fd_data()
  expect_error(fit_sem("y ~ m + b*g", d), "expands to 2 terms")
  bad <- sem_mutate(.sem_check_factor_modifiers, "nzchar(r$label) ||", "FALSE ||")
  testthat::local_mocked_bindings(.sem_check_factor_modifiers = bad)
  # the defect lets the labeled bare factor through, so the refusal the real code gives is gone
  expect_no_error(fit_sem("y ~ m + b*g", d))
})

test_that("planted: no expansion before completion is caught", {
  fx_skip_covr()
  bad <- sem_mutate(
    .sem_fit_syntax, ".sem_expand_factors(parsed$parameters, data, fixed_x, factors)",
    "list(table = parsed$parameters, data = data, fixed_x = fixed_x, map = list())"
  )
  testthat::local_mocked_bindings(.sem_fit_syntax = bad)
  expect_false(fd_equals_twin())
})

test_that("planted: a refit without the factor map is caught", {
  fx_skip_covr()
  d <- fd_data()
  f <- fit_sem("m ~ a*x + g\ny ~ b*m + g", d)
  r <- mbco_sem(f, paths = c("a", "b"))
  expect_true(is.finite(r$statistic))
  bad <- sem_mutate(mbco_sem, "factors = fit@internals$factors", "factors = NULL")
  testthat::local_mocked_bindings(mbco_sem = bad)
  expect_error(mbco_sem(f, paths = c("a", "b")))
})
