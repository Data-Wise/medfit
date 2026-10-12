# GRILL: medfit 0.8.0 release (T23)

**Date:** 2026-10-11 | **Checkpoint D evidence:** strict `devtools::check(cran = TRUE, args = "--run-donttest")` with the DEPENDS_ONLY, SUGGESTS_ONLY and CRAN_INCOMING(_REMOTE) variables on `dev` `743d9e8`: 0 errors, 0 warnings, 0 notes (56.6 s). Docs tests 443 passed, 0 failed.

| # | Question | Decision |
|---|---|---|
| R1 | Where does 0.8.0 ship? (Recommended: GitHub, then CRAN.) | **GitHub only**, as 0.5.0 to 0.7.0. Consequence recorded: RMediation's CRAN release stays blocked on a CRAN medfit (G3b), and CRAN 0.3.2 keeps the two silent bugs fixed on dev (serial `te()`/`pm()`, `confint()` path rows). RMediation work continues on its dev branch. |
| R2 | Does the release wait for a human review of Checkpoints A and C? (Recommended: wait.) | **No: release on the evidence.** The release PR body carries the evidence summary (strict check, gates, revdep, counts). |
| R3 | Version? | **0.8.0** (minor bump). Naming change is on an experimental class; the renamed arguments keep working through lifecycle. |

## What NEWS must say (T24 checklist)
- Behavior changes: `SEMFit` parameter names are lavaan's; `fit_sem(weights =)` and `mbco_sem(object, ...)` renames with lifecycle warnings.
- New: nonlinear constraints, zero-product branch split, sums of products (best-effort), `mbco_sem(paths =)` for k paths (size verified: at most 0.055 at alpha 0.05), `anova()`, `tidy()`/`glance()`/`confint()` for `SEMFit`, Newton polish.
- Documentation: lavaan article, cookbook recipes 12 and 13, 0.7.0 native-route wording corrected.
- Not in this release: CRAN submission, outcome-scale effects (0.9.0), the E1 version-matrix row (a cross-repo write that waits for an explicit request after the release).

## Release steps (T24, release engineering)
Version bump in `DESCRIPTION`, NEWS heading, `.STATUS`; grep the old version string across the repo; full suite and strict check on the release tree; `dev` to `main` merge-commit PR; CI green on `main`; tag `v0.8.0`; GitHub release; r-universe check (query the packages list, not `/api/packages/{pkg}`). No Netlify credit is involved (pkgdown on GitHub Pages).
