# Native SEM engine: a refit that cannot be fitted is an unresolved result, never a silent answer or a hard error
# (restoration-bound plan T7, G4 and G7), and a zero-product branch that cannot be fitted is an error, never a partial
# fit that coef(), vcov() or extract_mediation() would consume as certified. Callers: `.sem_fit_branches()` (a dropped
# branch is a `medfit_error_no_convergence`), `mbco_sem()` (a failed refit is a row with `converged = FALSE` and the
# statistic is NA, never the minimum over the refits that worked), `compare_lr()` (the reference is not accepted, the
# verdict is "unresolved"), and `anova()` (unchanged). The failures are planted by replacing `.sem_fit_syntax()` for
# chosen calls; every other call is the real fit.

ur_data <- function() medfit::mediation_demo
ur_model <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"

# `.sem_fit_syntax()` with the calls in `fail` (counted from 1 after this is installed) stopped
ur_failing <- function(fail, counter = new.env()) {
  real <- medfit:::.sem_fit_syntax
  counter$n <- 0L
  function(...) {
    counter$n <- counter$n + 1L
    if (counter$n %in% fail) medfit:::.sem_no_convergence("planted refit failure")
    real(...)
  }
}

test_that("a dropped zero-product branch is a classed error naming it, and a complete fit is unaffected", {
  full <- fit_sem(paste0(ur_model, "\na*b == 0"), ur_data())
  expect_true(S7::S7_inherits(full, SEMFit))
  expect_false("incomplete" %in% names(full@internals))
  # call 1 is the entry; calls 2 and 3 are the two branches (a = 0, b = 0): the first branch fails
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(2L))
  err <- tryCatch(fit_sem(paste0(ur_model, "\na*b == 0"), ur_data()), error = identity)
  expect_s3_class(err, "medfit_error_no_convergence")
  expect_match(conditionMessage(err), "1 of 2 zero-product branches did not converge")
  expect_match(conditionMessage(err), "best of the other branches has discrepancy [0-9.]+")
  expect_match(conditionMessage(err), "a == 0: planted refit failure", fixed = TRUE)
  # nothing is returned, so no consumer can use a partial fit
  expect_false(exists("res", inherits = FALSE))
})

test_that("every branch failing is still an error", {
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(2:3))
  expect_error(fit_sem(paste0(ur_model, "\na*b == 0"), ur_data()), "no branch of the zero-product constraints")
})

test_that("a failed refit is an unresolved row: NA statistic, converged FALSE, the survivor's number kept", {
  fit <- fit_sem(ur_model, ur_data())
  ok <- mbco_sem(fit, "a", "b")
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(1L))
  expect_warning(res <- mbco_sem(fit, "a", "b"), "refit with `a == 0` failed")
  expect_s3_class(res, "mbco_sem")
  expect_identical(res$tests$converged, c(FALSE, TRUE))
  expect_true(is.na(res$tests$diff_ll[1L]))
  expect_equal(res$tests$diff_ll[2L], ok$tests$diff_ll[2L], tolerance = 1e-8)
  expect_true(grepl("planted refit failure", res$tests$note[1L]))
  # never the minimum over the refits that worked
  expect_true(is.na(res$statistic))
  expect_true(is.na(res$p.value))
  expect_true(isTRUE(res$unresolved))
  # it still prints: the NA is shown, not an error
  expect_output(print(res), "MBCO = NA")
})

test_that("every refit failing leaves an NA statistic with both notes", {
  fit <- fit_sem(ur_model, ur_data())
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(1:2))
  expect_warning(res <- mbco_sem(fit, "a", "b"), "failed")
  expect_identical(res$tests$converged, c(FALSE, FALSE))
  expect_true(is.na(res$statistic))
  expect_false(any(grepl("^$", res$tests$note)))
})

test_that("a model or data error in a refit still stops: only an optimizer failure is unresolved", {
  fit <- fit_sem(ur_model, ur_data())
  real <- medfit:::.sem_fit_syntax
  testthat::local_mocked_bindings(.sem_fit_syntax = function(...) stop("planted structural error", call. = FALSE))
  expect_error(mbco_sem(fit, "a", "b"), "the refit with `a == 0` failed \\(planted structural error\\)")
})

test_that("a complete MBCO result carries converged TRUE, empty notes and unresolved FALSE", {
  res <- mbco_sem(fit_sem(ur_model, ur_data()), "a", "b")
  expect_true(all(res$tests$converged))
  expect_true(all(res$tests$note == ""))
  expect_false(isTRUE(res$unresolved))
  expect_true(is.finite(res$statistic))
})

test_that("mbco_sem() on a fit with a zero-product constraint reports a failed branch refit as unresolved", {
  full <- fit_sem(paste0(ur_model, "\na*b == 0"), ur_data())
  # the refit under the null a == 0 is itself a branch fit when the model already carries a*b == 0
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(1L))
  expect_warning(res <- mbco_sem(full, "a", "b"), "failed")
  expect_true(is.na(res$statistic))
  expect_true(isTRUE(res$unresolved))
})

test_that("the compare_lr reference is not accepted and the LR is NA when a refit fails", {
  fit <- fit_sem(ur_model, ur_data())
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(1L))
  ref <- suppressWarnings(medfit:::.lr_reference(fit, c("a", "b")))
  expect_false(ref$accepted)
  expect_true(is.na(ref$lr))
  # the assessment of any engine run is "unresolved" and blames neither side
  eng <- lr_engine(est = ref$est, fit = ref$fit, runs = list(lr_run(lr = 0.5)))
  out <- medfit:::.lr_assess(ref, list(eng))
  expect_identical(out$verdict, "unresolved")
  expect_true(all(out$runs$status == "unresolved"))
  expect_match(out$reason, "no accepted comparable result")
})

test_that("compare_lr() returns an unresolved comparison, not an error, when medfit's refit fails", {
  skip_if_not_installed("lavaan")
  fit <- suppressWarnings(fit_sem(ur_model, ur_data(), fixed_x = FALSE, meanstructure = NULL))
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(1L))
  expect_warning(res <- suppressWarnings(compare_lr(fit, c("a", "b"), engine = "lavaan")), NA)
  expect_s3_class(res, "medfit_lr_comparison")
  expect_identical(res$verdict, "unresolved")
  expect_false(res$reference$accepted)
  expect_true(is.na(res$reference$lr))
  expect_output(print(res), "not accepted")
})

test_that("anova() of nested fits is unchanged: its LR is the discrepancy difference", {
  f1 <- fit_sem(ur_model, ur_data())
  f0 <- fit_sem(paste0(ur_model, "\na == 0"), ur_data())
  an <- suppressWarnings(anova(f0, f1))
  lr <- f1@n_obs * (f0@f - f1@f)
  expect_equal(max(an[["Chisq diff"]], na.rm = TRUE), lr, tolerance = 1e-6)
})

test_that("planted defect: taking the minimum over the surviving refits would hide the failure", {
  fit <- fit_sem(ur_model, ur_data())
  testthat::local_mocked_bindings(.sem_fit_syntax = ur_failing(1L))
  res <- suppressWarnings(mbco_sem(fit, "a", "b"))
  survivors_min <- min(res$tests$diff_ll, na.rm = TRUE)
  expect_true(is.finite(survivors_min))
  # the reported statistic must differ from that minimum: it is NA
  expect_false(isTRUE(all.equal(unname(res$statistic), survivors_min)))
})
