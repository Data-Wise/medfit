## Release notes

This is medfit 0.21.1. The previous CRAN release is 0.3.2; versions 0.4.0 to 0.21.0 were released on GitHub only and
were not submitted to CRAN. 0.21.1 is the first submission since 0.3.2, so it carries all of that development. The
package code is identical to the GitHub release 0.21.0; 0.21.1 only makes the tests suitable for CRAN (see "Tests").

## Test environments

* local macOS (aarch64), R 4.6.2: `R CMD check --as-cran --run-donttest` with `NOT_CRAN` unset,
  `_R_CHECK_LIMIT_CORES_=TRUE` and the CRAN-incoming variables (`_R_CHECK_CRAN_INCOMING_`,
  `_R_CHECK_CRAN_INCOMING_REMOTE_`). Total time 4 minutes 7 seconds, of which the tests took 194 seconds.
  The same machine with `_R_CHECK_DEPENDS_ONLY_=true` and with `_R_CHECK_SUGGESTS_ONLY_=true`: no errors, no warnings.
* GitHub Actions: Ubuntu 24.04 (R release, R devel, R oldrel-1, and R release without the Suggests packages), macOS
  (R release) and Windows (R release), with the full test suite. All passed for 0.21.0, which has the same package
  code.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE: "Version jumps in minor (submitted: 0.21.1, existing: 0.3.2)". Expected,
  for the reason given under "Release notes".

## Tests

The 17 longest test files (maximum-likelihood oracle comparisons for the FIML, two-level and four-way routines) call
`skip_on_cran()`, so the check stays short. They run in full in the GitHub Actions jobs above and whenever
`NOT_CRAN=true`. The tests that remain on CRAN run 14,233 expectations with no failures and no warnings.

## Dependencies

Since 0.3.2 the package imports nloptr, rlang and lifecycle in addition to the earlier imports; all are on CRAN.
Suggests packages are used conditionally (`requireNamespace()` in code and `skip_if_not_installed()` in tests); the
`_R_CHECK_DEPENDS_ONLY_` pass above confirms the package checks without them.

## Downstream dependencies

RMediation lists medfit in Suggests; its test suite was run against medfit 0.21.0 (same package code) with no new
failure (587 tests pass). probmed imports medfit; its suite was run against the same build and shows the same single
failure with the previous release as with this one.
