# PLAN: S7 1.0 readiness (2026-10-17)

**Status:** DRAFT for the author. Follows D1 of `PLAN-0.11.0-scope-2026-10-16.md` (closed 2026-10-17: S7 1.0.0 forces no
CRAN action today). This plan is the watch-and-verify work so that stays true. Nothing here blocks the 0.11.0 release.

## What is known (verified 2026-10-17)

- CRAN has S7 0.2.2 (2026-04-22). `NEWS.md` on S7 `main` has an unreleased "S7 1.0.0" section with no date.
- medfit already handles the one 1.0 mechanism that touched it (#219, #220): `.onLoad()` calls `S7_on_load()` when S7
  exports it (else `methods_register()`), `.onUnload()` calls `S7_on_unload()`, `R/zzz.R` calls `S7_on_build()` at
  top level, all guarded by `%in% getNamespaceExports("S7")` so S7 0.2.2 still works. The `s7-lifecycle` gate (12 rows,
  two mutants) installs, loads, uses, unloads and reloads against S7 0.2.2 and `S7@main`; it passed at Checkpoint 2.

## Audit against the 1.0.0 breaking-change list (grep of `R/`, 2026-10-17)

| 1.0.0 change | medfit exposure | Evidence |
|---|---|---|
| `convert()` upcast and sibling rules | none | no `convert(` in `R/` |
| `S7_on_build()` for external generics | handled | `R/zzz.R` top level, guarded |
| subclass constructors, parent constructors | none | no `parent =` in any `new_class()`; 8 flat classes |
| reserved `_` property names | none | no property or argument starts with `_` |
| `new_object()` / `set_props()` argument names | none | neither is called |
| `new_property()` complex-default warning (future error) | low | only default is `NULL` (`kr_df`, `R/classes.R:1920`) |
| `method<-()` on S7 unions expands per class | not audited | medfit registers its own unions as S4 (`R/classes.R:33`) and `method<-` on external generics (`print`, `show`, `coef`, `vcov`, `nobs`, `confint`, `summary`, `AIC`, `BIC`, `logLik`, `anova`) |

## Not known

1. Whether medfit's **full test suite** passes on `S7@main`. The lifecycle gate runs construct, show, fit, tidy, unload and
   reload only; #214's contributor did not run the suite either. This is the largest gap.
2. The S7 1.0.0 release date, and what CRAN's revdep process does to a package whose S4 unions break (CRAN 0.3.2 is
   OK on all 13 flavors today).
3. Whether probmed and RMediation (Suggests/Imports of medfit's classes) have their own S7 1.0 exposure.

## S1 result (2026-10-17, DONE)

Full suite on `S7@main` (version 0.2.2.9000, `S7_on_build` exported), medfit installed from `dev` (`047a90f` plus docs) into a
scratch library, `testthat::test_dir(package = "medfit", load_package = "installed")`, `NOT_CRAN=true`: **6397 passed,
0 failed, 0 errors, 1 skipped (the lavaan-absence test, by design), 0 warnings**, identical to the S7 0.2.2 count at
Checkpoint 2. The unknown "does the suite pass on S7 1.0 development" is answered for today's `main`. A first attempt was
killed mid-run when launched as a bare `&` job (no result line); the rerun under a tracked background task completed. Not
covered: S7 changes after today (S5), and the `method<-` probe (S3).

## S3 result (2026-10-17, DONE for 5 of 8 classes)

Fresh R process, medfit installed from `dev`, objects of five classes (MediationData, SEMFit, BootstrapResult,
ParallelMediationData, SerialMediationData; fit from `mediation_demo`), 15 generics each (75 calls: print, show, summary,
coef, vcov, nobs, confint, nie, nde, te, pm, paths, tidy, glance, logLik, AIC, BIC), then `unloadNamespace("medfit")`,
`library(medfit)` and the same 75 calls again. Result on **S7 0.2.2.9000 (main) and on CRAN S7 0.2.2 is identical:
65 of 75 calls succeed before and after the reload; the same 10 calls report "no method" in all four runs** (`nie`,
`nde`, `te`, `pm`, `paths` on SEMFit; `nobs`, `nde`, `te`, `pm`, `paths` on BootstrapResult). Those 10 are the existing
design (effect generics exist for the extracted data classes; a SEMFit goes through `extract_mediation()`), not an S7
1.0 difference. Not probed: InteractionMediationData, JointMediationData, ClusterMediationData (their method tables come
from the same registration code and the green full suite on S7 `main` exercises them; a probe needs their fixtures).
Script: not committed (scratch); the shape is in this paragraph.

## Tasks

| # | Task | Done when | Size |
|---|---|---|---|
| S1 (DONE 2026-10-17, 6397/0) | Run the full suite on `S7@main` in a scratch library (installed medfit, not `load_all()`), triage every failure against the S7 0.2.2 baseline | pass/fail counts quoted; each new failure is a medfit bug, an S7 bug (issue filed upstream) or a test that assumed 0.2.2 | S, 1 h |
| S2 | If S1 is green, add the full-suite run as an optional `--sim` step of the lifecycle gate (skips never count: a missing S7@main is a failed row, as now); if S1 finds failures, fix and add a red test per failure | gate row exists, planted defect exits 1 | S-M |
| S3 (DONE 2026-10-17, 5 of 8 classes) | Probe the not-audited row: unload medfit, reload, and call every `method<-` generic on one object per class under `S7@main` | one transcript, 8 classes, 0 errors | S, 1 h |
| S4 | Check probmed and RMediation against `S7@main` (their suites, medfit installed from `dev`) | counts quoted, or an issue in each repo | S, 1 h each; cross-repo writes need the author's go |
| S5 | Watch trigger: when CRAN's S7 page shows 1.0.0 (or a CRAN mail names medfit), rerun S1 and S3 on the released version within 3 days and decide 0.3.3 versus submitting the current medfit | decision recorded in `.STATUS` | at trigger |
| S6 | Decide the DESCRIPTION floor: `S7 (>= 0.1.0)` is untested below 0.2.2; either test the floor or raise it | floor tested or raised, NEWS note if raised | S |

## Decisions for the author

| # | Decision | Recommended |
|---|---|---|
| E1 | When to run S1 | Before the 0.11.0 release PR: it is an hour, and a red result changes what 0.11.0 says about S7 |
| E2 | How to detect the S7 release | A scheduled weekly check of CRAN's S7 page (a cheap `Monitor`-style poll, not a model loop) |
| E3 | S4 across repos | Run S4 read-only first; open issues rather than editing probmed or RMediation |

## Risks

- A green S7@main run today does not cover S7 changes between now and the release; S5 is the guard, not S1.
- The audit is a grep, not a read of the S7 1.0 source; S1 and S3 are the executable checks.
- If S1 shows a medfit failure that CRAN 0.3.2 shares, D1 reopens (the installed 0.3.2 would break on 1.0.0).
