test_that("one accepted attempt retains the existing single-status spread and count types", {
  spec <- list(idx = 1:2, ratio = 0.4, labels = c("a", "b"))
  local_mocked_bindings(.sem_optimize = function(...) {
    list(theta = c(a = 1, b = 0.4), f = 1, status = 4L, decrement = 0,
         optimum = list(n_starts = 3L, n_accepted = 1L, certified = FALSE),
         attempts = list(list(accepted = TRUE, f = 1), list(accepted = FALSE, f = 2),
                         list(accepted = FALSE, f = 3)))
  })
  out <- .sem_optimize_signs(NULL, NULL, c(a = 1, b = 0.4), c(0.1, 0), c(Inf, Inf),
                             3L, list(), NULL, spec)
  expect_identical(out$optimum$status, "single")
  expect_identical(out$optimum$n_starts, 3L)
  expect_identical(out$optimum$n_accepted, 1L)
  expect_true(is.na(out$optimum$spread))
  expect_false(out$optimum$certified)
})
