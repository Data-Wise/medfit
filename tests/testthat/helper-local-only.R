# skip_unless_local(): the "local-only" tier (PLAN: planning/PLAN-local-only-tier-2026-11-26.md).
# A test file that alone costs more than about 5 minutes on a hosted runner starts with this call. It skips on CRAN
# (`skip_on_cran()`) and on any CI service (`skip_on_ci()`, true when the `CI` environment variable is "true"), and
# runs on the maintainer's machine, where NOT_CRAN=true and CI is unset (devtools::test() and
# scripts/check-local-full.sh set NOT_CRAN). A release needs a green local full-run receipt for the release commit
# (scripts/check-local-full.sh), because hosted CI no longer runs these files.
skip_unless_local <- function() {
  testthat::skip_on_cran()
  testthat::skip_on_ci()
  invisible(TRUE)
}
