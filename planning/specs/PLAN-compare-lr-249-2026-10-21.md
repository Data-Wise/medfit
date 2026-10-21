# Plan: compare_lr(), comparison engines for constrained LR fits (#249), 2026-10-21

Spec: `planning/specs/GRILL-249-comparison-engines-2026-10-21.md` (decisions 1-6, amended after the Codex adversarial review, #275). Tasks live in this file
(planning/ is Rbuildignored; `tasks/` would ship in the tarball). Release: own 0.12.0, GitHub-only.

## Overview

Add one exported function that runs the same product-null LR test in an external engine (lavaan, OpenMx) and reports it beside medfit's `mbco_sem()` result,
with classed warnings that fire only on observed evidence. No solver behavior changes (SLSQP stays the only constrained solver, as a permanent selectable
backup per decision 6; D18/D20 are #276).

## Design decisions made by this plan (to confirm at review)

- **Signature (draft):** `compare_lr(object, paths, engine = c("lavaan", "openmx"), tolerance = 1e-4)` (tolerance scale per P5); `object` a `SEMFit`, `paths` as in `mbco_sem()`.
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

## Grill of this plan (2026-10-21), decisions locked

| # | Branch | Decision |
|---|---|---|
| P1 | Export vs spike | **T0 gates the export.** Both failures reproduce: export `compare_lr()`. Only one: export for that engine. Neither: tests/sim harness and a docs section only, no new export |
| P2 | Same model | **Precheck before any LR comparison:** the engine's unrestricted fit must agree with medfit's on estimates and discrepancy (engine options set to mirror medfit: fixed.x, meanstructure, ML divisor); otherwise the verdict is `unresolved`, naming the differing parameters, and no engine is blamed |
| P3 | Supported class | **Narrow, refuse the rest:** covariance-only observed-variable regression models; no mean structure, weights, `fixed_x`, products, factors or bounds; each refusal names its reason |
| P4 | Starts | **Two runs per engine, reported as separate rows:** the engine's own default start and a zero start, so the known failure points are exercised (a medfit-default-only start could hide the OpenMx zero-Jacobian failure and give false agreement) |
| P5 | Tolerance | **|engine LR - medfit LR| <= tol * max(1, medfit LR), tol = 1e-4**, OpenMx converged tightly (optimality/feasibility 1e-12, function precision 1e-15), as the profile gate and `sem_openmx()` do |

Consequences for the tasks: T0 becomes a go/no-go gate; T1 adds the `unresolved` path for a failed precheck; T2/T3 add the precheck, the refusal list (P3) and the two-start runs (P4); T3's helper (`sem_openmx()` in `tests/testthat/helper-sem.R`) is covariance-only and takes internals `mod`/`smp`, which is why P3 is narrow; T4's result table has one row per engine and start; the draft tolerance in the signature becomes P5's form.

## Codex review gate (added 2026-10-21, author request)

After **each phase** a Codex adversarial review runs on that phase's PR before the next phase starts:
`/codex:adversarial-review --background <phase focus>` (review-only; Codex edits nothing). Every finding is triaged in
the PR as **fix** (done before the next phase), **reject** (with the evidence), or **defer** (an issue filed); the
outcome is recorded under the phase's checkpoint below. A phase is not closed with an untriaged finding. Focus text per phase:

| Gate | After | Focus |
|---|---|---|
| G1 | Phase 1 (T1) | evidence rules and false-accusation paths; is `unresolved` reachable and honest; tolerance scale |
| G2 | Phase 2 (T2, T3) | model equivalence between medfit and each engine; refusal list completeness; start handling (zero start) |
| G3 | Phase 3 (T4, T5) | API surface under the freeze; does the live gate protect against upstream drift; mislabel paths in `compare_lr()` |
| G4 | Phase 4 (T6, T7) | docs claims vs behavior; release readiness; anything the freeze or dependents contract misses |

## Dependency graph

```
T0 spike: do the failures reproduce on installed versions? ──► fixtures for T2/T5
T1 assess() pure function (injected results, all verdicts)  ──► T2 lavaan adapter ──► T4 compare_lr() assembly ──► T6 docs/freeze ──► T7 release
                                                              T3 OpenMx adapter ───┘            └──► T5 live harness gate
```

## Tasks (checkboxes are the task list; tick them in the PR that does the work)

### Phase 0: facts first

- [x] **T0. Spike and go/no-go (XS, read-only, no package code), DONE 2026-10-21: GO.** Results and scripts: `planning/specs/evidence/compare-lr-t0-2026-10-21/RESULTS.md`. Dependencies: none.
  - [x] Scratch script prints the OpenMx and lavaan versions installed and, for `a*b == 0` at n = 100 (the issue's cell), the OpenMx LR started at 0, the lavaan statistic with default and zero starts, and `mbco_sem()`; it states whether each failure reproduces.
  - [x] Output recorded; **decision (P1): both reproduce, export** (OpenMx at zero start 59/60 dropped; lavaan default start 20/300 above medfit).
  - [x] (original text) **decision to record (P1):** both reproduce = export; one = export for that engine; neither = harness and docs only, no export, and T4/T6 shrink to a docs section.
  - Files: none committed.

### Phase 1: detection core (pure, testable without engines)

- [x] **T1. `.lr_assess()`, the condition classes, the injected-result harness (S), implemented in PR #278 (gate G1 pending).** Dependencies: T0 (go).
  - [ ] Inputs: injected reference (accepted or `unresolved` branches) and engine result (unrestricted fit, LR per start, converged, constraint residual, Jacobian-at-start flag, version).
  - [ ] Order of verdicts: model precheck first (P2: unrestricted estimates and discrepancy agree, else `unresolved` naming the parameters), then evidence rules, then the tolerance `|dLR| <= 1e-4 * max(1, LR_medfit)` (P5).
  - [ ] Tests `test-compare-lr-assess.R`: OpenMx constraint-violating fit warns; **valid zero-LR null fit does not warn**; lavaan statistic above an accepted comparable restricted maximum warns; unresolved/rejected medfit branch gives `unresolved`, no warning; failed precheck gives `unresolved`, no warning; disagreement beyond tolerance flagged without fault; **planted defect** (assess keys on LR = 0) fails the valid-zero case.
  - [ ] Classes `medfit_warning_engine_constraint_dropped`, `medfit_warning_engine_statistic_above_max`, parent `medfit_warning_engine_comparison`.
  - Verify: `devtools::test(filter = "compare-lr-assess")`. Files: `R/compare-lr.R`, `tests/testthat/test-compare-lr-assess.R`, `tests/testthat/helper-compare-lr.R`.

### Phase 2: engine adapters

- [ ] **T2. lavaan adapter (M).** Dependencies: T1.
  - [ ] `.lr_engine_lavaan()` fits the unrestricted and product-null models from `object@model` plus the data with options mirroring medfit (fixed.x, meanstructure, ML divisor), two runs (default and zero start, P4), returns the T1 shape.
  - [ ] lavaan zero start: T0 found a start of 0 in the parameter table is ignored (also via `start =`); find a mechanism or document lavaan as default-start only.
  - [ ] Refusal list (P3) with a named reason each: mean structure, weights, `fixed_x`, products, factors, bounds, `start()`/`lower()`/`upper()`.
  - [ ] Tests (`skip_if_not_installed("lavaan")`): finite LR close to medfit on the `mbco_sem` docs model; each refusal errors with its message.
  - Files: `R/compare-lr.R`, `tests/testthat/test-compare-lr-lavaan.R`.

- [ ] **T3. OpenMx adapter (L, riskiest).** Dependencies: T1.
  - [ ] Translate the fit's table to the helper's `mod$a`/`mod$s` row frames for observed models (T0: `sem_openmx()` is not drop-in; it takes a test model, not a `SEMFit`), then promote the helper; keep a test-side wrapper so existing tests still pass.
  - [ ] Constraint as `mxConstraint`; two runs (default and zero start, P4); tight tolerances (optimality/feasibility 1e-12, function precision 1e-15, restored on exit); return the constraint residual and the Jacobian-at-start flag.
  - [ ] Same refusal list (P3).
  - [ ] Tests (`skip_if_not_installed("OpenMx")`): known answer against `mbco_sem()` when both converge; refusals.
  - Files: `R/compare-lr-openmx.R`, `tests/testthat/test-compare-lr-openmx.R`, `tests/testthat/helper-sem.R`. If it grows past L, ship lavaan alone and move OpenMx to a follow-up at Checkpoint A.

### Gate G1 (after T1, before Phase 2)

- [ ] Codex adversarial review run on the T1 PR (#278); findings triaged (fix / reject / defer) and recorded here

### Checkpoint A (after T1-T3)

- [ ] `devtools::test()` green, lint clean, `noSuggests` path passes (engines guarded)
- [ ] T0 findings (evidence/compare-lr-t0-2026-10-21/RESULTS.md) reviewed against the code as built
- [ ] **Gate G2:** Codex adversarial review run on the Phase 2 PR(s); findings triaged and recorded here
- [ ] Author review before building the public function

### Phase 3: the public function and its harness

- [ ] **T4. `compare_lr()` assembly and print method (M).** Dependencies: T2, T3 (or T2 alone).
  - [ ] Exported; roxygen with guarded `\donttest` examples; checkmate validation; clear error when the engine package is absent; reference from `mbco_sem(object, paths = paths)`; result `medfit_lr_comparison` (reference, one row per engine and start, verdict, warnings) with `print()`/`format()`.
  - [ ] Guard test: `a*b == 0` is never posed as a constraint in medfit's own path (the reference null fits hand the solver no product-zero nonlinear row).
  - Verify: `devtools::document()`, `devtools::test(filter = "compare-lr")`, examples run. Files: `R/compare-lr.R`, `NAMESPACE`, `man/compare_lr.Rd`, `tests/testthat/test-compare-lr.R`.

- [ ] **T5. Live harness gate (M).** Dependencies: T4.
  - [ ] `tests/sim/compare-lr-gate.R`: the issue's cell (a*b == 0, n = 100, default and zero starts, several seeds) through `compare_lr()`; records engine versions and whether each known failure reproduced; exit 0 whether or not upstream is fixed; exit 1 only if `compare_lr()` mislabels (a warning on a valid fit, silence on an observed violation).
  - [ ] `MUTANT=noresidual` (detector keys on LR = 0) exits 1.
  - [ ] Registered in three places: `tests/sim/gates.csv`, a rule in `tests/sim/run-gates.R`, and the gate id in the C2 set of `planning/specs/CRITERIA-native-experimental-exit-2026-10-17.csv` (so `test-experimental-criteria.R` stays green; this broke `dev` once, #266).
  - Verify: macOS run; `tests/sim/linux/run.sh tests/sim/compare-lr-gate.R` on the reference BLAS; the gates driver self-test.
  - Files: `tests/sim/compare-lr-gate.R`, `tests/sim/gates.csv`, `tests/sim/run-gates.R`, the criteria CSV.

### Checkpoint B (after T4-T5)

- [ ] Full suite green; macOS and Linux-container gates green; the planted defect is caught
- [ ] End-to-end transcript of `compare_lr()` on a real model quoted in the PR body (e2e-before-pr rule)
- [ ] **Gate G3:** Codex adversarial review run on the Phase 3 PR(s); findings triaged and recorded here

### Phase 4: documentation, freeze, release

- [ ] **T6. Docs and contracts (S).** Dependencies: T4.
  - [ ] Refcard row and `_pkgdown.yml` reference entry (`test-refcard-coverage.R`); section in `lavaan-comparison.qmd` describing the evidence-based warnings, the narrow supported class and the two-start rows; `test-api-freeze.R` pins `compare_lr()` argument order; NEWS entry; US English.
  - Verify: `devtools::test(filter = "refcard|api-freeze|guide|model-pages|dependents")`.
  - Files: `vignettes/articles/refcard.qmd`, `lavaan-comparison.qmd`, `_pkgdown.yml`, `NEWS.md`, `tests/testthat/test-api-freeze.R`.

- [ ] **T7. Release 0.12.0 (S, author-gated).** Dependencies: T6, author approval.
  - [ ] Version, Date, NEWS header, README row, CLAUDE.md status, `.STATUS`; rforge cran-prep (incoming, strict) `ready`; `gh workflow run gates --ref dev` green; release PR `dev` to `main` (merge commit); tag only after `main` CI is green.

### Checkpoint C: complete

- [ ] **Gate G4:** Codex adversarial review run on the Phase 4 PR(s) and the release PR; findings triaged and recorded here
- [ ] All acceptance criteria met; #249 closed with a comment; #275 ledger merged; this list ticked

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| OpenMx RAM translation is larger than estimated (T0: the helper is not drop-in) | High | T3 is isolated; reuse `sem_openmx()`; split into "covariance models only" first; Checkpoint A can drop OpenMx to a follow-up and ship lavaan alone |
| A phase closes with an untriaged review finding | Med | the Codex review gates G1-G4: no phase closes with an untriaged finding |
| Known failures no longer reproduce on current versions | Med | T0 tells us first; the live gate reports instead of asserting; unit tests use injected results |
| New false-accusation path in the warnings | High | evidence-only rules; valid zero-LR and unresolved cases are tests; planted-defect mutant in the gate |
| medfit reference itself `unresolved` | Med | verdict `unresolved`, no fault assigned (decision 2) |
| Suggests packages absent in CI `noSuggests` | Med | adapters guarded; assess tests need no engine |
| New gate not registered in the criteria set | Low | explicit step in T5 (this broke dev once, #266) |
| Syntax medfit accepts that engines cannot | Low | explicit errors naming the construct, no silent translation |

## Open questions for review

1. Confirm the signature and the return as a classed list (not S7).
2. Ship lavaan and OpenMx together, or lavaan first and OpenMx as a follow-up if T3 grows? (Decide at Checkpoint A with T0 facts in hand.)
3. ~~Tolerance~~ resolved by P5.
4. Whether the live gate should block the release or stay informational (draft: informational for upstream behavior, blocking for `compare_lr()` mislabeling).
