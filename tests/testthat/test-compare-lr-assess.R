# The detection rules of compare_lr() on injected results (#249, plan T1): a warning needs observed evidence, never an
# LR value alone; an unresolved reference or a model mismatch assigns no fault.

assess <- function(engine, ref = lr_ref(), ...) { # nolint: object_usage_linter.
  medfit:::.lr_assess(ref, list(engine), ...)
}
classes_of <- function(x) unlist(lapply(x$conditions, function(cnd) class(cnd)[1L]))

test_that("a fit that agrees with the reference gives agree and no conditions", {
  out <- assess(lr_engine(runs = list(lr_run(lr = 0.5), lr_run("zero", lr = 0.5))))
  expect_identical(out$verdict, "agree")
  expect_length(out$conditions, 0L)
  expect_identical(out$runs$status, c("agree", "agree"))
})

test_that("an OpenMx fit that violates the product constraint warns constraint_dropped", {
  out <- assess(lr_engine("openmx", list(lr_run("zero", lr = 0, residual = 0.027, jac_zero_at_start = TRUE))),
                ref = lr_ref(lr = 0.8))
  expect_identical(out$verdict, "disagree")
  expect_identical(classes_of(out), "medfit_warning_engine_constraint_dropped")
  expect_match(conditionMessage(out$conditions[[1L]]), "openmx 9.9.9.*violates the product constraint.*zero start")
})

test_that("a valid zero-LR null fit does not warn: LR = 0 alone is no evidence", {
  # the unrestricted optimum satisfies the null, so the correct restricted fit also has LR = 0 and no residual
  out <- assess(lr_engine("openmx", list(lr_run("zero", lr = 0, residual = 1e-9))), ref = lr_ref(lr = 0))
  expect_identical(out$verdict, "agree")
  expect_length(out$conditions, 0L)
})

test_that("a statistic above the accepted restricted maximum warns statistic_above_max, for either engine", {
  for (eng in c("lavaan", "openmx")) {
    out <- assess(lr_engine(eng, list(lr_run(lr = 0.9))), ref = lr_ref(lr = 0.5))
    expect_identical(out$verdict, "disagree")
    expect_identical(classes_of(out), "medfit_warning_engine_statistic_above_max")
  }
})

test_that("an unresolved or rejected reference gives unresolved and assigns no fault", {
  out <- assess(lr_engine("lavaan", list(lr_run(lr = 5))), ref = lr_ref(lr = 0.5, accepted = FALSE))
  expect_identical(out$verdict, "unresolved")
  expect_length(out$conditions, 0L)
  expect_identical(out$runs$status, "unresolved")
})

test_that("a failed model precheck gives unresolved, naming the differing parameter, and no warning", {
  out <- assess(lr_engine("lavaan", list(lr_run(lr = 5)), est = c(a = 0.1, b = 0.9, cp = 0.3)), ref = lr_ref(lr = 0.5))
  expect_identical(out$verdict, "unresolved")
  expect_length(out$conditions, 0L)
  expect_match(out$reason, "b")
})

test_that("a difference within tolerance agrees; beyond it, below the reference, disagrees without fault", {
  tol <- 1e-4 * max(1, 2)
  expect_identical(assess(lr_engine(runs = list(lr_run(lr = 2 + 0.5 * tol))), ref = lr_ref(lr = 2))$verdict, "agree")
  below <- assess(lr_engine(runs = list(lr_run(lr = 1.5, residual = 0))), ref = lr_ref(lr = 2))
  expect_identical(below$verdict, "disagree")
  expect_length(below$conditions, 0L) # medfit may be the worse optimum: reported, not blamed
  expect_identical(below$runs$status, "below_reference")
})

test_that("a run that did not converge is reported failed with no fault", {
  out <- assess(lr_engine(runs = list(lr_run(converged = FALSE, lr = NA_real_))))
  expect_identical(out$runs$status, "failed")
  expect_length(out$conditions, 0L)
})

test_that("tolerance scales with max(1, LR): a large LR tolerates a larger absolute gap", {
  expect_identical(assess(lr_engine(runs = list(lr_run(lr = 100.005))), ref = lr_ref(lr = 100))$verdict, "agree")
  expect_identical(assess(lr_engine(runs = list(lr_run(lr = 100.05))), ref = lr_ref(lr = 100))$verdict, "disagree")
})

test_that(".lr_signal() raises each condition with its class and the parent class", {
  out <- assess(lr_engine("lavaan", list(lr_run(lr = 0.9))), ref = lr_ref(lr = 0.5))
  expect_warning(medfit:::.lr_signal(out), class = "medfit_warning_engine_statistic_above_max")
  expect_warning(medfit:::.lr_signal(out), class = "medfit_warning_engine_comparison")
})

test_that("the check can fail: a detector that keys on LR = 0 would accuse the valid zero-LR fit", {
  naive <- function(run) isTRUE(run$lr == 0)
  expect_true(naive(lr_run("zero", lr = 0, residual = 1e-9))) # the planted defect warns on a valid fit
  out <- assess(lr_engine("openmx", list(lr_run("zero", lr = 0, residual = 1e-9))), ref = lr_ref(lr = 0))
  expect_length(out$conditions, 0L) # the real rule does not
})
