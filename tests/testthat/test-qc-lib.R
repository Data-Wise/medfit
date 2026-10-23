# The weekly QC pieces (tests/sim/qc-lib.R, qc-metrics.R, qc-collect.R; plan Q-5): the alert rules and the history
# merge, each with a planted case that must fire and a control that must not.

lib <- test_path("..", "sim", "qc-lib.R")
skip_if_not(file.exists(lib), "tests/sim is not shipped with the installed tests")
root <- normalizePath(test_path("..", ".."))
env <- new.env(parent = globalenv())
sys.source(lib, envir = env)

qc_fixture <- function(...) {
  base <- list(date = "2026-10-23", sha = "abc", ref = "dev", r_version = "4.6.1", blas = "openblas-0.3.26",
               nloptr = "2.2.1", lavaan = "0.7.3", openmx = "2.22.11", image = "ubuntu24/20261020.1",
               gate_parity = "PASS", gate_restoration = "PASS", restoration_max_rho = 0.9998)
  as.data.frame(utils::modifyList(base, list(...)), stringsAsFactors = FALSE)
}

test_that("a clean run against an identical previous run raises no alert", {
  al <- env$qc_alerts(qc_fixture(), qc_fixture())
  expect_length(al$gate_failures, 0L)
  expect_length(al$env_changes, 0L)
})

test_that("a failing gate is an alert, and the first run (no history) can only alert on gates", {
  al <- env$qc_alerts(qc_fixture(gate_restoration = "FAIL"), qc_fixture())
  expect_identical(al$gate_failures, "restoration")
  al0 <- env$qc_alerts(qc_fixture(gate_parity = "FAIL"), NULL)
  expect_identical(al0$gate_failures, "parity")
  expect_length(al0$env_changes, 0L)
})

test_that("a changed R, BLAS, nloptr, lavaan or OpenMx is an alert; the runner image alone is not", {
  prev <- qc_fixture()
  for (k in c("r_version", "blas", "nloptr", "lavaan", "openmx")) {
    new <- qc_fixture()
    new[[k]] <- "changed"
    al <- env$qc_alerts(new, prev)
    expect_length(al$env_changes, 1L)
    expect_match(al$env_changes, paste0("^", k, ": "))
  }
  expect_length(env$qc_alerts(qc_fixture(image = "ubuntu24/20261101.1"), prev)$env_changes, 0L)
})

test_that("the planted-test flag adds a gate alert, so the issue path can be exercised on purpose", {
  expect_identical(env$qc_alerts(qc_fixture(), qc_fixture(), planted = TRUE)$gate_failures, "planted-test")
})

test_that("gate status lines are parsed from a run-gates summary and nothing else", {
  lines <- c("", "parity        PASS  [tests/sim/results/x.csv]", "  ok   results file   ok",
             "restoration   FAIL  [y.csv]", "  FAIL some check   detail", "fast          PASS  [NA]")
  expect_identical(env$qc_gate_status(lines), c(parity = "PASS", restoration = "FAIL", fast = "PASS"))
})

test_that("shard rows merge into one row and append to a history with aligned columns", {
  a <- qc_fixture(gate_restoration = NULL, restoration_max_rho = NULL)
  b <- qc_fixture(gate_parity = NULL)
  m <- env$qc_merge(list(a, b))
  expect_identical(nrow(m), 1L)
  expect_identical(m$gate_parity, "PASS")
  expect_identical(m$gate_restoration, "PASS")
  expect_equal(m$restoration_max_rho, 0.9998)
  h <- env$qc_append(qc_fixture(gate_restoration = NULL), qc_fixture(gate_new = "PASS"))
  expect_identical(nrow(h), 2L)
  expect_true(is.na(h$gate_new[1L]) && identical(h$gate_new[2L], "PASS"))
})

test_that("the collect script merges shard files, appends to a history and writes the alerts", {
  skip_if_not(nzchar(Sys.which("Rscript")))
  d <- withr::local_tempdir()
  for (sh in c("rest", "reliability")) dir.create(file.path(d, sh))
  utils::write.csv(qc_fixture(gate_restoration = NULL, restoration_max_rho = NULL),
                   file.path(d, "rest", "qc-metrics-rest.csv"), row.names = FALSE)
  utils::write.csv(qc_fixture(gate_parity = "FAIL", gate_restoration = NULL),
                   file.path(d, "reliability", "qc-metrics-reliability.csv"), row.names = FALSE)
  prev <- file.path(d, "history.csv")
  utils::write.csv(qc_fixture(blas = "older-blas"), prev, row.names = FALSE)
  out <- file.path(d, "out.csv")
  al <- file.path(d, "alerts.txt")
  res <- system2(file.path(R.home("bin"), "Rscript"),
                 c(file.path(root, "tests", "sim", "qc-collect.R"), file.path(d, "rest"), file.path(d, "reliability"),
                   "--history", prev, "--out", out, "--alerts", al), stdout = TRUE, stderr = TRUE)
  expect_null(attr(res, "status"))
  lines <- readLines(al)
  expect_true("gate: parity" %in% lines)
  expect_true(any(grepl("^env: blas: older-blas -> ", lines)))
  expect_identical(nrow(utils::read.csv(out)), 2L)
})
