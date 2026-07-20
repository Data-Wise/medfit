## R CMD check results

0 errors | 0 warnings | 0 notes (expected)

Checked with `devtools::check(cran = TRUE, args = "--run-donttest", env_vars =
c(_R_CHECK_DEPENDS_ONLY_ = "true", _R_CHECK_SUGGESTS_ONLY_ = "true",
_R_CHECK_CRAN_INCOMING_ = "true", _R_CHECK_CRAN_INCOMING_REMOTE_ = "true"))`
on R 4.6.1 (macOS, aarch64): 0/0/0 (this machine has no local `aspell`, so
the DESCRIPTION spell-check sub-check does not run here). `urlchecker::url_check()`
and `spelling::spell_check_package()` both clean.

win-builder (R-release 4.6.1, R-oldrelease 4.5.3, R-devel r90279 -- all of
which do run `aspell`) checked this same source as 0.3.1, before the
Version bump to 0.3.2 (no code change since, only Version/Date/NEWS -- see
"Submission timing" below for why); it reported 1 NOTE on every flavor:

  Possibly misspelled words in DESCRIPTION:
    VanderWeele (20:42)

This is the cited author's surname (VanderWeele 2014, four-way decomposition
method reference), not a misspelling. Added `.aspell/defaults.R` with
`description <- list(ignore = c("VanderWeele"))` (PR #51, merged to dev) to
suppress it via R's documented package-defaults mechanism
(`?aspell-utils`). Re-dispatched win-builder (all 3 flavors) against the
0.3.2 source on 2026-07-20 to confirm; results pending.

## Submission timing

This release respects the CRAN 1-2 month update cadence: medfit 0.2.1 was
accepted 2026-06-18; this submission is on/after 2026-07-18 (>= 1 month
later), so no "Days since last update" NOTE is expected. Version 0.3.2
(rather than 0.3.1) only to avoid colliding with an existing unreleased
GitHub tag of the same number; no CRAN version of medfit has ever been
0.3.x before this submission.

## Reverse dependencies

One reverse dependency on CRAN: RMediation (via Suggests). RMediation's full
test suite (307 tests) run against this medfit build (0.3.1 source,
unchanged in 0.3.2): 0 failures, 0 warnings.
