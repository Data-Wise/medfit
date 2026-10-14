# Native SEM engine: product rows in the parameter table (0.10.0 plan U2, amendment section 4 rule 7).
# The table's `rhs` is the canonical product, a duplicate within one equation is an error naming both spellings and
# the canonical name, and the same product in different equations shares one column. Everything here reads the
# parsed or completed table, never data. Positive controls: planted defects must turn the matching test red.

test_that("`x:m` alone and `m:x` alone yield the same row and the same coefficient name", {
  for (term in c("x:m", "m:x")) {
    tab <- .sem_parse(paste0("y ~ ", term))$parameters
    expect_identical(tab$rhs, "m:x", info = term)
    ram <- .sem_to_ram(.sem_complete(tab))$ram
    expect_true("y~m:x" %in% ram$par_names, info = term)
  }
})

test_that("a labeled product is named by its label", {
  ram <- .sem_to_ram(.sem_complete(.sem_parse("y ~ b*x:m + c*x")$parameters))$ram
  expect_true(all(c("b", "c") %in% ram$par_names))
  expect_false("y~m:x" %in% ram$par_names)
})

test_that("two spellings of one product in one equation are a duplicate, naming both and the canonical name", {
  msg <- "'x:m' and 'm:x' in the equation for 'y' are the same product \\(canonical name 'm:x'\\)"
  expect_error(.sem_parse("y ~ x:m + m:x"), msg)
  expect_error(.sem_parse("y ~ a*x:m + b*m:x"), msg) # conflicting labels
  expect_error(.sem_parse("y ~ 0.3*x:m + m:x"), msg) # conflicting fixed value
  expect_error(.sem_parse("y ~ x + m + x:m + w + m:x"), msg)
  # written order is kept in the message: reversed here
  expect_error(.sem_parse("y ~ m:x + x:m"), "'m:x' and 'x:m' in the equation for 'y'")
  # the same spelling twice is a duplicate too
  expect_error(.sem_parse("y ~ x:m + x:m"), "'x:m' and 'x:m' in the equation for 'y' are the same product")
  # across statements of one equation
  expect_error(.sem_parse("y ~ x:m\ny ~ m:x"), msg)
  # a duplicate at the same level only
  expect_error(.sem_parse("level: 1\ny ~ x:m\nlevel: 1\ny ~ m:x"), msg)
  expect_no_error(.sem_parse("level: 1\ny ~ x:m\nlevel: 2\ny ~ m:x"))
})

test_that("distinct products and a product beside its factors are not duplicates", {
  r <- .sem_parse("y ~ x:m + x:w + m:w + x + m + w")$parameters
  expect_identical(r$rhs, c("m:x", "w:x", "m:w", "x", "m", "w"))
  expect_no_error(.sem_parse("y ~ x:m\nm ~ x"))
})

test_that("the same product in different equations is allowed and gives separately named coefficients", {
  parsed <- .sem_parse("y ~ x:m\nz ~ m:x")
  expect_identical(parsed$parameters$lhs, c("y", "z"))
  expect_identical(parsed$parameters$rhs, c("m:x", "m:x"))
  tab <- .sem_complete(parsed$parameters)
  ram <- .sem_to_ram(tab)$ram
  expect_setequal(grep("^[yz]~m:x$", ram$par_names, value = TRUE), c("y~m:x", "z~m:x"))
  # one materialized column: the product is one observed variable in the completed model
  expect_identical(sum(ram$vars == "m:x"), 1L)
  expect_identical(sum(tab$op == "~~" & tab$lhs == "m:x" & tab$rhs == "m:x"), 1L)
  # a multi-left-side statement is the same thing
  expect_identical(.sem_parse("y, z ~ x:m")$parameters$rhs, c("m:x", "m:x"))
})

test_that("the product column is an exogenous observed variable with free variance, covariances and a mean", {
  tab <- .sem_complete(.sem_parse("m ~ x\ny ~ m + x + x:m")$parameters, meanstructure = TRUE)
  expect_true("m:x" %in% .sem_roles(tab)$ov_x)
  expect_true(any(tab$op == "~~" & tab$lhs == "m:x" & tab$rhs == "m:x" & is.na(tab$fixed)))
  expect_true(any(tab$op == "~~" & tab$lhs == "x" & tab$rhs == "m:x" & is.na(tab$fixed)))
  expect_true(any(tab$op == "~1" & tab$lhs == "m:x" & is.na(tab$fixed)))
  expect_identical(tab$rhs[tab$op == "~" & tab$lhs == "y"], c("m", "x", "m:x"))
})

test_that("the parsed and completed tables do not depend on data", {
  # neither the parser nor the completer takes data, so the table is the same however the model is later fitted
  expect_false("data" %in% names(formals(.sem_parse)))
  expect_false("data" %in% names(formals(.sem_complete)))
  expect_false("data" %in% names(formals(.sem_product_name)))
  model <- "m ~ x\ny ~ m + x + x:m"
  expect_identical(.sem_parse(model), .sem_parse(model))
  expect_identical(.sem_complete(.sem_parse(model)$parameters), .sem_complete(.sem_parse(model)$parameters))
  # the written order never leaks into the table
  expect_identical(
    .sem_complete(.sem_parse("m ~ x\ny ~ m + x + x:m")$parameters),
    .sem_complete(.sem_parse("m ~ x\ny ~ m + x + m:x")$parameters)
  )
})

test_that("planted defect: skipping canonicalization lets two spellings of one product through", {
  fx_skip_covr()
  # without the canonical name the reversed spelling is a different column name, so no duplicate is seen:
  # the model would reach the fit with two identical columns (lavaan: a singular-covariance failure)
  bad <- sem_mutate(.sem_product_name, "sort(c(a, b), method = \"radix\")", "c(a, b)")
  testthat::local_mocked_bindings(.sem_product_name = bad)
  expect_no_error(.sem_parse("y ~ x:m + m:x"))
  tab <- .sem_parse("y ~ x:m + m:x")$parameters
  expect_identical(tab$rhs, c("x:m", "m:x"))
})

test_that("planted defect: dropping the duplicate check, the specific error turns into the generic one or none", {
  fx_skip_covr()
  bad <- sem_mutate(.sem_parse, "which(is_prod & duplicated(pkey))", "integer()")
  testthat::local_mocked_bindings(.sem_parse = bad)
  # only the generic duplicate check is left: it stops the pair, but names neither spelling nor the canonical name,
  # so the test of the specific message goes red
  for (m in c("y ~ x:m + x:m", "y ~ x:m + m:x", "y ~ a*x:m + b*m:x")) {
    msg <- tryCatch(.sem_parse(m), error = conditionMessage)
    expect_match(msg, "specified more than once", info = m)
    expect_no_match(msg, "canonical name", info = m)
  }
})

test_that("planted defect: dropping the latent-product check lets `eta:x` through", {
  fx_skip_covr()
  bad <- sem_mutate(.sem_parse, "if (any(latent_hit))", "if (FALSE)")
  testthat::local_mocked_bindings(.sem_parse = bad)
  expect_no_error(.sem_parse("eta =~ m1 + m2 + m3\ny ~ eta:x"))
})

test_that("planted defect: a consumer that hard-codes the written spelling disagrees with the table", {
  fx_skip_covr()
  tab <- .sem_to_ram(.sem_complete(.sem_parse("y ~ x:m")$parameters))$ram
  expect_true(.sem_product_name("x", "m") %in% sub("^y~", "", tab$par_names))
  expect_false("x:m" %in% sub("^y~", "", tab$par_names))
})
