## Resubmission

This is a resubmission of medfit as version 0.2.1, addressing the CRAN
reviewer's (Konstanze Lauseker) feedback on version 0.2.0:

* Explained the acronym in the Description text: "GLM" is now written out as
  "generalized linear models".
* Added references describing the methods to the Description field in the
  requested `authors (year) <doi:...>` form: MacKinnon, Lockwood, Hoffman,
  West and Sheets (2002) <doi:10.1037/1082-989X.7.1.83> and Tofighi and
  MacKinnon (2011) <doi:10.3758/s13428-011-0076-x>.
* Added `\value` tags documenting the return value (class and meaning) for the
  exported print methods that were missing them: `print.mediation_effect`,
  `print.summary.BootstrapResult`, `print.summary.MediationData`, and
  `print.summary.SerialMediationData`.
* Replaced `\dontrun{}` with `\donttest{}` for executable examples
  (the class constructors and `extract_mediation()`), rewriting them to be
  self-contained. The `extract_mediation_lavaan()` example is additionally
  guarded with `requireNamespace("lavaan")`.

Two examples remain wrapped in `\dontrun{}`: `fit_mediation()` and
`bootstrap_mediation()`. These functions are documented stubs that call
`stop("... not yet implemented")`, so their examples genuinely cannot be
executed and would error under `--run-donttest`.

The previous round (Uwe Ligges) had already been addressed in 0.2.0: removed
`+ file LICENSE` and the LICENSE file (now plain `GPL (>= 3)`), and
single-quoted the software names 'probmed', 'RMediation', and 'medrobust'.

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
