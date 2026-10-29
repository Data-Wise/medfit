# A nonlinear-constraint fit tries every start and keeps the best accepted one; with exactly one accepted start the
# "starts disagree" rule has nothing to compare, and the fit used to be returned silently although it may be the
# wrong branch (found on a Linux runner with the reference BLAS: the #213 floor fixture accepted one wrong-branch
# optimum, LR 3685 against 936). It now warns.

nl_data <- function() {
  set.seed(11)
  n <- 300
  x <- stats::rnorm(n)
  m <- 0.5 * x + stats::rnorm(n)
  y <- 0.4 * m + 0.2 * x + stats::rnorm(n)
  data.frame(x = x, m = m, y = y)
}
nl_model <- "m ~ a*x\ny ~ b*m + cp*x\na*b == 0.1"

test_that("a single accepted start among several is flagged", {
  # This unit test isolates local-search warnings; sign coverage is tested separately.
  local_mocked_bindings(.sem_nonzero_product = function(...) list(supported = FALSE, reason = "test_local"))
  d <- nl_data()
  real_gate <- .sem_gate
  calls <- 0L
  # accept the gate verdict of exactly one start: call 1 is the reference fit, call 3 the second start and call 4 the
  # polish re-check of that start (an accepted start is polished and gated again)
  testthat::local_mocked_bindings(
    .sem_gate = function(...) {
      calls <<- calls + 1L
      g <- real_gate(...)
      if (!calls %in% c(1L, 3L, 4L)) g$accepted <- FALSE
      g
    }
  )
  warns <- character()
  suppressMessages(tryCatch(
    withCallingHandlers(fit_sem(nl_model, d, n_starts = 5), warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }),
    error = function(e) NULL
  ))
  expect_true(any(grepl("^only 1 of [0-9]+ starts reached an accepted solution", warns)),
              info = paste(warns, collapse = " | "))
})

test_that("an ordinary nonlinear fit does not raise the single-start warning", {
  d <- nl_data()
  warns <- character()
  fit <- withCallingHandlers(fit_sem(nl_model, d, n_starts = 5), warning = function(w) {
    warns <<- c(warns, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_s3_class(fit, "S7_object")
  expect_false(any(grepl("starts reached an accepted solution", warns)), info = paste(warns, collapse = " | "))
})
