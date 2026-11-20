# S7 1.0.0 drops a property passed to `new_object()` as `call = call` (its dots collector has a `call` formal).
# `.s7_call_safe()` (R/aac-s7-compat.R) rebuilds the four classes with a `call` property; these checks fail without
# it under S7 >= 1.0.0 and pass under 0.2.2 either way. Run the suite against both versions when touching it.

test_that("the four classes with a call property keep @call", {
  cl <- quote(f(x = 1))
  boot <- BootstrapResult(
    estimate = 0.2, ci_lower = 0.1, ci_upper = 0.3, ci_level = 0.95,
    boot_estimates = c(0.1, 0.2, 0.3), n_boot = 3L, method = "nonparametric", call = cl
  )
  expect_identical(boot@call, cl)

  td <- tl_td(call = "lavaan::sem(model)")
  expect_identical(td@call, "lavaan::sem(model)")
  tdp <- tlp_td(call = "lavaan::sem(model)")
  expect_identical(tdp@call, "lavaan::sem(model)")

  fit <- fit_sem("mediator1 ~ a*treatment\noutcome ~ b*mediator1 + treatment", mediation_demo)
  expect_true(is.call(fit@call))
})

test_that("the call-safe constructors keep the generated formals", {
  for (cls in list(BootstrapResult, SEMFit, TwoLevelMediationData, TwoLevelParallelMediationData)) {
    expect_identical(names(formals(cls)), names(cls@properties))
  }
})
