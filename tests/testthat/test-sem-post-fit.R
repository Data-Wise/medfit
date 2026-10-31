post_fit_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

test_that("public covariance failure exposes accepted evidence, never a SEMFit", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  data$unused <- NA_real_
  data$recall[1L] <- NA_real_
  baseline <- suppressMessages(fit_sem(post_fit_model, data, n_starts = 1L, information = "expected"))
  local_mocked_bindings(.sem_vcov = function(...) {
    stop(.sem_covariance_diagnostic("information_not_pd", "injected covariance failure"))
  })
  err <- tryCatch(suppressMessages(fit_sem(post_fit_model, data, n_starts = 1L,
                                           information = "expected")), error = identity)
  expect_s3_class(err, "medfit_sem_covariance_error")
  expect_identical(err$schema_version, 1L)
  expect_identical(err$stage, "covariance")
  expect_identical(err$partial$f, baseline@f)
  expect_identical(err$partial$theta, baseline@theta)
  expect_identical(err$ledger$context, baseline@diagnostics$ledger$context)
  expect_identical(err$ledger, err$partial$ledger)
  expect_identical(conditionMessage(err), "injected covariance failure")
  # a sibling of the optimizer failure: the optimizer accepted this fit, and no D-11 handler may take it for one
  expect_false(inherits(err, "medfit_error_no_convergence"))
  expect_false(S7::S7_inherits(err$partial, SEMFit))
  expect_null(err$partial$vcov)
  expect_null(err$partial$defined)
  expect_identical(err$ledger$covariance, "failed")
  expect_match(err$ledger$post_fit$condition$message, "injected covariance failure")
  expect_true(.sem_valid_outcome(err$ledger))
  # Documented condition fields can be consumed without private namespace access.
  expect_identical(err$ledger$likelihood$f, err$partial$f)
  expect_identical(err$ledger$context$n_obs, baseline@n_obs)
  expect_error(mbco_sem(err, a = "a1", b = "b1"), "SEMFit")
})

test_that("either internal null may retain covariance-only evidence with its failure notice", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  full <- fit_sem(post_fit_model, data, n_starts = 1L, information = "expected")
  baseline <- mbco_sem(full, a = "a1", b = "b1")
  vcov <- .sem_vcov
  for (target in 1:2) local({
    calls <- 0L
    local_mocked_bindings(.sem_vcov = function(...) {
      calls <<- calls + 1L
      if (calls == target) stop(.sem_covariance_diagnostic("information_not_pd", "injected null covariance failure"))
      vcov(...)
    })
    expect_warning(out <- mbco_sem(full, a = "a1", b = "b1"), "covariance.*likelihood retained")
    expect_identical(calls, 2L)
    expect_identical(out$tests, baseline$tests)
    expect_identical(out$statistic, baseline$statistic)
    node <- out$ledger$children[[target + 1L]]
    expect_identical(node$id, paste0("mbco/null:", target))
    expect_identical(node$covariance, "failed")
    expect_match(node$post_fit$condition$message, "injected null covariance failure")
    expect_true(any(vapply(node$notices$warnings, function(w) {
      grepl("likelihood retained", w$message)
    }, TRUE)))
  })
})

test_that("non-covariance failures do not acquire a covariance certificate", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  local_mocked_bindings(.sem_vcov = function(...) stop("covariance must not hide invalid definitions"))
  for (model in c(paste(post_fit_model, "bad := missing_label", sep = "\n"), "invalid syntax")) {
    err <- tryCatch(fit_sem(model, data, n_starts = 1L), error = identity)
    expect_s3_class(err, "error")
    expect_false(inherits(err, "medfit_sem_covariance_error"))
    expect_identical(err$ledger$likelihood$state, "unavailable")
  }
  local_mocked_bindings(.sem_optimize = function(...) stop("optimizer failure"))
  err <- tryCatch(fit_sem(post_fit_model, data, n_starts = 1L), error = identity)
  expect_false(inherits(err, "medfit_sem_covariance_error"))
  expect_identical(err$ledger$likelihood$state, "unavailable")
})

