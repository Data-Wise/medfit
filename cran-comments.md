## R CMD check results

0 errors | 0 warnings | 1 note

Checked with `devtools::check(cran = TRUE, args = "--run-donttest", env_vars =
c(_R_CHECK_DEPENDS_ONLY_ = "true", _R_CHECK_SUGGESTS_ONLY_ = "true",
_R_CHECK_CRAN_INCOMING_ = "true", _R_CHECK_CRAN_INCOMING_REMOTE_ = "true"))`
on R 4.6.1 (macOS, aarch64): 0/0/0 (this machine has no local `aspell`, so
the DESCRIPTION spell-check sub-check does not run here). `urlchecker::url_check()`
and `spelling::spell_check_package()` both clean.

Confirmed via win-builder (R-devel 4.6.1 and R-release 4.5.3, both of which do
run `aspell`): 1 NOTE on both flavors --

  Possibly misspelled words in DESCRIPTION:
    VanderWeele (20:42)

This is the cited author's surname (VanderWeele 2014, four-way decomposition
method reference), not a misspelling.

## Submission timing

This release respects the CRAN 1-2 month update cadence: medfit 0.2.1 was
accepted 2026-06-18; this submission is on/after 2026-07-18 (>= 1 month
later), so no "Days since last update" NOTE is expected.

## Reverse dependencies

One reverse dependency on CRAN: RMediation (via Suggests). RMediation's full
test suite (307 tests) run against this medfit 0.3.1 build: 0 failures, 0
warnings.
