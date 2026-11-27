# skip_unless_local(): the "local-only" tier (PLAN: planning/PLAN-local-only-tier-2026-11-26.md).
# The tier holds the majority of the test time (2026-11-27: 42 of 244 files, 84%, the slowest by hosted-mode
# seconds on the maintainer's machine; list and seconds in local-only-tests.txt). A test file in the tier starts
# with this call. It skips on CRAN (`skip_on_cran()`)
# and on any CI service (`skip_on_ci()`, true when the `CI` environment variable is "true"), and
# runs on the maintainer's machine, where NOT_CRAN=true and CI is unset (devtools::test() and
# scripts/check-local-full.sh set NOT_CRAN). A release needs a green local full-run receipt for the release commit
# (scripts/check-local-full.sh), because hosted CI no longer runs these files.
skip_unless_local <- function() {
  testthat::skip_on_cran()
  testthat::skip_on_ci()
  invisible(TRUE)
}
