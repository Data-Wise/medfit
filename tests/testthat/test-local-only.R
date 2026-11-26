# The local-only tier: skip_unless_local() skips on CRAN and on CI, runs locally; the tier list names real files.

skip_reason <- function(env) {
  withr::with_envvar(env, tryCatch(
    {
      skip_unless_local()
      NULL
    },
    skip = function(s) conditionMessage(s)
  ))
}

test_that("skip_unless_local() skips when CI is true", {
  expect_match(skip_reason(c(NOT_CRAN = "true", CI = "true")), "CI")
})

test_that("skip_unless_local() skips on CRAN (NOT_CRAN unset)", {
  expect_match(skip_reason(c(NOT_CRAN = NA, CI = NA)), "CRAN")
})

test_that("skip_unless_local() runs with NOT_CRAN=true and CI unset", {
  expect_null(skip_reason(c(NOT_CRAN = "true", CI = NA)))
})

test_that("planted defect: a helper without skip_on_ci() would not skip under CI", {
  naive <- function() testthat::skip_on_cran()
  r <- withr::with_envvar(
    c(NOT_CRAN = "true", CI = "true"),
    tryCatch(
      {
        naive()
        NULL
      },
      skip = function(s) "skipped"
    )
  )
  expect_null(r)
})

test_that("every file in the local-only list calls skip_unless_local() before any other code", {
  lst <- testthat::test_path("local-only-tests.txt")
  expect_true(file.exists(lst))
  files <- trimws(sub("#.*$", "", readLines(lst, warn = FALSE)))
  files <- files[nzchar(files)]
  expect_gt(length(files), 0L)
  for (f in files) {
    p <- testthat::test_path(f)
    expect_true(file.exists(p), info = f)
    code <- trimws(readLines(p, warn = FALSE))
    code <- code[nzchar(code) & !startsWith(code, "#")]
    expect_match(code[1], "^skip_unless_local\\(\\)", info = f)
  }
})

# ---- the local-only gate tier (tests/sim/gates-local-only.txt) ----
sim_root <- function() {
  root <- testthat::test_path("..", "..")
  testthat::skip_if(!file.exists(file.path(root, "tests", "sim", "gates.csv")), "tests/sim is not in the installed package")
  root
}

test_that("the local-only gate list names real gates and the drop helper honors --local-only", {
  root <- sim_root()
  source(file.path(root, "tests", "sim", "gate-tier-lib.R"), local = TRUE)
  lo <- gate_local_only(file.path(root, "tests", "sim", "gates-local-only.txt"))
  ids <- utils::read.csv(file.path(root, "tests", "sim", "gates.csv"), stringsAsFactors = FALSE)$gate
  expect_true("twolevel-equal-size" %in% lo)
  expect_true(all(lo %in% ids))
  expect_false("reliability" %in% lo) # the required check `gates (reliability)` must keep its gate
  spec <- data.frame(gate = c("parity", "twolevel-equal-size"))
  expect_identical(gate_drop_local_only(spec, lo, enabled = FALSE)$gate, "parity")
  expect_identical(gate_drop_local_only(spec, lo, enabled = TRUE)$gate, spec$gate)
})

test_that("run-gates.R drops a local-only gate unless --local-only is passed (planted control: parity stays)", {
  root <- sim_root()
  skip_on_cran()
  run <- function(args) {
    withr::with_dir(root, system2("Rscript", c("tests/sim/run-gates.R", args), stdout = TRUE, stderr = TRUE))
  }
  out <- run(c("--only", "twolevel-equal-size"))
  expect_true(any(grepl("local-only gates skipped", out, fixed = TRUE)))
  expect_false(any(grepl("twolevel-equal-size  ", out, fixed = TRUE))) # no verdict line for the dropped gate
  out2 <- run(c("--only", "twolevel-equal-size", "--local-only"))
  expect_false(any(grepl("local-only gates skipped", out2, fixed = TRUE)))
})

test_that("qc-monthly keeps the local-only gates; the hosted PR gates workflow does not pass --local-only", {
  root <- sim_root()
  qc <- readLines(file.path(root, ".github", "workflows", "qc-monthly.yaml"))
  expect_true(any(grepl("run-gates.R --sim --only \"$only\" --monthly --local-only", qc, fixed = TRUE)))
})
