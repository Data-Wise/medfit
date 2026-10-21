# Plan: compare_lr(), comparison engines for constrained LR fits (#249), 2026-10-21

Spec: `planning/specs/GRILL-249-comparison-engines-2026-10-21.md` (decisions 1-6, amended after the Codex adversarial review, #275). Tasks live in this file
(planning/ is Rbuildignored; `tasks/` would ship in the tarball). Release: own 0.12.0, GitHub-only.

## Overview

Add one exported function that runs the same product-null LR test in an external engine (lavaan, OpenMx) and reports it beside medfit's `mbco_sem()` result,
with classed warnings that fire only on observed evidence. No solver behavior changes (SLSQP stays the only constrained solver, as a permanent selectable
backup per decision 6; D18/D20 are #276).

## Design decisions made by this plan (to confirm at review)

- **Signature (draft):** `compare_lr(object, paths, engine = c("lavaan", "openmx"), tolerance = 1e-4)`; `object` a `SEMFit`, `paths` as in `mbco_sem()`.
  The reference is `mbco_sem(object, paths = paths)`; the external engine fits the full model and the product-null (`a*b == 0`, started at its own default
  starts) on the same data and syntax.
- **Correction to the grill:** Q1's argument "a new argument on an existing function breaks the API freeze" was too strong: `test-api-freeze.R` allows
  trailing arguments. The new function is still the right home (it needs deps guards, warnings and its own return value), but it is a choice, not a forced one.
- **Return value:** a plain classed list `medfit_lr_comparison` with `print()`/`format()` methods, not an S7 class (an S7 class adds a refcard class row, a
  dependents-contract entry and a freeze pin for little gain). Fields: `reference` (medfit LR, status `accepted`/`unresolved`), `engines` (one row per engine:
  version, LR, converged, constraint residual, evidence), `verdict` (`agree`, `disagree`, `unresolved`), `warnings` (classed conditions raised).
- **Engine syntax:** medfit syntax that lavaan/OpenMx cannot express (`start()`, `lower()`, `upper()`, `:` products, `fixed_x`) errors with a message naming the
  construct; no silent translation. lavaan takes the model text (plus `a*b == 0`); OpenMx needs a RAM translation (see T3, the riskiest task).
- **Evidence rules (decision 2):** OpenMx warns only if the returned parameters violate the product constraint (residual above tolerance) or the constraint
  Jacobian is zero at its start; lavaan only if its statistic exceeds the restricted maximum by a margin versus an accepted comparable fit. LR = 0 alone never
  warns. medfit is the reference only when every branch fit is accepted with a comparable likelihood; else the verdict is `unresolved` and no fault is assigned.
- **Condition classes:** `medfit_warning_engine_constraint_dropped` (OpenMx evidence) and `medfit_warning_engine_statistic_above_max` (lavaan evidence), both
  inheriting `medfit_warning_engine_comparison`.

## Dependency graph

```
T0 spike: do the failures reproduce on installed versions? ──► fixtures for T2/T5
T1 assess() pure function (injected results, all verdicts)  ──► T2 lavaan adapter ──► T4 compare_lr() assembly ──► T6 docs/freeze ──► T7 release
                                                              T3 OpenMx adapter ───┘            └──► T5 live harness gate
```

## Tasks

### Phase 0: facts first

**T0. Spike: reproduce both known failures (XS, read-only, no package code).**
- Acceptance: a scratch script prints OpenMx and lavaan versions installed and, for `a*b == 0` at n = 100 (the issue's cell), the OpenMx LR started at 0 and the lavaan statistic with default and zero starts versus `mbco_sem()`; it states whether each failure reproduces.
- Verification: output pasted into the PR body; if neither reproduces, the live harness (T5) reports instead of asserting, as designed.
- Files: none committed (scratch in the scratchpad). Dependencies: none.
- Why first: it decides whether T5 has a live positive control and which fixtures T1 mirrors.

### Phase 1: detection core (pure, testable without engines)

**T1. `.lr_assess()` and the condition classes (S).**
- Acceptance: given an injected reference (accepted or unresolved branches) and an injected engine result (LR, converged, residual, jac_zero_at_start, version), it returns `agree`/`disagree`/`unresolved` and raises the classed warnings only on the evidence rules above.
- Tests (`test-compare-lr-assess.R`): OpenMx constraint-violating fit warns; **valid zero-LR null fit does not warn**; lavaan statistic above the restricted maximum warns; unresolved/rejected medfit branch gives `unresolved` with no warning; disagreement beyond tolerance flagged without fault; planted defect (assess ignores the residual and keys on LR = 0) fails the valid-zero case.
- Verification: `devtools::test(filter = "compare-lr-assess")`.
- Files: `R/compare-lr.R`, `tests/testthat/test-compare-lr-assess.R`, `tests/testthat/helper-compare-lr.R` (injected-result builders = the test harness). Dependencies: T0.

### Phase 2: engine adapters

**T2. lavaan adapter (M).**
- Acceptance: `.lr_engine_lavaan(object, paths, data)` fits full and product-null models from `object@model` plus the data, returns the T1 result shape (statistic, converged, residual of `a*b`, version); unsupported syntax errors naming the construct.
- Tests: guarded by `skip_if_not_installed("lavaan")`; the model of `mbco_sem` docs on `mediation_demo` returns finite LR close to medfit's; unsupported-syntax cases error with the expected message.
- Files: `R/compare-lr.R`, `tests/testthat/test-compare-lr-lavaan.R`. Dependencies: T1.

**T3. OpenMx adapter (L, riskiest, split if it grows).**
- Acceptance: RAM table translation from `object@internals`/`@table` to `mxModel` (covariance-structure, `numObs`, `a*b == 0` as `mxConstraint`); returns the T1 shape including the constraint residual and, if available, the Jacobian-at-start flag; unsupported syntax errors.
- Reuse: the existing `sem_openmx()` helper used by `tests/sim/sem-constrained-gate.R` and `sem-nonlinear-gate.R`; promote it, do not rewrite.
- Tests: `skip_if_not_installed("OpenMx")`; known-answer on the mediation model against `mbco_sem()` when both converge.
- Files: `R/compare-lr.R` (or `R/compare-lr-openmx.R`), `tests/testthat/test-compare-lr-openmx.R`. Dependencies: T1.

### Checkpoint A (after T1-T3)

- [ ] `devtools::test()` green, lint clean, `noSuggests` path still passes (engines guarded)
- [ ] T0 findings reviewed: do the failures reproduce? decide how T5 asserts
- [ ] Review with the author before building the public function

### Phase 3: the public function and its harness

**T4. `compare_lr()` assembly and print method (M).**
- Acceptance: exported, roxygen with `@examples` (`\donttest`, guarded), validates inputs with checkmate, errors clearly when the engine package is absent, calls `mbco_sem()` for the reference, returns the `medfit_lr_comparison` list; `print()` shows reference, per-engine rows, verdict and any warnings.
- Guard test (decision 6/3): `a*b == 0` is never posed as a constraint in medfit's own path: assert the reference path hands the solver no product-zero nonlinear row (inspect `.sem_constraint_rows()`/`cons` for the null fits).
- Verification: `devtools::document()`, `devtools::test(filter = "compare-lr")`, `R CMD check` examples.
- Files: `R/compare-lr.R`, `NAMESPACE`, `man/compare_lr.Rd`, `tests/testthat/test-compare-lr.R`. Dependencies: T2, T3.

**T5. Live harness gate (M).**
- Acceptance: `tests/sim/compare-lr-gate.R` runs the issue's cell (a*b == 0, n = 100, default and zero starts, several seeds) through `compare_lr()`, records engine versions and, per engine, whether the known failure reproduced; exit 0 whether or not upstream is fixed; exit 1 only when `compare_lr()` mislabels (a warning on a valid fit, or silence on an observed violation). `MUTANT=` switch: `noresidual` (detector keys on LR = 0) must exit 1.
- Registration (do not skip, see #266): row in `tests/sim/gates.csv`, a rule in `tests/sim/run-gates.R`, and the gate id added to the C2 set in `planning/specs/CRITERIA-native-experimental-exit-2026-10-17.csv` so `test-experimental-criteria.R` stays green.
- Verification: macOS run; `tests/sim/linux/run.sh tests/sim/compare-lr-gate.R` on the reference BLAS; the gates driver rule self-test (`MUTANT`) passes.
- Files: `tests/sim/compare-lr-gate.R`, `tests/sim/gates.csv`, `tests/sim/run-gates.R`, the criteria CSV. Dependencies: T4.

### Checkpoint B (after T4-T5)

- [ ] Full suite green; both gates (macOS and the Linux container) green; the planted defect is caught
- [ ] An end-to-end transcript of `compare_lr()` on a real model (quoted in the PR body per the e2e-before-pr rule)

### Phase 4: documentation, freeze, release

**T6. Docs and contracts (S).**
- Acceptance: refcard row and `_pkgdown.yml` reference entry (satisfy `test-refcard-coverage.R`); a section in `lavaan-comparison.qmd` with the two evidence-based warnings; `test-api-freeze.R` pins `compare_lr()` argument order; `test-dependents-contract.R` untouched (no class change); NEWS entry; US English.
- Verification: `devtools::test(filter = "refcard|api-freeze|guide|model-pages|dependents")`.
- Files: `vignettes/articles/refcard.qmd`, `lavaan-comparison.qmd`, `_pkgdown.yml`, `NEWS.md`, `tests/testthat/test-api-freeze.R`. Dependencies: T4.

**T7. Release 0.12.0 (S, author-gated).**
- Acceptance: version, Date, NEWS header, README row, CLAUDE.md status, `.STATUS`; rforge cran-prep (incoming, strict) `ready`; dev gates green; release PR `dev` to `main` merge commit; tag only after `main` CI is green. Run `gh workflow run gates --ref dev` before the release PR.
- Dependencies: T6, author approval at the release step.

### Checkpoint C: complete

- [ ] All acceptance criteria met; #249 closed with a comment; #275 ledger merged; the plan task list ticked

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OpenMx RAM translation is larger than estimated | High | T3 is isolated; reuse `sem_openmx()`; split into "covariance models only" first; Checkpoint A can drop OpenMx to a follow-up and ship lavaan alone |
| Known failures no longer reproduce on current versions | Med | T0 tells us first; the live gate reports instead of asserting; unit tests use injected results |
| New false-accusation path in the warnings | High | evidence-only rules; valid zero-LR and unresolved cases are tests; planted-defect mutant in the gate |
| medfit reference itself `unresolved` | Med | verdict `unresolved`, no fault assigned (decision 2) |
| Suggests packages absent in CI `noSuggests` | Med | adapters guarded; assess tests need no engine |
| New gate not registered in the criteria set | Low | explicit step in T5 (this broke dev once, #266) |
| Syntax medfit accepts that engines cannot | Low | explicit errors naming the construct, no silent translation |

## Open questions for review

1. Confirm the signature and the return as a classed list (not S7).
2. Ship lavaan and OpenMx together, or lavaan first and OpenMx as a follow-up if T3 grows? (Recommendation: decide at Checkpoint A with T0 facts in hand.)
3. Tolerance default for "disagreement" (draft: 1e-4 relative).
4. Whether the live gate should block the release or stay informational (draft: informational for upstream behavior, blocking for `compare_lr()` mislabeling).
