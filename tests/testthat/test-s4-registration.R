# S7 compatibility (PR #214, T1 of the 0.11.0 plan): the nullable property unions are registered with S4 before the
# classes use them, so the package loads under development S7 (> 0.2.2) as well as 0.2.2. Contributed in PR #214 by
# t-kalinowski. These checks read the registry of the running test process; the installed-package lifecycle
# (install, load, use, unload, reload, under S7 0.2.2 and `RConsortium/S7@main`) is `tests/sim/s7-lifecycle-gate.R`,
# registered in `tests/sim/gates.csv`.

test_that("S4 show handles nullable bootstrap metadata", {
  result <- BootstrapResult(
    estimate = 0.2,
    ci_lower = 0.1,
    ci_upper = 0.3,
    ci_level = 0.95,
    boot_estimates = c(0.1, 0.2, 0.3),
    n_boot = 3L,
    method = "nonparametric",
    call = NULL
  )

  expect_null(result@call)
  expect_equal(
    capture.output(methods::show(result)),
    capture.output(print(result))
  )
})

test_that("the plain numeric union and the four nullable-property unions are registered with S4", {
  expect_true(methods::isClassUnion("medfit_numeric"))
  expect_true(methods::is(1L, "medfit_numeric"))
  expect_true(methods::is(1.5, "medfit_numeric"))
  expect_false(methods::is(NULL, "medfit_numeric"))
  for (u in c("medfit_numeric_or_NULL", "medfit_list_or_NULL", "medfit_data_frame_or_NULL", "medfit_call_or_NULL")) {
    expect_true(methods::isClassUnion(u), info = u)
    expect_true(methods::is(NULL, u), info = u)
  }
  expect_true(methods::is(1L, "medfit_numeric_or_NULL"))
  expect_true(methods::is(data.frame(), "medfit_data_frame_or_NULL"))
})

test_that("the S7 hooks are used only when the installed S7 exports them", {
  hooks <- c("S7_on_load", "S7_on_unload", "S7_on_build")
  has <- hooks %in% getNamespaceExports("S7")
  # either all three hooks exist (development S7) or none does (0.2.2): never a partial set that the package
  # would half-use
  expect_true(all(has) || !any(has))
  expect_true("methods_register" %in% getNamespaceExports("S7") || all(has))
})

test_that("planted: dropping the plain numeric union (the one S7 cannot find in an installed package) is caught", {
  fx_skip_covr()
  expect_true("medfit_numeric" %in% .register_s4_unions())
  bad <- sem_mutate(.register_s4_unions, 'medfit_numeric = c("integer", "numeric"),', "")
  expect_false("medfit_numeric" %in% bad())
})

test_that("registering the unions again is harmless and leaves them registered", {
  nms <- medfit:::.register_s4_unions()
  expect_setequal(nms, c(
    "medfit_numeric", "medfit_numeric_or_NULL", "medfit_list_or_NULL",
    "medfit_data_frame_or_NULL", "medfit_call_or_NULL"
  ))
  expect_true(all(vapply(nms, methods::isClassUnion, logical(1))))
  expect_no_error(BootstrapResult(
    estimate = 1, ci_lower = 0, ci_upper = 2, ci_level = 0.95,
    boot_estimates = c(0.5, 1.5), n_boot = 2L, method = "plugin",
    call = NULL
  ))
})
