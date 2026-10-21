# The OpenMx adapter of compare_lr() (#249 T3): real OpenMx on the bundled data and on the joint-null cell where OpenMx
# 2.19.1 or later drops the constraint at a zero start (T0 spike), plus the shared refusals.

skip_if_not_installed("OpenMx")

model_txt <- "mediator1 ~ a*treatment\noutcome ~ b*mediator1 + cp*treatment"
fit0 <- suppressWarnings(fit_sem(model_txt, mediation_demo))

test_that("OpenMx fits the same unrestricted model: same parameter keys, estimates and discrepancy", {
  ref <- medfit:::.lr_reference(fit0, c("a", "b"))
  eng <- medfit:::.lr_engine_openmx(fit0, c("a", "b"))
  expect_setequal(names(eng$est), names(ref$est))
  expect_equal(unname(eng$est[names(ref$est)]), unname(ref$est), tolerance = 1e-4)
  expect_equal(eng$fit, ref$fit, tolerance = 1e-6)
  expect_identical(vapply(eng$runs, function(r) r$start, ""), c("default", "zero"))
})

test_that("from medfit's default start OpenMx agrees with medfit on a well-behaved model", {
  ref <- medfit:::.lr_reference(fit0, c("a", "b"))
  eng <- medfit:::.lr_engine_openmx(fit0, c("a", "b"))
  out <- medfit:::.lr_assess(ref, list(eng))
  expect_identical(out$runs$status[out$runs$start == "default"], "agree")
})

test_that("the zero start flags the zero-Jacobian start, and a dropped constraint is caught as evidence", {
  eng <- medfit:::.lr_engine_openmx(fit0, c("a", "b"))
  zero <- eng$runs[[2L]]
  expect_true(zero$jac_zero_at_start)
  expect_false(eng$runs[[1L]]$jac_zero_at_start)
  # the known failure (OpenMx#433): at the zero start the product constraint is not enforced, the returned fit
  # violates it and the detector warns on that evidence (the residual), not on the LR value
  out <- medfit:::.lr_assess(medfit:::.lr_reference(fit0, c("a", "b")), list(eng))
  zero_status <- out$runs$status[out$runs$start == "zero"]
  expect_true(zero_status %in% c("agree", "constraint_violated", "above_reference", "below_reference"))
  if (identical(zero_status, "constraint_violated")) {
    classes <- vapply(out$conditions, function(cnd) class(cnd)[1L], "")
    expect_true("medfit_warning_engine_constraint_dropped" %in% classes)
  }
})

test_that("the joint-null cell: a violated constraint from the zero start is reported, never blamed on LR = 0 alone", {
  set.seed(2)
  n <- 100
  d <- data.frame(X = stats::rnorm(n), M = stats::rnorm(n))
  d$Y <- 0.3 * d$X + stats::rnorm(n)
  fit <- suppressWarnings(fit_sem("M ~ a*X\nY ~ b*M + cp*X", d))
  out <- medfit:::.lr_assess(medfit:::.lr_reference(fit, c("a", "b")),
                             list(medfit:::.lr_engine_openmx(fit, c("a", "b"))))
  zero <- out$runs[out$runs$start == "zero", ]
  # every status other than constraint_violated must come with a residual within the natural-unit tolerance
  if (zero$status != "constraint_violated") {
    expect_lte(zero$residual, 1e-4)
  } else {
    expect_gt(zero$residual, 1e-4)
  }
})

test_that("the shared refusals apply to the OpenMx adapter", {
  d <- mediation_demo
  expect_error(medfit:::.lr_engine_openmx(suppressWarnings(fit_sem(model_txt, d, fixed_x = TRUE)), c("a", "b")),
               "`fixed_x`", fixed = TRUE)
  expect_error(medfit:::.lr_engine_openmx(suppressWarnings(fit_sem(paste0(model_txt, "\ncp == 0"), d)), c("a", "b")),
               "constraints in the model", fixed = TRUE)
})

test_that("the tight OpenMx options are restored after a run", {
  before <- OpenMx::mxOption(NULL, "Optimality tolerance")
  invisible(medfit:::.lr_engine_openmx(fit0, c("a", "b")))
  expect_identical(OpenMx::mxOption(NULL, "Optimality tolerance"), before)
})
