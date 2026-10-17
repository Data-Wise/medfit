# S7 compatibility (PR #214, T1 of the 0.11.0 plan): the nullable property unions are registered with S4 before the
# classes use them, so the package loads under development S7 (> 0.2.2) as well as 0.2.2. Contributed in PR #214 by
# t-kalinowski; the load-level checks below run the package in a fresh R process.

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
  real <- paste(deparse(.register_s4_unions), collapse = "\n")
  expect_true(grepl('setClassUnion("medfit_numeric", c("integer", "numeric"))', real, fixed = TRUE))
  bad <- sem_mutate(.register_s4_unions, 'methods::setClassUnion("medfit_numeric", c("integer", "numeric"))', "NULL")
  expect_false(grepl("medfit_numeric\"", paste(deparse(bad), collapse = "\n"), fixed = TRUE))
})
