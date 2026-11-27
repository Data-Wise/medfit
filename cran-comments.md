## Release notes

This is medfit 0.21.2. The previous CRAN release is 0.3.2; versions 0.4.0 to 0.21.1 were released on GitHub only and
were not submitted to CRAN. 0.21.2 is the first submission since 0.3.2, so it carries all of that development, and
the version jump is intentional. An earlier upload (0.21.1.9000, a development version) was sent by mistake and
withdrawn by email on 2026-11-26.

Changes since the withdrawn upload, answering CRAN's pretest: the Rd file `SEMFit-methods.Rd` now has a `\usage`
section, and the slowest tests call `skip_on_cran()`, so the check time is below 10 minutes. This release also removes the
`ERROR:from:upgrade:S7` issue open on 0.3.2.

## Test environments

* local macOS (aarch64), R 4.6.2: `R CMD check --as-cran --run-donttest` on the tarball built from the release tag, with
  `NOT_CRAN` unset, `_R_CHECK_LIMIT_CORES_=TRUE` and the CRAN-incoming variables. TIMINGS_TBD
* GitHub Actions: Ubuntu 24.04 (R release, devel, oldrel-1 and R release without the Suggests packages), macOS and
  Windows (R release), with the full test suite.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE: "Version jumps in minor (submitted: 0.21.2, existing: 0.3.2)". Expected,
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
