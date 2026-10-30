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

test_that("monthly QC propagates PR gate failures after uploading artifacts", {
  f <- wf_path("workflows", "qc-monthly.yaml")
  skip_if_not(file.exists(f), "no .github directory (installed package)")
  skip_if_not_installed("yaml")
  steps <- yaml::read_yaml(f)$jobs$gates$steps
  names <- vapply(steps, function(x) if (is.null(x$name)) "" else x$name, "")
  gate <- which(names == "Run the gates of this shard (--sim)")
  upload <- which(vapply(steps, function(x) {
    if (is.null(x$uses)) FALSE else startsWith(x$uses, "actions/upload-artifact@")
  }, TRUE))
  final <- which(names == "Fail PR shard when its gate failed")
  expect_length(gate, 1L)
  expect_length(upload, 1L)
  expect_length(final, 1L)
  if (length(final) != 1L) return()
  expect_true(gate < upload && upload < final)
  expect_true(isTRUE(steps[[gate]][["continue-on-error"]]))
  expect_identical(steps[[final]]$`if`, "always() && github.event_name == 'pull_request'")
  script <- steps[[final]]$run
  expect_match(script, "steps.gate.outcome", fixed = TRUE)
  for (outcome in c("success", "failure")) {
    path <- withr::local_tempfile(fileext = ".sh")
    writeLines(gsub("${{ steps.gate.outcome }}", outcome, script, fixed = TRUE), path)
    result <- suppressWarnings(system2("sh", path, stdout = TRUE, stderr = TRUE))
    status <- attr(result, "status")
    if (outcome == "success") expect_null(status) else expect_identical(status, 1L)
  }
})

test_that("coverage skips only an explicit metadata decision and preserves release triggers", {
  f <- wf_path("workflows", "test-coverage.yaml")
  skip_if_not(file.exists(f), "no .github directory (installed package)")
  skip_if_not_installed("yaml")
  workflow <- yaml::read_yaml(f)
  # YAML 1.1 readers can interpret the unquoted GitHub 'on' key as TRUE.
  triggers <- workflow[[if ("on" %in% names(workflow)) "on" else "TRUE"]]
  expect_setequal(triggers$push$branches, c("main", "dev"))
  expect_identical(triggers$pull_request$branches, "dev")
  expect_null(triggers$push$paths)
  expect_null(triggers$push$`paths-ignore`)
  expect_null(triggers$pull_request$paths)
  expect_null(triggers$pull_request$`paths-ignore`)
  scope <- workflow$jobs$`coverage-scope`
  expect_identical(scope$outputs$run_coverage, "${{ steps.scope.outputs.run_coverage }}")
  expect_identical(scope$steps[[1]]$with$`fetch-depth`, 0L)
  expect_identical(scope$steps[[2]]$run,
                   "python3 -m unittest discover -s .github/scripts -p test_coverage_scope.py")
  expect_identical(scope$steps[[3]]$id, "scope")
  expect_identical(scope$steps[[3]]$run, "python3 .github/scripts/coverage_scope.py")
  coverage <- workflow$jobs$`test-coverage`
  expect_identical(coverage$needs, "coverage-scope")
  expect_identical(coverage$`if`, paste0(
    "${{ !cancelled() && (needs.coverage-scope.result != 'success' || ",
    "needs.coverage-scope.outputs.run_coverage != 'false') }}"
  ))
})

test_that("coverage scope regression scenarios pass in a checkout", {
  scripts <- wf_path("scripts")
  skip_if_not(file.exists(file.path(scripts, "test_coverage_scope.py")), "no workflow scripts")
  python <- Sys.which("python3")
  skip_if_not(nzchar(python), "python3 unavailable")
  result <- suppressWarnings(system2(python, c(
    "-m", "unittest", "discover", "-s", shQuote(scripts), "-p", "test_coverage_scope.py"
  ), stdout = TRUE, stderr = TRUE))
  expect_null(attr(result, "status"), info = paste(result, collapse = "\n"))
})
