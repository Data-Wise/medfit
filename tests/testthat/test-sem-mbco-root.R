# The MBCO root ledger is validated before mbco_sem() returns: the full fit and one null per tested path, rebuilt.

mbco_root_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

mbco_root_fit <- function(...) {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  suppressMessages(fit_sem(mbco_root_model, data, n_starts = 1L, ...))
}

test_that("a resolved ordinary MBCO root validates, and mutated roots do not", {
  fit <- mbco_root_fit()
  res <- mbco_sem(fit, "a2", "cp", n_starts = 1L)
  root <- res$ledger
  paths <- c("a2", "cp")
  expect_length(root$children, 3L)
  # the generic validator cannot take a root whose children are not zero-product branches
  expect_false(.sem_valid_outcome(root))
  expect_true(.sem_valid_mbco_outcome(root, paths))

  dropped <- root
  dropped$children <- root$children[-3L]
  expect_false(.sem_valid_mbco_outcome(dropped, paths))
  extra <- root
  extra$children[[4L]] <- root$children[[3L]]
  expect_false(.sem_valid_mbco_outcome(extra, paths))
  swapped <- root
  swapped$children[2:3] <- root$children[3:2]
  expect_false(.sem_valid_mbco_outcome(swapped, paths))
  expect_false(.sem_valid_mbco_outcome(root, rev(paths)))
  altered <- root
  altered$children[[2L]]$constraints$rhs <- "1"
  expect_false(.sem_valid_mbco_outcome(altered, paths))
  other <- root
  other$children[[3L]]$context$sample_hash <- "forged"
  expect_false(.sem_valid_mbco_outcome(other, paths))
  own <- root
  own$children[[3L]]$context[["sample"]] <- root$context[["sample"]][-1L, ]
  expect_false(.sem_valid_mbco_outcome(own, paths))
  renamed <- root
  renamed$id <- "fit"
  expect_false(.sem_valid_mbco_outcome(renamed, paths))
  badnull <- root
  badnull$children[[2L]]$id <- "mbco/null:9"
  expect_false(.sem_valid_mbco_outcome(badnull, paths))
  badlik <- root
  badlik$likelihood$f <- root$likelihood$f + 1
  expect_false(.sem_valid_mbco_outcome(badlik, paths))
  badout <- root
  badout$children[[2L]]$outcome <- "unresolved"
  expect_false(.sem_valid_mbco_outcome(badout, paths))
})

test_that("mbco_sem() refuses a root that does not validate, with the ledger error class", {
  fit <- mbco_root_fit()
  testthat::local_mocked_bindings(.sem_valid_mbco_outcome = function(x, paths) FALSE)
  expect_error(mbco_sem(fit, "a2", "cp", n_starts = 1L), "malformed MBCO outcome ledger",
               class = "medfit_error_ledger")
})

test_that("an unresolved MBCO root validates", {
  fit <- mbco_root_fit()
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    if (!is.null(model) && endsWith(model, "\na2 == 0")) {
      stop(.sem_no_convergence("injected null failure"))
    }
    real(model, ...)
  })
  res <- suppressWarnings(mbco_sem(fit, "a2", "cp", n_starts = 1L))
  expect_true(res$unresolved)
  expect_identical(res$ledger$outcome, "unresolved")
  expect_identical(res$ledger$children[[2L]]$outcome, "unresolved")
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a2", "cp")))
  forged <- res$ledger
  forged$outcome <- "resolved"
  expect_false(.sem_valid_mbco_outcome(forged, c("a2", "cp")))
  # a failed null on other rows is not the null that was asked for
  other <- res$ledger
  other$children[[2L]]$context$sample_hash <- "forged"
  expect_false(.sem_valid_mbco_outcome(other, c("a2", "cp")))
  moved <- res$ledger
  moved$children[[2L]]$constraints$lhs <- "cp"
  expect_false(.sem_valid_mbco_outcome(moved, c("a2", "cp")))
})

test_that("a retained covariance-failed null validates", {
  fit <- mbco_root_fit(information = "expected")
  vcov <- .sem_vcov
  calls <- 0L
  testthat::local_mocked_bindings(.sem_vcov = function(...) {
    calls <<- calls + 1L
    if (calls == 1L) stop("injected null covariance failure")
    vcov(...)
  })
  expect_warning(res <- mbco_sem(fit, "a1", "b1"), "likelihood retained")
  node <- res$ledger$children[[2L]]
  expect_identical(node$covariance, "failed")
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a1", "b1")))
  forged <- res$ledger
  forged$children[[2L]]$post_fit <- NULL
  expect_false(.sem_valid_mbco_outcome(forged, c("a1", "b1")))
})

test_that("explicit n_starts and control overrides on the refits validate", {
  fit <- mbco_root_fit()
  res <- mbco_sem(fit, "a2", "cp", n_starts = 2L, control = list())
  expect_identical(res$ledger$children[[2L]]$context$settings$n_starts, 2L)
  expect_true(.sem_valid_mbco_outcome(res$ledger, c("a2", "cp")))
  mixed <- res$ledger
  mixed$children[[3L]]$context$settings$n_starts <- 7L
  expect_false(.sem_valid_mbco_outcome(mixed, c("a2", "cp")))
})
