# Guards for two mistakes found in review of the 0.11.0 CI work (Codex R4, 2026-10-17): the weekly S7 watch ran its
# lifecycle gate with the failure mutant planted unconditionally (a trial commit's edit survived a silent
# `git revert`), and its seen-version file still held the trial placeholder. The workflow files live in the repository
# checkout, not in the installed package, so these run on a checkout (the CI jobs) and skip elsewhere.

wf_path <- function(...) testthat::test_path("..", "..", ".github", ...)

test_that("the S7 watch plants the gate mutant only on request", {
  f <- wf_path("workflows", "s7-watch.yaml")
  skip_if_not(file.exists(f), "no .github directory (installed package)")
  lines <- readLines(f)
  mut <- grep("^\\s*MUTANT:", lines, value = TRUE)
  expect_length(mut, 1L)
  expect_match(mut, "force_gate_failure", info = "MUTANT must be conditional on the force_gate_failure input")
  expect_false(any(grepl("^\\s*MUTANT:\\s*[A-Za-z]", lines)), info = "an unconditional MUTANT literal is planted")
  expect_false(any(grepl("^\\s*push:", lines)), info = "the trial push trigger was left in")
})

test_that("the S7 watch's seen version is a real CRAN version, not a trial placeholder", {
  f <- wf_path("s7-cran-seen.txt")
  skip_if_not(file.exists(f), "no .github directory (installed package)")
  v <- trimws(readLines(f, n = 1L))
  expect_match(v, "^[0-9]+\\.[0-9]+\\.[0-9]+$")
  expect_false(identical(v, "0.0.0"), info = "the trial value 0.0.0 would open an issue on the first scheduled run")
})

test_that("planted defect: the checks above reject the two mistakes they guard against", {
  bad <- c("        env:", "          MUTANT: nounion")
  good <- c("        env:",
            "          MUTANT: ${{ github.event.inputs.force_gate_failure == 'true' && 'nounion' || '' }}")
  literal <- function(x) any(grepl("^\\s*MUTANT:\\s*[A-Za-z]", x))
  expect_true(literal(bad))
  expect_false(literal(good))
})
