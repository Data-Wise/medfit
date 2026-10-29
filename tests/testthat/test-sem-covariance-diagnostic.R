# D4(b) (owner ruling 2026-10-26): only a typed covariance diagnostic (`medfit_sem_covariance_diagnostic`, raised by an
# explicit check in `.sem_vcov()`) is likelihood-ratio evidence. Every other error in the covariance stage fails
# closed: it propagates unchanged from `fit_sem()`, a zero-product branch and an `mbco_sem()` null refit, and nothing
# is retained, wrapped or noticed.

diag_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"

diag_data <- function() readRDS(testthat::test_path("fixtures", "memory_exp.rds"))

# Run `code`, returning its error (or NULL) and every warning it raised, with the warnings muffled.
diag_run <- function(code) {
  warns <- list()
  err <- tryCatch(withCallingHandlers(code, warning = function(w) {
    warns[[length(warns) + 1L]] <<- w
    invokeRestart("muffleWarning")
  }), error = identity)
  list(error = if (inherits(err, "error")) err, warnings = warns)
}

is_notice <- function(warns) any(vapply(warns, inherits, TRUE, "medfit_sem_covariance_notice"))

# TRUE inside a `.sem_vcov()` call: a planted information matrix is then the one the covariance stage inverts, never
# the one the optimizer or its acceptance gate uses.
in_vcov <- function() {
  any(vapply(sys.calls(), function(cl) identical(cl[[1L]], quote(.sem_vcov)), TRUE))
}

# A symmetric information with a positive diagonal and an indefinite 2 x 2 minor on coordinates 1 and 2 (correlation
# 2 in the Jacobi-scaled matrix): finite and invertible, so it passes the singular check, but not positive definite.
indefinite <- function(m) {
  off <- 2 * sqrt(m[1L, 1L] * m[2L, 2L])
  m[1L, 2L] <- m[2L, 1L] <- off
  m
}

test_that("the diagnostic constructor carries a validated kind and no call", {
  e <- .sem_covariance_diagnostic("information_not_pd", "planted")
  expect_s3_class(e, c("medfit_sem_covariance_diagnostic", "error", "condition"), exact = TRUE)
  expect_identical(e$kind, "information_not_pd")
  expect_identical(conditionMessage(e), "planted")
  expect_null(conditionCall(e))
  expect_identical(.sem_covariance_diagnostic("negative_variance", "x")$kind, "negative_variance")
  # singular information is not a kind: it stays the public warning plus an NA covariance (owner, 2026-10-26)
  for (kind in c("singular_information", "other", NA_character_)) {
    expect_error(.sem_covariance_diagnostic(kind, "x"), "kind")
  }
  expect_identical(.sem_condition_record(e)$kind, "information_not_pd")
  # a record of an untyped condition keeps its old shape: no `kind` element at all
  expect_identical(names(.sem_condition_record(simpleError("x"))), c("class", "message", "call"))
})

test_that("an indefinite information below .sem_vcov raises information_not_pd: public error, retained null", {
  data <- diag_data()
  full <- fit_sem(diag_model, data, n_starts = 1L, information = "expected")
  baseline <- mbco_sem(full, a = "a1", b = "b1")
  real <- .sem_checked_invert_info
  local_mocked_bindings(.sem_checked_invert_info = function(info) {
    real(indefinite(info))
  })
  # the planted matrix passes the singular screen: it is the new check, not the warning-plus-NA path, that fires
  expect_identical(nrow(full@vcov), length(full@theta))
  run <- diag_run(fit_sem(diag_model, data, n_starts = 1L, information = "expected"))
  err <- run$error
  expect_s3_class(err, "medfit_sem_covariance_error")
  expect_identical(err$ledger$post_fit$condition$kind, "information_not_pd")
  expect_true("medfit_sem_covariance_diagnostic" %in% err$ledger$post_fit$condition$class)
  expect_identical(err$partial$f, full@f)
  expect_true(.sem_valid_outcome(err$ledger))
  expect_false(any(grepl("may not be identified", vapply(run$warnings, conditionMessage, ""))))
  run <- diag_run(out <- mbco_sem(full, a = "a1", b = "b1"))
  expect_null(run$error)
  expect_true(is_notice(run$warnings))
  expect_identical(out$statistic, baseline$statistic)
  for (i in 2:3) {
    node <- out$ledger$children[[i]]
    expect_identical(node$covariance, "failed")
    expect_identical(node$post_fit$condition$kind, "information_not_pd")
  }
})

test_that("information_not_pd also fires on the reduced Z' I Z of an active constraint", {
  data <- diag_data()
  model <- paste(diag_model, "a1 == a2", sep = "\n")
  real <- .sem_checked_invert_info
  local_mocked_bindings(.sem_checked_invert_info = function(info) {
    real(indefinite(info))
  })
  err <- diag_run(fit_sem(model, data, n_starts = 1L, information = "expected"))$error
  expect_s3_class(err, "medfit_sem_covariance_error")
  expect_identical(err$ledger$post_fit$condition$kind, "information_not_pd")
})

