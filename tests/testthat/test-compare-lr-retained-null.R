# compare_lr() on an MBCO reference whose null was RETAINED after a covariance-stage failure (D4, #340). The null keeps
# its likelihood (`covariance = "failed"` in its ledger node) and the statistic is unchanged; an optimizer failure is
# the unresolved case. Failure injection reuses test-sem-post-fit.R: a mocked `.sem_vcov` (retained) and a mocked
# `.sem_fit_syntax` raising `.sem_no_convergence()` (unresolved, as in test-sem-mbco-root.R).

skip_if_not_installed("lavaan")

retained_model <- "repetition ~ a1*x\nimagery ~ a2*x\nrecall ~ cp*x + b1*repetition + b2*imagery"
retained_paths <- c("a1", "b1")

retained_fit <- function() {
  data <- readRDS(testthat::test_path("fixtures", "memory_exp.rds"))
  suppressMessages(medfit::fit_sem(retained_model, data, n_starts = 1L, information = "expected"))
}

# Run `code` with the first `.sem_vcov` call of each mbco_sem() refit sequence failing (null 1 retains its likelihood).
with_failed_null_covariance <- function(code) {
  real <- medfit:::.sem_vcov
  calls <- 0L
  testthat::local_mocked_bindings(.sem_vcov = function(...) {
    calls <<- calls + 1L
    if (calls == 1L) stop("injected null covariance failure")
    real(...)
  }, .package = "medfit")
  force(code)
}

# Run compare_lr() and collect every warning it raises.
collect_compare <- function(fit) {
  warns <- list()
  res <- withCallingHandlers(
    medfit::compare_lr(fit, retained_paths, engine = "lavaan"),
    warning = function(w) {
      warns[[length(warns) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  list(res = res, warns = warns)
}

is_retained_warning <- function(w) grepl("likelihood retained, covariance unavailable", conditionMessage(w))

# The contract of case 1 as named checks, shared by the planted-defect test so the mutant is judged by the same rules.
retained_contract <- function(cmp, ref, base) {
  null <- ref$ledger$children[[2L]]
  c(
    same_lr = identical(cmp$res$reference$lr, base$reference$lr),
    reference_accepted = isTRUE(cmp$res$reference$accepted) && isTRUE(ref$accepted),
    same_verdict = identical(cmp$res$verdict, base$verdict),
    same_run_status = identical(cmp$res$runs$status, base$runs$status),
    no_unresolved_run = !any(cmp$res$runs$status == "unresolved"),
    null_kept = identical(null$id, "mbco/null:1"),
    null_covariance_failed = identical(null$covariance, "failed"),
    root_resolved = identical(ref$ledger$outcome, "resolved")
  )
}

test_that("a covariance-failed retained null leaves the compare_lr() reference unchanged and resolved", {
  fit <- retained_fit()
  base <- collect_compare(fit)
  expect_length(base$warns, 0L)
  base_mbco <- medfit::mbco_sem(fit, paths = retained_paths)

  cmp <- with_failed_null_covariance(collect_compare(fit))
  ref <- with_failed_null_covariance(suppressWarnings(medfit:::.lr_reference(fit, retained_paths)))

  # same statistic (f and p-value) as with the failure absent
  expect_identical(cmp$res$reference$lr, base$res$reference$lr)
  with_failed_null_covariance({
    mb <- suppressWarnings(medfit::mbco_sem(fit, paths = retained_paths))
    expect_identical(mb$tests$f, base_mbco$tests$f)
    expect_identical(mb$p.value, base_mbco$p.value)
    expect_false(mb$unresolved)
    expect_true(all(mb$tests$converged))
  })
  # the retained warning is the only new condition
  expect_length(cmp$warns, 1L)
  expect_true(is_retained_warning(cmp$warns[[1L]]))
  expect_s3_class(cmp$warns[[1L]], "medfit_sem_covariance_notice")
  expect_false(inherits(cmp$res, "error"))
  # the null stays in the ledger with covariance "failed", the reference is not unresolved, no run is
  expect_identical(length(ref$ledger$children), 3L)
  contract <- retained_contract(cmp, ref, base$res)
  expect_identical(contract, stats::setNames(rep(TRUE, length(contract)), names(contract)))
})

test_that("an optimizer-failed null still makes the compare_lr() reference unresolved", {
  fit <- retained_fit()
  real <- medfit:::.sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(model, ...) {
    if (!is.null(model) && endsWith(model, "\na1 == 0")) {
      stop(medfit:::.sem_no_convergence("injected null failure"))
    }
    real(model, ...)
  }, .package = "medfit")
  cmp <- collect_compare(fit)
  ref <- suppressWarnings(medfit:::.lr_reference(fit, retained_paths))
  expect_false(cmp$res$reference$accepted)
  expect_true(is.na(cmp$res$reference$lr))
  expect_identical(cmp$res$verdict, "unresolved")
  expect_true(all(cmp$res$runs$status == "unresolved"))
  expect_false(ref$accepted)
  expect_identical(ref$ledger$outcome, "unresolved")
  expect_identical(ref$ledger$children[[2L]]$outcome, "unresolved")
  # an unresolved null is not a covariance-stage retention
  expect_false(any(vapply(cmp$warns, is_retained_warning, TRUE)))
  expect_false(identical(ref$ledger$children[[2L]]$covariance, "failed"))
})

# Planted defect (mutant `retained_as_unresolved`): a reference that treats the retained null as an unresolved refit,
# i.e. its row has `converged = FALSE`, the MBCO statistic is NA and the ledger root is unresolved.
test_that("treating the retained null as unresolved is caught by the retained-null contract", {
  fit <- retained_fit()
  base <- collect_compare(fit)
  real_mbco <- medfit::mbco_sem
  mutant <- function(object, ...) {
    out <- real_mbco(object, ...)
    out$tests$converged[1L] <- FALSE
    out$tests$f[1L] <- NA_real_
    out$tests$diff_ll[1L] <- NA_real_
    out$unresolved <- TRUE
    out$statistic[] <- NA_real_
    out$ledger$outcome <- "unresolved"
    out
  }
  testthat::local_mocked_bindings(mbco_sem = mutant, .package = "medfit")
  cmp <- with_failed_null_covariance(collect_compare(fit))
  ref <- with_failed_null_covariance(suppressWarnings(medfit:::.lr_reference(fit, retained_paths)))
  expect_identical(cmp$res$verdict, "unresolved") # the mutant really is the unresolved reference
  contract <- retained_contract(cmp, ref, base$res)
  expect_false(all(contract))
  expect_false(contract[["reference_accepted"]])
  expect_false(contract[["root_resolved"]])
})
