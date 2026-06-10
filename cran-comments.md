## Submission

This is a resubmission of medfit (version 0.2.0), addressing the CRAN
reviewer's feedback on the initial submission:

* Removed `+ file LICENSE` from the `License` field and deleted the
  accompanying `LICENSE` file. The package is now licensed under a plain
  `GPL (>= 3)` with no additional restrictions.
* Single-quoted the software names 'probmed', 'RMediation', and 'medrobust'
  in the Description field.

## Test environments

* Local: macOS 26.5.0 (Tahoe), R 4.6.0 — `R CMD check --as-cran`
* win-builder (R-devel) — via `devtools::check_win_devel()`
* GitHub Actions (ubuntu-latest): R-release, R-devel, R-oldrel-1
* GitHub Actions (macos-latest): R-release
* GitHub Actions (windows-latest): R-release

## R CMD check results

0 errors | 0 warnings | 1 note

* New submission - This is the first submission of medfit to CRAN

## Downstream dependencies

There are currently no downstream dependencies for this package.
