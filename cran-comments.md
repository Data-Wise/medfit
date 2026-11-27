## Release notes

This is medfit 0.21.3. The previous CRAN release is 0.3.2; versions 0.4.0 to 0.21.2 were released on GitHub only and
were not submitted to CRAN. 0.21.3 is the next submission since 0.3.2, so it carries all of
that development, and the version jump is intentional. Two earlier uploads did not pass: 0.21.1.9000 (a development
version, sent by mistake and withdrawn by email on 2026-11-26) and 0.21.2 (archived by the pretest on 2026-11-27).

Changes since 0.21.2, answering its pretest: the Windows check took 11 minutes against the 10-minute limit, 452 s of it
in the tests. 33 more test files now call `skip_on_cran()`, which halves the test time under CRAN's settings (105 s to
53 s locally). The 0.21.2 pretest had no other new issue. This release also removes the `ERROR:from:upgrade:S7` issue open
on 0.3.2.

## Test environments

* local macOS (aarch64), R 4.6.2: `R CMD check --as-cran --run-donttest` on the 0.21.3 tarball, with `NOT_CRAN` unset,
  `_R_CHECK_LIMIT_CORES_=TRUE` and the CRAN-incoming variables. Result: 1 NOTE (the version jump). The tests take 43 s
  (142 s for the whole check). The 0.21.2 tarball took 87 s for its tests on the same machine and 452 s on the Windows
  pretest.
* GitHub Actions: Ubuntu 24.04 (R release, devel, oldrel-1 and R release without the Suggests packages), macOS and
  Windows (R release). The heaviest tests and simulation gates run on the maintainer's machine (a full local run, green
  for the release commit) rather than on hosted runners.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE: "Version jumps in minor (submitted: 0.21.3, existing: 0.3.2)". Expected,
  for the reason given under "Release notes".

## Tests

The slowest test files (maximum-likelihood oracle comparisons for the FIML, two-level and four-way routines, and the
simulation gates) call `skip_on_cran()`, so the check stays short. They run in full in the GitHub Actions jobs and the
maintainer's full local run, and whenever `NOT_CRAN=true`. The tests that remain on CRAN give 5,023 passing expectations
with no failures and no warnings.

## Dependencies

Since 0.3.2 the package imports nloptr, rlang and lifecycle in addition to the earlier imports; all are on CRAN.
Suggests packages are used conditionally (`requireNamespace()` in code and `skip_if_not_installed()` in tests); the
`_R_CHECK_DEPENDS_ONLY_` pass above confirms the package checks without them.

## Downstream dependencies

RMediation lists medfit in Suggests; its test suite was run against medfit 0.21.0 (same package code) with no new
failure (587 tests pass). probmed imports medfit; its suite was run against the same build and shows the same single
failure with the previous release as with this one.