test_that("a negative variance in the final covariance raises negative_variance: public error, retained null", {
  data <- diag_data()
  full <- fit_sem(diag_model, data, n_starts = 1L, information = "expected")
  baseline <- mbco_sem(full, a = "a1", b = "b1")
  # the real information and the real check; only the inverse handed back is planted with a negative variance
  local_mocked_bindings(.sem_invert_info = function(info) {
    v <- solve(info)
    v[1L, 1L] <- -abs(v[1L, 1L])
    v
  })
  err <- diag_run(fit_sem(diag_model, data, n_starts = 1L, information = "expected"))$error
  expect_s3_class(err, "medfit_sem_covariance_error")
  expect_identical(err$ledger$post_fit$condition$kind, "negative_variance")
  expect_true(.sem_valid_outcome(err$ledger))
  run <- diag_run(out <- mbco_sem(full, a = "a1", b = "b1"))
  expect_null(run$error)
  expect_true(is_notice(run$warnings))
  expect_identical(out$statistic, baseline$statistic)
  expect_identical(out$ledger$children[[2L]]$post_fit$condition$kind, "negative_variance")
})

test_that("an untyped covariance-stage error fails closed in fit_sem(), a branch and an mbco_sem() null", {
  data <- diag_data()
  full <- fit_sem(diag_model, data, n_starts = 1L, information = "expected")
  union <- paste(diag_model, "a1*b1 == 0", sep = "\n")
  conditions <- list(
    oom = simpleError("cannot allocate vector of size 8.0 Gb"),
    internal = structure(class = c("medfit_internal_bug", "error", "condition"),
                         list(message = "internal invariant broken", call = quote(.sem_internal())))
  )
  for (nm in names(conditions)) local({
    planted <- conditions[[nm]]
    local_mocked_bindings(.sem_vcov = function(...) stop(planted))
    calls <- list(
      fit_sem = function() fit_sem(diag_model, data, n_starts = 1L, information = "expected"),
      branch = function() fit_sem(union, data, n_starts = 1L, information = "expected"),
      mbco_null = function() mbco_sem(full, a = "a1", b = "b1")
    )
    for (site in names(calls)) {
      run <- diag_run(calls[[site]]())
      err <- run$error
      label <- paste(nm, site)
      expect_s3_class(err, class(planted)[1L])
      expect_identical(class(err), class(planted), info = label)
      expect_identical(conditionMessage(err), conditionMessage(planted), info = label)
      expect_identical(conditionCall(err), conditionCall(planted), info = label)
      expect_false(inherits(err, "medfit_sem_covariance_error"), info = label)
      expect_false(inherits(err, "medfit_error_no_convergence"), info = label)
      expect_false(inherits(err, "medfit_error_ledger"), info = label)
      expect_null(err$partial, info = label)
      expect_false(is_notice(run$warnings), info = label)
    }
  })
})

test_that("a covariance error whose evidence is not the typed diagnostic is refused, never retained", {
  data <- diag_data()
  full <- fit_sem(diag_model, data, n_starts = 1L, information = "expected")
  genuine <- local({
    local_mocked_bindings(.sem_vcov = function(...) {
      stop(.sem_covariance_diagnostic("information_not_pd", "planted diagnostic"))
    })
    tryCatch(fit_sem(diag_model, data, n_starts = 1L, information = "expected"), error = identity)
  })
  expect_s3_class(genuine, "medfit_sem_covariance_error")
  expect_warning(.sem_retain_covariance(genuine), class = "medfit_sem_covariance_notice")
  forge <- function(e, edit) {
    e$partial$ledger$post_fit$condition <- edit(e$partial$ledger$post_fit$condition)
    e$ledger <- e$partial$ledger
    e
  }
  untyped <- forge(genuine, function(cond) {
    cond$class <- c("simpleError", "error", "condition")
    cond$kind <- NULL
    cond
  })
  badkind <- forge(genuine, function(cond) {
    cond$kind <- "singular_information"
    cond
  })
  nokind <- forge(genuine, function(cond) {
    cond$kind <- NULL
    cond
  })
  for (bad in list(untyped, badkind, nokind)) {
    expect_error(.sem_retain_covariance(bad), "malformed covariance-stage", class = "medfit_error_ledger")
    expect_false(.sem_valid_post_fit(bad$ledger$post_fit))
  }
  # both internal consumers refuse the forged payload: the MBCO null and a zero-product branch
  syntax <- .sem_fit_syntax
  local_mocked_bindings(.sem_fit_syntax = function(...) {
    tryCatch(syntax(...), medfit_sem_covariance_error = function(e) {
      stop(forge(e, function(cond) {
        cond$class <- c("simpleError", "error", "condition")
        cond
      }))
    })
  }, .sem_vcov = function(...) stop(.sem_covariance_diagnostic("information_not_pd", "planted diagnostic")))
  run <- diag_run(mbco_sem(full, a = "a1", b = "b1"))
  expect_s3_class(run$error, "medfit_error_ledger")
  expect_false(is_notice(run$warnings))
  run <- diag_run(fit_sem(paste(diag_model, "a1*b1 == 0", sep = "\n"), data, n_starts = 1L,
                          information = "expected"))
  expect_s3_class(run$error, "medfit_error_ledger")
  expect_false(is_notice(run$warnings))
})

test_that("negative diagonal information is diagnosed while singular information remains unavailable", {
  err <- tryCatch(.sem_checked_invert_info(diag(c(-2, 1))), error = identity)
  expect_s3_class(err, "medfit_sem_covariance_diagnostic")
  expect_identical(err$kind, "information_not_pd")
  expect_null(.sem_checked_invert_info(diag(c(1, 0))))
  expect_null(.sem_checked_invert_info(diag(c(-2, 0))))
  expect_s3_class(tryCatch(.sem_checked_invert_info(matrix(c(0, 1, 1, 0), 2)), error = identity),
                  "medfit_sem_covariance_diagnostic")
})
