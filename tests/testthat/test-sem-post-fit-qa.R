# Independent QA assertions for D4 (P4): attribution when several branches fail, messages kept from a retained
# branch, and each clause of the retained-null compatibility check isolated with a refit that differs in one respect.

qa_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

test_that("a union whose branches all fail reports the first failing branch in branch order, in both product orders", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  vcov <- .sem_vcov
  for (product in c("a1*b1", "b1*a1")) local({
    model <- paste(qa_model, paste(product, "== 0"), sep = "\n")
    full <- fit_sem(model, data, n_starts = 1L, information = "expected")
    objectives <- vapply(full@diagnostics$ledger$children, function(x) x$likelihood$f, 0)
    winner <- which.min(objectives)
    calls <- 0L
    local_mocked_bindings(.sem_vcov = function(...) {
      calls <<- calls + 1L
      stop(.sem_covariance_diagnostic("information_not_pd", paste0("qa failure in call ", calls)))
    })
    err <- tryCatch(suppressWarnings(fit_sem(model, data, n_starts = 1L, information = "expected")), error = identity)
    expect_s3_class(err, "medfit_sem_covariance_error")
    expect_identical(calls, 2L)
    expect_true(.sem_valid_outcome(err$ledger))
    expect_identical(conditionMessage(err), "qa failure in call 1")
    expect_identical(err$ledger$post_fit, err$ledger$children[[1L]]$post_fit)
    expect_match(err$ledger$post_fit$condition$message, "call 1")
    expect_identical(vapply(err$ledger$children, function(x) x$covariance, ""), c("failed", "failed"))
    # in one order the first failing branch is the minimum, in the other it is not: both are reported the same way
    expect_true(winner %in% 1:2)
    expect_identical(err$partial$f, full@f)
  })
})

test_that("a message raised before a branch's covariance failure survives into its node", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  model <- paste(qa_model, "a1*b1 == 0", sep = "\n")
  calls <- 0L
  local_mocked_bindings(.sem_vcov = function(...) {
    calls <<- calls + 1L
    if (calls == 1L) {
      message("qa branch message")
      warning("qa branch warning", call. = FALSE)
      stop(.sem_covariance_diagnostic("information_not_pd", "qa branch failure"))
    }
    stop(.sem_covariance_diagnostic("information_not_pd", "qa second failure"))
  })
  err <- tryCatch(suppressMessages(suppressWarnings(fit_sem(model, data, n_starts = 1L))), error = identity)
  expect_s3_class(err, "medfit_sem_covariance_error")
  node <- err$ledger$children[[1L]]
  expect_true(any(grepl("qa branch message", vapply(node$notices$messages, `[[`, "", "message"))))
  expect_true(any(grepl("qa branch warning", vapply(node$notices$warnings, `[[`, "", "message"))))
})

test_that("each clause of the retained-null compatibility check refuses a refit that differs in that respect", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  orig <- .sem_fit_syntax
  for (fixed in list(FALSE, TRUE)) local({
    fit <- fit_sem(qa_model, data, n_starts = 1L, information = "expected", fixed_x = fixed)
    baseline <- mbco_sem(fit, a = "a1", b = "b1")
    run <- function(tweak) {
      local_mocked_bindings(
        .sem_fit_syntax = function(...) do.call(orig, tweak(list(...))),
        .sem_vcov = function(...) stop(.sem_covariance_diagnostic("information_not_pd", "qa covariance failure"))
      )
      tryCatch(mbco_sem(fit, a = "a1", b = "b1"), error = identity)
    }
    # accepted: the refit is the null that was asked for; same statistic, one warning per retained null
    ws <- character()
    ok <- withCallingHandlers(run(identity), warning = function(w) {
      ws <<- c(ws, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
    expect_s3_class(ok, "htest")
    expect_identical(ok$statistic, baseline$statistic)
    expect_identical(ok$p.value, baseline$p.value)
    expect_identical(ok$tests, baseline$tests)
    expect_identical(sum(grepl("covariance-stage failure", ws)), 2L)
    expect_identical(vapply(ok$ledger$children[-1L], function(x) x$covariance, ""), c("failed", "failed"))
    tweaks <- list(
      data_values = function(a) {
        a[[2L]]$recall <- a[[2L]]$recall + 0.5
        a
      },
      information = function(a) {
        a[[3L]] <- if (identical(a[[3L]], "expected")) "observed" else "expected"
        a
      },
      other_restriction = function(a) {
        a[[1L]] <- sub("a1 == 0", "a2 == 0", a[[1L]], fixed = TRUE)
        a
      },
      two_restrictions = function(a) {
        a[[1L]] <- paste0(a[[1L]], "\ncp == 0")
        a
      },
      fixed_x = function(a) {
        a$fixed_x <- !isTRUE(fixed)
        a
      },
      meanstructure = function(a) {
        a$meanstructure <- !isTRUE(a$meanstructure)
        a
      }
    )
    for (nm in names(tweaks)) {
      err <- suppressWarnings(run(tweaks[[nm]]))
      expect_s3_class(err, "medfit_error_ledger")
      expect_match(conditionMessage(err), "incompatible", info = nm)
    }
  })
})

test_that("each field of the retained-null check refuses a self-consistent payload that differs in that field", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  orig <- .sem_fit_syntax
  # The null's own ledger is edited with the payload, so only the comparison with the parent fit can refuse it.
  for (fixed in list(FALSE, TRUE)) local({
    fit <- fit_sem(qa_model, data, n_starts = 1L, information = "expected", fixed_x = fixed)
    edits <- list(
      fixed_x = function(p) {
        p$fixed_x <- if (length(p$fixed_x)) character() else "x"
        p$ledger$context$domain$fixed_x <- p$fixed_x
        p
      },
      meanstructure = function(p) {
        p$ram$has_mean <- !isTRUE(p$ram$has_mean)
        p$ledger$context$domain$meanstructure <- p$ram$has_mean
        p
      },
      parameters = function(p) {
        p$ram$q <- p$ram$q + 1L
        p
      },
      weights = function(p) {
        p$weights <- rep(1, nrow(p$data))
        p$ledger$context$domain$weights <- p$weights
        p
      },
      factors = function(p) {
        p$factors <- c(p$factors, "qa_factor")
        p$ledger$context$domain$factors <- p$factors
        p
      },
      information = function(p) {
        p$information <- "other"
        p$ledger$context$domain$information <- "other"
        p
      }
    )
    for (nm in names(edits)) {
      local_mocked_bindings(
        .sem_fit_syntax = function(...) {
          tryCatch(orig(...), medfit_sem_covariance_error = function(e) {
            e$partial <- edits[[nm]](e$partial)
            e$ledger <- e$partial$ledger
            stop(e)
          })
        },
        .sem_vcov = function(...) stop(.sem_covariance_diagnostic("information_not_pd", "qa covariance failure"))
      )
      err <- tryCatch(suppressWarnings(mbco_sem(fit, a = "a1", b = "b1")), error = identity)
      expect_s3_class(err, "medfit_error_ledger")
      expect_match(conditionMessage(err), "incompatible", info = paste(nm, "fixed_x =", fixed))
    }
  })
})
