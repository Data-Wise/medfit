## R CMD check results

0 errors | 0 warnings | 0 notes (expected)

Checked with `devtools::check(cran = TRUE, args = "--run-donttest", env_vars =
c(_R_CHECK_DEPENDS_ONLY_ = "true", _R_CHECK_SUGGESTS_ONLY_ = "true",
_R_CHECK_CRAN_INCOMING_ = "true", _R_CHECK_CRAN_INCOMING_REMOTE_ = "true"))`
on R 4.6.1 (macOS, aarch64): 0/0/0 (this machine has no local `aspell`, so
the DESCRIPTION spell-check sub-check does not run here). `urlchecker::url_check()`
and `spelling::spell_check_package()` both clean.

win-builder (R-release, R-oldrelease, R-devel -- all of which do run
`aspell`) iterated twice on this DESCRIPTION-only spelling check (a separate
mechanism from `spelling::spell_check_package()`, controlled by
`.aspell/defaults.R`, not `inst/WORDLIST`):

  1. Original 1 NOTE: "VanderWeele" (cited author surname). Fixed via
     `.aspell/defaults.R` (PR #51).
  2. Recheck surfaced a different 1 NOTE instead: "RMediation medrobust
     probmed" (single-quoted package names on the DESCRIPTION line citing
     the mediationverse ecosystem, text unchanged throughout). Extended the
     same ignore list to cover all 4 words (PR #54).

Re-dispatched win-builder (all 3 flavors) against the final 0.3.2 source
(commit 9b4d377) on 2026-07-20: R-release 4.5.3 and R-devel (r90279) both
returned `Status: OK`, no NOTEs -- the aspell fix (PR #54) is confirmed
clean on all checked flavors.

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
