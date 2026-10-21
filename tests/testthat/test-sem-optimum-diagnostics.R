optimum_data <- function() {
  set.seed(3)
  x <- stats::rnorm(300)
  m <- 0.5 * x + stats::rnorm(300, sd = 0.8)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(300, sd = 0.7)
  data.frame(X = x, M = m, Y = y)
}

optimum_model <- "M ~ a*X\nY ~ b*M + cp*X"

test_that("ordinary and feasible-reference fits report their optimum verdict", {
  d <- optimum_data()
  ordinary <- fit_sem(optimum_model, d)
  o <- ordinary@diagnostics$optimum
  expect_identical(o$status, "unique")
  expect_false(o$best_of)
  expect_false(o$certified)
  expect_identical(o$n_starts, 1L)
  expect_identical(o$n_accepted, 1L)
  expect_true(is.na(o$spread))
  expect_false(any(grepl("Optimum:", capture.output(summary(ordinary)), fixed = TRUE)))

  certified <- fit_sem(paste0(optimum_model, "\na*b > 0.01"), d)
  o <- certified@diagnostics$optimum
  expect_identical(o$status, "certified")
  expect_true(o$best_of)
  expect_true(o$certified)
  expect_gte(o$n_starts, 5L)
  expect_gte(o$n_accepted, 1L)
  expect_lte(o$n_accepted, o$n_starts)  # a reference appended after the starts is not a start
  expect_false(any(grepl("Optimum:", capture.output(summary(certified)), fixed = TRUE)))
})

test_that("disagreeing starts report the spread and print the verdict", {
  d <- optimum_data()
  model <- paste0(optimum_model, "\na*b > 0.4")
  expect_warning(fit <- fit_sem(model, d), "the starts disagree")
  o <- fit@diagnostics$optimum
  expect_identical(o$status, "disagreed")
  expect_true(o$best_of)
  expect_false(o$certified)
  expect_gte(o$n_accepted, 2L)
  expect_lte(o$n_accepted, o$n_starts)  # a reference appended after the starts is not a start
  expect_gt(o$spread, .sem_spread_tol)
  expect_true(any(grepl(sprintf("Optimum: disagreed (%d of %d starts accepted)",
                                o$n_accepted, o$n_starts), capture.output(summary(fit)), fixed = TRUE)))

  testthat::local_mocked_bindings(.sem_optimize = sem_mutate(.sem_optimize, '"disagreed"', '"agreed"'))
  mutant <- suppressWarnings(fit_sem(model, d))
  expect_false(identical(mutant@diagnostics$optimum$status, o$status))
})

test_that("one accepted start is reported and printed", {
  d <- optimum_data()
  real_gate <- .sem_gate
  calls <- 0L
  testthat::local_mocked_bindings(.sem_gate = function(...) {
    calls <<- calls + 1L
    g <- real_gate(...)
    if (!calls %in% c(1L, 3L, 4L)) g$accepted <- FALSE
    g
  })
  expect_warning(fit <- fit_sem(paste0(optimum_model, "\na*b == 0.1"), d),
                 "only 1 of .* starts reached an accepted solution")
  o <- fit@diagnostics$optimum
  expect_identical(o$status, "single")
  expect_true(o$best_of)
  expect_false(o$certified)
  expect_identical(o$n_accepted, 1L)
  expect_gt(o$n_starts, 1L)
  expect_true(is.na(o$spread))
  expect_true(any(grepl(sprintf("Optimum: single (1 of %d starts accepted)", o$n_starts),
                        capture.output(summary(fit)), fixed = TRUE)))
})
