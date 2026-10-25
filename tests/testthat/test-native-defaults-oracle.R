# Fast subset of the native-defaults oracle matrix (0.14.0 plan T8a, spec R-12): the simple cell under the old and
# the 0.15.0 settings and the opt-in, and the named-subset cell, against lavaan; the planted defect fixedx_logical (a
# named subset translated as all-fixed) must turn the subset cell red. Full matrix: tests/sim/native-defaults-oracle.R.

skip_if_not_installed("lavaan")
ndo_lib <- test_path("..", "sim", "native-defaults-oracle-lib.R")
skip_if_not(file.exists(ndo_lib), "tests/sim is not shipped with the installed tests")
source(ndo_lib, local = TRUE)

test_that("the simple cell agrees with lavaan under the old and new settings and through the opt-in", {
  d <- ndo_data()
  for (combo in c("fx=FALSE ms=NULL", "fx=TRUE ms=TRUE", "optin")) {
    r <- ndo_cell_rows("simple", combo, d)
    expect_true(all(r$status %in% c("pass", "limit")), info = combo)
    expect_false(any(r$status == "fail"), info = paste(combo, paste(r$quantity[r$status == "fail"], collapse = ",")))
  }
  opt <- ndo_cell_rows("simple", "optin", d)
  expect_identical(opt$status[opt$quantity == "same_as_explicit"], "pass")
})

test_that("the named-subset cell agrees with lavaan's fixed rows and the hand-calculated conditional likelihood", {
  r <- ndo_cell_rows("subset", "fx=c ms=TRUE")
  expect_setequal(unique(r$status), "pass")
  expect_true(all(c("npar", "df", "logLik", "AIC", "BIC") %in% r$quantity))
})

test_that("planted defect: a named subset translated as all-fixed fails the subset cell", {
  bad <- sem_mutate(medfit:::.sem_resolve_fixed_x, "sel <- fixed_x", "sel <- roles$ov_x")
  local_mocked_bindings(.sem_resolve_fixed_x = bad, .package = "medfit")
  r <- ndo_cell_rows("subset", "fx=c ms=TRUE")
  expect_true(all(c("npar", "logLik") %in% r$quantity[r$status == "fail"]))
})