test_that("nonfinite or unaccepted optimization cannot retain a likelihood", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  optimize <- .sem_optimize
  for (field in c("f", "converged")) local({
    local_mocked_bindings(.sem_optimize = function(...) {
      x <- optimize(...)
      x[[field]] <- if (field == "f") Inf else FALSE
      x
    }, .sem_vcov = function(...) stop(.sem_covariance_diagnostic("information_not_pd", "covariance must not run")))
    err <- tryCatch(fit_sem(post_fit_model, data, n_starts = 1L), error = identity)
    expect_s3_class(err, "error")
    expect_false(inherits(err, "medfit_sem_covariance_error"))
    expect_identical(err$ledger$likelihood$state, "unavailable")
  })
})

test_that("singular-information NA return and warnings are not cleared by finite f", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  local_mocked_bindings(.sem_invert_info = function(...) NULL)
  expect_warning(full <- fit_sem(post_fit_model, data, n_starts = 1L), "may not be identified")
  expect_true(all(is.na(full@vcov)))
  expect_identical(full@diagnostics$ledger$covariance, "unavailable")
  expect_null(full@diagnostics$ledger$post_fit)
  expect_true(is.finite(full@f))
  local_mocked_bindings(.sem_vcov = function(...) {
    warning("information matrix is singular; the model may not be identified")
    stop(.sem_covariance_diagnostic("information_not_pd", "injected covariance failure after identification warning"))
  })
  out <- suppressWarnings(mbco_sem(full, a = "a1", b = "b1"))
  for (node in out$ledger$children[-1L]) {
    text <- vapply(node$notices$warnings, `[[`, "", "message")
    expect_true(any(grepl("may not be identified", text)))
    expect_true(any(grepl("likelihood retained", text)))
    expect_identical(node$covariance, "failed")
  }
})

test_that("nested covariance failures retain every branch without a public success", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  model <- paste(post_fit_model, "a1*b1 == 0", sep = "\n")
  full <- fit_sem(model, data, n_starts = 1L, information = "expected")
  baseline <- mbco_sem(full, a = "a2", b = "cp")
  vcov <- .sem_vcov
  for (target in 1:2) local({
    calls <- 0L
    local_mocked_bindings(.sem_vcov = function(...) {
      calls <<- calls + 1L
      if (calls == target) stop(.sem_covariance_diagnostic("information_not_pd", "injected nested covariance failure"))
      vcov(...)
    })
    err <- tryCatch(suppressWarnings(fit_sem(model, data, n_starts = 1L,
                                             information = "expected")), error = identity)
    expect_s3_class(err, "medfit_sem_covariance_error")
    expect_length(err$ledger$children, 2L)
    expect_true(.sem_valid_outcome(err$ledger))
    expect_identical(err$ledger$context, full@diagnostics$ledger$context)
    expect_identical(err$partial$f, full@f)
    expect_identical(err$ledger$children[[target]]$covariance, "failed")
    calls <- 0L
    out <- suppressWarnings(mbco_sem(full, a = "a2", b = "cp"))
    expect_identical(calls, 4L)
    expect_identical(out$tests, baseline$tests)
    node <- out$ledger$children[[2L]]$children[[target]]
    expect_identical(node$id, paste0("mbco/null:1/branch:", target))
    expect_match(node$post_fit$condition$message, "injected nested")
    expect_true(any(vapply(node$notices$warnings, function(w) grepl("likelihood retained", w$message), TRUE)))
  })
})

