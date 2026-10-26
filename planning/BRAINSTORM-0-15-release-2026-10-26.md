# BRAINSTORM: medfit 0.15.0 (native defaults flip)

**Date:** 2026-10-26 | **Mode:** deep, arch focus | **Status:** draft for review
**Feeds:** `planning/specs/SPEC-0-15-release-2026-10-26.md`, `planning/PLAN-0.15.0-native-defaults-flip-2026-10-26.md`
**Inputs:** ADR `planning/specs/ADR-native-defaults-2026-10-24.md` (E-1 to E-15), `planning/specs/SPEC-native-defaults-2026-10-24.md`,
`planning/ISSUE-breaking-native-defaults-0.15.0.md` ([BREAKING] #329), 0.14.0 plan (Checkpoints A-C).

## Decisions recorded (user, 2026-10-26)

| Topic | Decision |
|---|---|
| Scope | Flip + AIC/BIC convention |
| #320 (`compare_lr()` lavaan LR above reference, ~30% of gate runs) | Re-measure first, then decide |
| Timing | Readiness-gated; floor 2026-12-24 |
| Dependents | Scratch-lib suites for all six + missingmed#102 merged |
| AIC/BIC | Keep medfit's parameter count, document it |
| Gate fails | Hold the flip, fix first |

## Quick Wins (< 30 min)
1. Re-measure #320 on current `dev` (one `compare-lr` gate dispatch): decides whether it blocks.
2. Add the missing-data docs note (listwise deletion, no FIML) to the 0.15.0 NEWS and `?"medfit-syntax"`.
3. Pin the AIC/BIC wording (medfit counts its own free parameters; lavaan's differs under `fixed_x`).

## Medium Effort (1-2 hrs each)
- [ ] Flip the formals in `fit_sem()` and `fit_mediation(engine = "native")`; resolver unconditional (E-14); obsolete-option note for `options(medfit.native_defaults)`.
- [ ] Update `test-api-freeze.R` and rewrite the 21 tests from the Checkpoint B list.
- [ ] Verify lavaan `fixed.x = TRUE` product-column handling (E-5 VERIFY) against an independent fit.
- [ ] Docs rewrite: lavaan-comparison reversal, crosswalk, cookbook 18/19, tutorial step 9, mini-book, guide-changes, NEWS.

## Long-term (future sessions)
- [ ] 0.16.0: remove the `options(medfit.native_defaults)` shim.
- [ ] 0.16.0 candidate: FIML (`missing = "fiml"`), spiked against lavaan first (see below).
- [ ] CRAN submission of the 0.15.0 line after soak (#83 still deferred).

## Architecture notes

**What the flip changes.** `fixed_x = TRUE` (resolved to an explicit character subset, E-13) and
`meanstructure = TRUE`. In the 557-row oracle matrix structural estimates and SEs did not move (503 pass, 54 limit,
0 block). What moves: logLik (becomes conditional), npar, AIC/BIC, parameter list and `coef()` names, and the retry
seed (hash of `ram$par_names`, R-11).

**Why readiness-gated.** The flip is the only 0.15.0 content; a date-driven release adds risk with no feature to
justify it. Gates, not the calendar, decide, with 2026-12-24 as the earliest date (the 2-month notice from #329).

**Hold-the-flip rule.** If a gate fails (E-12 reliability non-inferiority, oracle matrix, dependents), the flip does
not ship; fix first. No partial flip, no `fixed_x`-only variant.

**#320.** Treated as a measurement question first: if lavaan's product-null LR sitting above the reference is a
flagged, documented lavaan behavior, it stays a known limit; if it grew, it blocks.

## FIML research (extra topic)

medfit has no FIML: `R/sem-fit.R` drops incomplete rows (listwise). lavaan offers `missing = "fiml"` and `"ml.x"`
(the latter needs `fixed.x = FALSE`).

| Option | Verdict |
|---|---|
| FIML in 0.15.0 | **No.** Conflicts with the `fixed_x = TRUE` default, the `x:m` product term, centered coordinates, information/sandwich/weights, and the QC contract (new objective = new oracle, reliability cell, planted defect). |
| Docs note in 0.15.0 | **Yes.** State listwise deletion, point to lavaan/`mice`, no FIML promise. |
| 0.16.0 candidate | **Yes**, behind a spike against lavaan `missing = "fiml"`, with auxiliary variables (Graham saturated correlates) out of the first cut. |

## Risks

| Risk | Impact | Mitigation |
|---|---|---|
| OpenBLAS runner differs from macOS at ~1e-9 | Med | Pin fixtures at 1e-6; gates run on the runner |
| Retry seed change alters which start wins | Med | E-12 reliability gate on final tree; NEWS states it |
| Dependents break on `coef()` names / npar | High | Scratch-lib suites for six dependents; missingmed#102 merged first |
| Timing slips past floor | Low | Readiness-gated; no calendar commitment |

## Recommended Next Step
-> Review the SPEC, then run the plan's T1 (re-measure #320) while T2-T4 are drafted: it is the only unknown that can
change scope.
