# Risk tier of a pull request (tests/sim/risk-lib.R, risk-tier.R): the rule the `risk-tier` workflow applies, with
# planted cases (a missing item, an n/a without a reason) that must fail and controls that must pass.

lib <- test_path("..", "sim", "risk-lib.R")
skip_if_not(file.exists(lib), "tests/sim is not shipped with the installed tests")
root <- normalizePath(test_path("..", ".."))
env <- new.env(parent = globalenv())
sys.source(lib, envir = env)
rf <- readLines(file.path(root, "tests", "sim", "risk-files.txt"), warn = FALSE)
full <- paste0("- [x] ", seq_along(env$risk_items), ". ", env$risk_items, collapse = "\n")

test_that("every risk file exists, so a rename cannot silently switch the tier off", {
  skip_if_not(file.exists(file.path(root, "R", "sem-ml.R")), "R sources are not shipped with the installed tests")
  expect_true(length(rf) >= 7L)
  for (f in rf) expect_true(file.exists(file.path(root, f)), info = f)
})

test_that("a PR touching no optimizer file is low risk, and so is a release PR from dev", {
  expect_false(env$risk_check(c("R/sem-anova.R", "NEWS.md"), rf, "")$high)
  expect_false(env$risk_check("R/sem-optim.R", rf, "", head_ref = "dev")$high)
})

test_that("a PR touching an optimizer file needs all seven items, ticked or n/a with a reason", {
  r <- env$risk_check(c("R/sem-optim.R", "README.md"), rf, full)
  expect_true(r$high)
  expect_identical(r$files, "R/sem-optim.R")
  expect_length(r$missing, 0L)
  na_body <- paste0(paste0("- [x] ", 1:6, ". x", collapse = "\n"), "\n- [ ] 7. n/a: no runner change")
  expect_length(env$risk_check("R/sem-ml.R", rf, na_body)$missing, 0L)
})

test_that("planted defects: a missing item, an n/a without a reason and an empty body are each refused", {
  missing_two <- sub("- \\[x\\] 2\\. [^\n]*\n", "", full)
  expect_identical(env$risk_check("R/sem-fit.R", rf, missing_two)$missing, 2L)
  bare_na <- paste0(paste0("- [x] ", 1:6, ". x", collapse = "\n"), "\n- [ ] 7. n/a:")
  expect_identical(env$risk_check("R/sem-fit.R", rf, bare_na)$missing, 7L)
  expect_length(env$risk_check("tests/sim/gates.csv", rf, "")$missing, 7L)
  expect_length(env$risk_check("tests/sim/gates.csv", rf, NA_character_)$missing, 7L)
})