test_that("nonwinning covariance failure keeps its own public child attribution", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  vcov <- .sem_vcov
  for (product in c("a1*b1", "b1*a1")) local({
    model <- paste(post_fit_model, paste(product, "== 0"), sep = "\n")
    full <- fit_sem(model, data, n_starts = 1L, information = "expected")
    children <- full@diagnostics$ledger$children
    objectives <- vapply(children, function(x) x$likelihood$f, 0)
    winner <- which.min(objectives)
    loser <- which.max(objectives)
    expect_gt(objectives[loser], objectives[winner])
    calls <- new.env(parent = emptyenv())
    calls$n <- 0L
    local_mocked_bindings(.sem_vcov = function(...) {
      calls$n <- calls$n + 1L
      if (calls$n == loser) {
        warning("injected losing-child identification concern", call. = FALSE)
        stop(.sem_covariance_diagnostic("information_not_pd", "injected losing-child covariance failure"))
      }
      vcov(...)
    })
    err <- tryCatch(suppressWarnings(fit_sem(model, data, n_starts = 1L,
                                             information = "expected")), error = identity)
    expect_s3_class(err, "medfit_sem_covariance_error")
    expect_identical(calls$n, 2L)
    node <- err$ledger
    failed <- node$children[[loser]]
    healthy <- node$children[[winner]]
    expect_true(.sem_valid_outcome(node))
    expect_identical(err$partial$f, full@f)
    expect_identical(node$likelihood$f, healthy$likelihood$f)
    expect_identical(failed$id, paste0("fit/branch:", loser))
    expect_identical(failed$covariance, "failed")
    expect_identical(healthy$covariance, "available")
    expect_null(healthy$post_fit)
    expect_identical(node$post_fit, failed$post_fit)
    expect_match(node$post_fit$condition$message, "losing-child covariance failure")
    text <- vapply(failed$notices$warnings, `[[`, "", "message")
    expect_true(any(grepl("identification concern", text)))
    expect_true(any(grepl("likelihood retained", text)))
    expect_length(healthy$notices$warnings, 0L)
    expect_null(err$partial$vcov)
    expect_null(err$partial$defined)
  })
})

test_that("either nested null retains a losing-child notice without changing LR or p", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  vcov <- .sem_vcov
  for (product in c("a1*b1", "b1*a1")) local({
    model <- paste(post_fit_model, paste(product, "== 0"), sep = "\n")
    full <- fit_sem(model, data, n_starts = 1L, information = "expected")
    baseline <- mbco_sem(full, a = "a2", b = "cp")
    for (target in 1:2) local({
      original <- baseline$ledger$children[[target + 1L]]
      objectives <- vapply(original$children, function(x) x$likelihood$f, 0)
      winner <- which.min(objectives)
      loser <- which.max(objectives)
      expect_gt(objectives[loser], objectives[winner])
      calls <- new.env(parent = emptyenv())
      calls$n <- 0L
      local_mocked_bindings(.sem_vcov = function(...) {
        calls$n <- calls$n + 1L
        if (calls$n == 2L * (target - 1L) + loser) {
          warning("injected losing-null-child identification concern", call. = FALSE)
          stop(.sem_covariance_diagnostic("information_not_pd", "injected losing-null-child covariance failure"))
        }
        vcov(...)
      })
      expect_warning(out <- mbco_sem(full, a = "a2", b = "cp"), "covariance.*likelihood retained")
      expect_identical(calls$n, 4L)
      expect_identical(out$tests, baseline$tests)
      expect_identical(out$statistic, baseline$statistic)
      expect_identical(out$p.value, baseline$p.value)
      node <- out$ledger$children[[target + 1L]]
      failed <- node$children[[loser]]
      healthy <- node$children[[winner]]
      expect_identical(node$likelihood$f, healthy$likelihood$f)
      expect_identical(node$context, original$context)
      expect_identical(node$enumeration, original$enumeration)
      expect_identical(failed$id, paste0("mbco/null:", target, "/branch:", loser))
      expect_identical(healthy$covariance, "available")
      expect_null(healthy$post_fit)
      expect_identical(node$post_fit, failed$post_fit)
      expect_identical(failed$covariance, "failed")
      text <- vapply(failed$notices$warnings, `[[`, "", "message")
      expect_true(any(grepl("identification concern", text)))
      expect_true(any(grepl("likelihood retained", text)))
      expect_length(healthy$notices$warnings, 0L)
      other <- out$ledger$children[[4L - target]]
      expect_null(other$post_fit)
      expect_identical(other$covariance, "available")
      expect_identical(out$ledger$children[[1L]], baseline$ledger$children[[1L]])
    })
  })
})

