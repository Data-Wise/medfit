# compare_lr(): the public wrapper (#249 T4).
d <- mediation_demo
mod <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"

test_that("compare_lr() validates its inputs", {
  fit <- suppressWarnings(fit_sem(mod, d))
  expect_error(compare_lr(1, c("a", "b")), "SEMFit")
  expect_error(compare_lr(fit, "a"), "paths")
  expect_error(compare_lr(fit, c("a", "b"), engine = "mplus"), "should be one of")
  expect_error(compare_lr(fit, c("a", "b"), tolerance = -1), "tolerance")
})

test_that("compare_lr() runs lavaan on a valid fit and returns a classed result", {
  skip_if_not_installed("lavaan")
  fit <- suppressWarnings(fit_sem(mod, d))
  res <- suppressWarnings(compare_lr(fit, c("a", "b"), engine = "lavaan"))
  expect_s3_class(res, "medfit_lr_comparison")
  expect_true(res$verdict %in% c("agree", "disagree", "unresolved"))
  expect_true(res$reference$accepted)
  expect_equal(res$reference$lr, min(mbco_sem(fit, paths = c("a", "b"))$tests$diff_ll))
  expect_output(print(res), "medfit LR comparison")
})

test_that("compare_lr() raises the engine warnings from observed evidence", {
  skip_if_not_installed("lavaan")
  fit <- suppressWarnings(fit_sem(mod, d))
  res <- withCallingHandlers(
    compare_lr(fit, c("a", "b"), engine = "lavaan"),
    medfit_warning_engine_comparison = function(w) invokeRestart("muffleWarning"),
    warning = function(w) invokeRestart("muffleWarning")
  )
  expect_true(all(res$runs$status %in% c("agree", "above_reference", "below_reference", "constraint_violated",
                                         "failed", "unchecked", "unresolved")))
})

test_that("compare_lr() never poses a*b == 0 to medfit's own solver", {
  skip_if_not_installed("lavaan")
  fit <- suppressWarnings(fit_sem(mod, d))
  models <- character()
  real <- .sem_fit_syntax
  testthat::local_mocked_bindings(
    .sem_fit_syntax = function(model, ...) {
      models <<- c(models, model)
      real(model, ...)
    }
  )
  suppressWarnings(compare_lr(fit, c("a", "b"), engine = "lavaan"))
  cons <- unlist(regmatches(models, gregexpr("[^\n]*==[^\n]*", models)))
  expect_setequal(trimws(cons), c("a == 0", "b == 0"))
  expect_false(any(grepl("\\*", cons)))
})
