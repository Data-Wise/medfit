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
