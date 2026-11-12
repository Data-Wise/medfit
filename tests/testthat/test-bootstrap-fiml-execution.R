execution_record <- function(i, status, reason = NULL) list(id = i, status = status, reason = reason)
execution_value <- function(i) list(value = as.numeric(i), record = execution_record(i, "accepted"))
execution_interrupt <- function() {
  stop(structure(list(message = "synthetic interrupt", call = NULL), class = c("interrupt", "condition")))
}

test_that("sequential interruption retains completed and unattempted requested IDs", {
  run <- function(i) {
    if (i == 2L) execution_interrupt()
    execution_value(i)
  }
  out <- .bootstrap_fiml_execute(3L, run, execution_record, FALSE, 1L)
  expect_identical(vapply(out, `[[`, numeric(1), "value"), c(1, NA_real_, NA_real_))
  expect_identical(vapply(out, function(x) x$record$status, character(1)),
                   c("accepted", "interrupted", "unattempted"))
  expect_identical(vapply(out, function(x) x$record$id, integer(1)), 1:3)
})

test_that("parallel child interruption stops subsequent batches and retains completed siblings", {
  skip_on_os("windows")
  run <- function(i) {
    if (i == 2L) return(list(value = NA_real_, record = execution_record(i, "interrupted", "synthetic")))
    execution_value(i)
  }
  out <- .bootstrap_fiml_execute(3L, run, execution_record, TRUE, 2L)
  expect_identical(vapply(out, `[[`, numeric(1), "value"), c(1, NA_real_, NA_real_))
  expect_identical(vapply(out, function(x) x$record$status, character(1)),
                   c("accepted", "interrupted", "unattempted"))
})

test_that("parent interruption keeps prior parallel batches and marks unavailable active IDs", {
  skip_on_os("windows")
  invocation <- 0L
  testthat::local_mocked_bindings(mclapply = function(X, FUN, ...) {
    invocation <<- invocation + 1L
    if (invocation == 2L) execution_interrupt()
    lapply(X, FUN)
  }, .package = "parallel")
  out <- .bootstrap_fiml_execute(6L, execution_value, execution_record, TRUE, 2L)
  expect_identical(vapply(out, `[[`, numeric(1), "value"), c(1, 2, rep(NA_real_, 4L)))
  expect_identical(vapply(out, function(x) x$record$status, character(1)),
                   c("accepted", "accepted", "interrupted", "interrupted", "unattempted", "unattempted"))
  expect_identical(invocation, 2L)
})

test_that("uninterrupted sequential and parallel execution preserve exact values and order", {
  sequential <- .bootstrap_fiml_execute(5L, execution_value, execution_record, FALSE, 1L)
  parallel <- .bootstrap_fiml_execute(5L, execution_value, execution_record, TRUE, 2L)
  expect_identical(parallel, sequential)
})

test_that("default parallel core selection honors the detected spare-core count", {
  skip_on_os("windows")
  observed <- integer()
  testthat::local_mocked_bindings(detectCores = function(...) 3L, mclapply = function(X, FUN, mc.cores, ...) {
    observed <<- c(observed, mc.cores)
    lapply(X, FUN)
  }, .package = "parallel")
  out <- .bootstrap_fiml_execute(5L, execution_value, execution_record, TRUE, NULL)
  expect_identical(observed, rep(2L, 3L))
  expect_identical(vapply(out, `[[`, numeric(1), "value"), as.numeric(1:5))
})
