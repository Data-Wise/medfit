# D4 closure additions: (1) the root of a union whose branches all fail reports the first failing branch in branch
# order even when another branch has the smaller discrepancy; (2) every clause of `.sem_retain_covariance` refuses a
# payload that violates it.

closure_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

test_that("the root of an all-failing union reports the first failing branch, not the minimum-discrepancy branch", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  winners <- integer()
  for (product in c("a1*b1", "b1*a1")) local({
    model <- paste(closure_model, paste(product, "== 0"), sep = "\n")
    full <- fit_sem(model, data, n_starts = 1L, information = "expected")
    objectives <- vapply(full@diagnostics$ledger$children, function(x) x$likelihood$f, 0)
    winner <- which.min(objectives)
    winners <<- c(winners, winner)
    calls <- 0L
    local_mocked_bindings(.sem_vcov = function(...) {
      calls <<- calls + 1L
      stop(paste0("closure failure in call ", calls), call. = FALSE)
    })
    err <- tryCatch(suppressWarnings(fit_sem(model, data, n_starts = 1L, information = "expected")), error = identity)
    expect_s3_class(err, "medfit_sem_covariance_error")
    first <- err$ledger$children[[1L]]
    expect_identical(conditionMessage(err), "closure failure in call 1", info = product)
    expect_identical(err$ledger$post_fit, first$post_fit, info = product)
    if (winner != 1L) {
      other <- err$ledger$children[[winner]]
      expect_false(identical(err$ledger$post_fit, other$post_fit), info = product)
      expect_match(other$post_fit$condition$message, "call 2", info = product)
    }
  })
  # the fixture must exercise both cases: the first branch is the minimum in one product order and is not in the other
  expect_identical(winners, c(2L, 1L))
})

closure_retain_error <- function() {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  local_mocked_bindings(.sem_vcov = function(...) stop("closure covariance failure", call. = FALSE))
  tryCatch(fit_sem(closure_model, data, n_starts = 1L, information = "expected"), error = identity)
}

test_that("a genuine covariance-stage failure is retained with one notice", {
  e <- closure_retain_error()
  expect_s3_class(e, "medfit_sem_covariance_error")
  ws <- character()
  p <- withCallingHandlers(.sem_retain_covariance(e), warning = function(w) {
    ws <<- c(ws, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  expect_identical(p, e$partial)
  expect_length(ws, 1L)
  expect_match(ws, "covariance-stage failure: closure covariance failure")
})

test_that("each clause of the retained-covariance check refuses a payload that violates it", {
  e0 <- closure_retain_error()
  sync <- function(e) {
    e$ledger <- e$partial$ledger
    e
  }
  mutants <- list(
    class = function(e) {
      class(e) <- setdiff(class(e), "medfit_sem_covariance_error")
      e
    },
    schema_version = function(e) {
      e$schema_version <- 2L
      e
    },
    stage = function(e) {
      e$stage <- "optimizer"
      e
    },
    ledger_mismatch = function(e) {
      e$ledger$id <- paste0(e$ledger$id, "-forged")
      e
    },
    partial_not_list = function(e) {
      e$partial <- NULL
      e
    },
    vcov_present = function(e) {
      e$partial$vcov <- diag(2)
      sync(e)
    },
    defined_present = function(e) {
      e$partial$defined <- list()
      sync(e)
    },
    covariance_not_failed = function(e) {
      e$partial$ledger$covariance <- "ok"
      sync(e)
    },
    post_fit_schema = function(e) {
      e$partial$ledger$post_fit$schema_version <- 2L
      sync(e)
    },
    post_fit_stage = function(e) {
      e$partial$ledger$post_fit$stage <- "optimizer"
      sync(e)
    },
    post_fit_condition_class = function(e) {
      e$partial$ledger$post_fit$condition$class <- "warning"
      sync(e)
    },
    post_fit_message = function(e) {
      e$partial$ledger$post_fit$condition$message <- c("a", "b")
      sync(e)
    }
  )
  for (nm in names(mutants)) {
    err <- tryCatch(suppressWarnings(.sem_retain_covariance(mutants[[nm]](e0))), error = identity)
    expect_s3_class(err, "medfit_error_ledger")
    expect_match(conditionMessage(err), "malformed covariance-stage failure payload", info = nm)
  }
})