test_that("malformed covariance payloads and incompatible null dimensions refuse recovery", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  full <- fit_sem(post_fit_model, data, n_starts = 1L)
  err <- local({
    local_mocked_bindings(.sem_vcov = function(...) {
      stop(.sem_covariance_diagnostic("information_not_pd", "injected covariance failure"))
    })
    tryCatch(fit_sem(post_fit_model, data, n_starts = 1L), error = identity)
  })
  for (field in c("schema_version", "stage", "partial", "ledger")) {
    bad <- err
    bad[[field]] <- NULL
    expect_error(.sem_retain_covariance(bad), "covariance-stage failure", class = "medfit_error_ledger")
  }
  bad <- err
  bad$partial$ledger$post_fit$schema_version <- 2L
  expect_error(.sem_retain_covariance(bad), "covariance-stage failure", class = "medfit_error_ledger")
  syntax <- .sem_fit_syntax
  changed_dimension <- function(...) {
    tryCatch(syntax(...), medfit_sem_covariance_error = function(e) {
      e$partial$df <- e$partial$df + 1L
      stop(e)
    })
  }
  local_mocked_bindings(.sem_vcov = function(...) {
    stop(.sem_covariance_diagnostic("information_not_pd", "injected covariance failure"))
  }, .sem_fit_syntax = changed_dimension)
  expect_error(suppressWarnings(mbco_sem(full, a = "a1", b = "b1")), "incompatible.*dimension",
               class = "medfit_error_ledger")
})

test_that("a returned fit can never carry covariance-failure evidence (D-11: no partial fit)", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  full <- fit_sem(post_fit_model, data, n_starts = 1L)
  forged <- full
  forged@diagnostics$ledger$covariance <- "failed"
  forged@diagnostics$ledger$post_fit <- list(
    schema_version = 1L, stage = "covariance",
    condition = list(class = c("simpleError", "error", "condition"), message = "forged", call = NULL)
  )
  expect_error(mbco_sem(forged, a = "a1", b = "b1"), class = "medfit_error_ledger")
  err <- local({
    local_mocked_bindings(.sem_vcov = function(...) {
      stop(.sem_covariance_diagnostic("information_not_pd", "injected covariance failure"))
    })
    tryCatch(fit_sem(post_fit_model, data, n_starts = 1L), error = identity)
  })
  expect_error(.sem_require_outcome(err$partial), class = "medfit_error_ledger")
  expect_silent(.sem_require_outcome(err$partial, partial = TRUE))
})

test_that("root attribution and failure evidence cannot be forged on a union ledger", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  model <- paste(post_fit_model, "a1*b1 == 0", sep = "\n")
  vcov <- .sem_vcov
  calls <- 0L
  local_mocked_bindings(.sem_vcov = function(...) {
    calls <<- calls + 1L
    if (calls == 2L) stop(.sem_covariance_diagnostic("information_not_pd", "injected second-branch covariance failure"))
    vcov(...)
  })
  err <- tryCatch(suppressWarnings(fit_sem(model, data, n_starts = 1L)), error = identity)
  ledger <- err$ledger
  expect_true(.sem_valid_outcome(ledger))
  expect_identical(ledger$post_fit, ledger$children[[2L]]$post_fit)
  # attribution to the first branch (or to nothing) is a forgery
  bad <- ledger
  bad$post_fit <- NULL
  bad$covariance <- "available"
  expect_false(.sem_valid_outcome(bad))
  bad <- ledger
  bad$post_fit <- bad$children[[1L]]$post_fit
  expect_false(.sem_valid_outcome(bad))
  # a failed covariance without its evidence, or evidence on an available one, is refused
  bad <- ledger
  bad$children[[2L]]$post_fit <- NULL
  expect_false(.sem_valid_outcome(bad))
  bad <- ledger
  bad$children[[1L]]$post_fit <- ledger$children[[2L]]$post_fit
  expect_false(.sem_valid_outcome(bad))
})

test_that("a covariance failure does not outrank a branch that did not converge (D-11 first)", {
  data <- readRDS(test_path("fixtures", "memory_exp.rds"))
  model <- paste(post_fit_model, "a1*b1 == 0", sep = "\n")
  vcov <- .sem_vcov
  optimize <- .sem_optimize
  fits <- 0L
  local_mocked_bindings(
    .sem_optimize = function(...) {
      fits <<- fits + 1L
      if (fits == 1L) .sem_no_convergence("injected branch failure")
      optimize(...)
    },
    .sem_vcov = function(...) stop(.sem_covariance_diagnostic("information_not_pd", "injected covariance failure"))
  )
  err <- tryCatch(suppressWarnings(fit_sem(model, data, n_starts = 1L)), error = identity)
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_false(inherits(err, "medfit_sem_covariance_error"))
})
