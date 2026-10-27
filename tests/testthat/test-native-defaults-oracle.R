# Fast subset of the native-defaults oracle matrix (0.14.0 plan T8a and T8b, spec R-12, E-11): the simple cell under
# the old and the 0.15.0 settings and the unset fit, the named-subset cell, and the product, factor and lenient cells,
# against lavaan; the planted defects fixedx_logical (a named subset translated as all-fixed) and product_free (the
# unset leaves the product column free) must turn cells red. Full matrix: tests/sim/native-defaults-oracle.R.

skip_if_not_installed("lavaan")
ndo_lib <- test_path("..", "sim", "native-defaults-oracle-lib.R")
skip_if_not(file.exists(ndo_lib), "tests/sim is not shipped with the installed tests")
source(ndo_lib, local = TRUE)

test_that("the simple cell agrees with lavaan under the old and new settings and through the unset fit", {
  d <- ndo_data()
  for (combo in c("fx=FALSE ms=NULL", "fx=TRUE ms=TRUE", "unset")) {
    r <- ndo_cell_rows("simple", combo, d)
    expect_true(all(r$status %in% c("pass", "limit")), info = combo)
    expect_false(any(r$status == "fail"), info = paste(combo, paste(r$quantity[r$status == "fail"], collapse = ",")))
  }
  opt <- ndo_cell_rows("simple", "unset", d)
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

test_that("T8b: product, factor and lenient cells agree with lavaan, and the unset fit resolves the expected subset", {
  d <- ndo_data_b()
  cases <- list(product = c("fx=TRUE ms=TRUE", "fx=x,c ms=TRUE", "unset"), factor = c("fx=g ms=TRUE", "unset"),
                lenient = c("fx=x ms=TRUE", "unset"))
  for (cell in names(cases)) {
    for (combo in cases[[cell]]) {
      r <- ndo_cell_rows(cell, combo, d)
      bad <- paste(r$quantity[r$status == "fail"], collapse = ",")
      expect_false(any(r$status == "fail"), info = paste(cell, combo, bad))
      expect_true(all(r$status[r$status != "pass"] == "limit"), info = paste(cell, combo))
      if (combo == "unset") {
        expect_identical(r$status[r$quantity == "same_as_explicit:fixed_x"], "pass", info = cell)
        expect_identical(r$native[r$quantity == "same_as_explicit:lenient_message"], as.numeric(cell == "lenient"),
                         info = cell)
      }
    }
  }
})

test_that("T8b planted defects: all-fixed subset and a free product column turn the new cells red", {
  d <- ndo_data_b()
  bad <- sem_mutate(medfit:::.sem_resolve_fixed_x, "sel <- fixed_x", "sel <- roles$ov_x")
  local({
    local_mocked_bindings(.sem_resolve_fixed_x = bad, .package = "medfit")
    r <- ndo_cell_rows("factor", "fx=g ms=TRUE", d)
    expect_true(all(c("npar", "logLik") %in% r$quantity[r$status == "fail"]))
  })
  free_products <- "sel <- setdiff(ov_x, c(free, grep(\":\", ov_x, fixed = TRUE, value = TRUE)))"
  bad2 <- sem_mutate(medfit:::.sem_default_fixed_x, "sel <- setdiff(ov_x, free)", free_products)
  local_mocked_bindings(.sem_default_fixed_x = bad2, .package = "medfit")
  r <- ndo_cell_rows("product", "unset", d)
  expect_true(all(c("same_as_explicit", "same_as_explicit:fixed_x") %in% r$quantity[r$status == "fail"]))
})
