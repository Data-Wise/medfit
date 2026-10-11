# Implementation Plan: medfit 0.8.0 (native SEM hardening, nonlinear constraints, lavaan comparison)

**Date:** 2026-10-11 | **Branch of record:** `dev` | **Release channel:** GitHub only (G4)
**Sources:** [BRAINSTORM](../planning/specs/BRAINSTORM-medfit-0-8-0-2026-10-11.md), [GRILL ledger G1-G13](../planning/specs/GRILL-medfit-0-8-0-2026-10-11.md) (authoritative where they differ), [FEASIBILITY](../planning/specs/FEASIBILITY-medfit-0-8-0-additions-2026-10-11.md), [RMediation handoff](../planning/specs/HANDOFF-rmediation-mbco-on-mbco_sem-2026-10-11.md).
**Task list:** `tasks/todo.md` (checklist; task numbers match this file).
**Status:** APPROVED 2026-10-11 by the author (after the two Codex findings and two self-review fixes: harness pass rules now point to `tests/sim/gates.csv`; T3 resized S to M). No code changed by this plan.

## Overview

0.8.0 hardens the experimental native ML SEM engine and adds constrained nonlinear optimization (via the nloptr already in `Imports`), an `anova()` likelihood-ratio test for nested `SEMFit`s, `SEMFit` methods that match `MediationData`, and an executed lavaan-vs-medfit article. It ships on top of the unreleased dev fixes (#128, #138, docs overhaul #129-#139). No separate SEM package (survey and G-ledger agree); consolidation in dependents is medfit-side API plus one RMediation route in a separate session.

## Architecture decisions (from the ledger)

- **G1** The W1 bound-verdict unification is exempt from deprecation (experimental badge, no dependent uses the native engine); NEWS behavior-change note.
- **G2/G12/G13** Nonlinear rows become closures with a central-difference Jacobian. `a*b == 0` and `b1*b2*b3 == 0` are solved exactly as k linear branches. Other nonlinear rows use best-of-n multi-start with a spread warning; sums of products are best-effort. Min-of-k MBCO ships only if the type I error gate passes.
- **G4** nloptr stays `Imports`; `rhub.yaml` runs once, in parallel with the foundations.
- **G5** The S1 scripts are gone; the two S1 findings are re-derived as committed fixtures in `planning/specs/evidence/native-sem-2026-10-11/`.
- **G9/G10** `anova()` for `SEMFit` pairs (with a boundary-null guard) is the building block; RMediation owns the `mbco` generic and registers a `(SEMFit, SEMFit)` method later. medfit exports no `mbco`.
- **G11** glm joint-significance is a documented recipe only (likelihood families); the function waits for 0.9.0.

## Dependency graph

```
T1 evidence+fixtures ─┬─> T7 NNLS gate ──┬─> T8 bound verdict (F4) ──> T9 S1 close ──┐
T2 rhub (parallel)     │                  │                                           │
T3 harness driver ─────┘ (gates plug in as they land)                                  v
T4 parse errors   T5 bound error   T6 redundant inequalities  (independent, W2)   [Checkpoint A]
                                                                                       │
T10 anova() + boundary guard ──> T11 SEMFit methods ──> T12 naming/args           [Checkpoint B] ──> unblock RMediation handoff (needs T10, T13-T16)
                                                                                       │
                        T13 nonlinear equality (a*b == c) end to end ──> T14 k-branch zero products
                                          │                                  │
                                          └──> T15 inequalities, := names, multi-start ──> T16 sums of products
                        T17 mbco_sem(paths) k-path ──> T18 k-size gate (G13)       T19 nonlinear gate (G6)   [Checkpoint C]
T20 lavaan article ── needs T11, T13 ;  T21 docs corrections ── needs T13-T16 ;  T22 glm recipe (independent)   [Checkpoint D]
T23 release grill ──> T24 release PR (owned by release engineering)
```

Foundations first (T1, T4-T9), the unblocker for RMediation next (T10), the L-sized nonlinear work after the foundations (it depends on W1), docs last.

## Verification harness (what "done" is measured with)

Existing gates are reused; new ones are added. Convention (already in the repo): sim scripts live in `tests/sim/` (Rbuildignored), run from the package root with `Rscript`, write `tests/sim/results/<gate>-<date>.csv` and `.out`; unit tests in `tests/testthat/` use a planted defect that must turn the test red.

| Gate | Command | Status | Pass rule | Planted defect that must fail it | When |
|---|---|---|---|---|---|
| H-unit | `Rscript -e 'devtools::test(filter = "sem-")'` per task; full: `devtools::test()` | exists | all pass; report counts | per-task, see tasks | every PR |
| H-lint | `Rscript -e 'devtools::load_all(); lintr::lint_package()'` (same process) | exists | 0 lints | n/a | every PR |
| H-parity | `Rscript tests/sim/sem-parity-gate.R` | exists (420 runs) | SE within 1e-3 rel., estimates within 1e-6 in at least 418/420 (D22 baseline) | n/a (regression) | after T7, T8, T13-T16 |
| H-constrained | `Rscript tests/sim/sem-constrained-gate.R` | exists | thresholds and expected cell count from `tests/sim/gates.csv` (seeded from the last committed results; see the verdict rule below) | n/a (regression) | after T7, T8 |
| H-reliab | `Rscript tests/sim/sem-reliability.R` | exists | aggregate threshold defined in T3 and recorded in `tests/sim/gates.csv` (none exists today); worker errors count as failures | n/a (regression) | after T15 (multi-start) |
| H-nonlinear | `Rscript tests/sim/sem-nonlinear-gate.R` | **new (T19)** | G6: never a worse objective than OpenMx's optimum minus 1e-8; estimates within 1e-5 when both reach the same branch; KKT gate passes; 0 improper; `a*b > k` best branch in at least 90% of cells with 5 starts; the sum-of-products hit rate is reported, not gated (G12); **standard errors** (Codex finding 2): the projected covariance is annihilated by the solution Jacobian (`|J V|` relative to `|V|` at most 1e-8) and the SEs match an independent oracle within 1e-3 relative (a reparameterized fit with the constraint solved out and delta-method SEs, plus a fixed-seed nonparametric bootstrap cross-check) | nonlinear row misclassified as linear; larger-branch pick; no Jacobian row dropping; covariance projection frozen at the starting Jacobian or omitted | after T13-T16 |
| H-ksize | `Rscript tests/sim/sem-mbco-k-size.R` | **new (T18)** | size at or below alpha plus Monte Carlo error with one, two and three zero paths; power floor under a stated alternative | refer min to chi-square(2) (fails the oracle and power floor, not size) | after T17 |
| H-oracle | testthat in `test-sem-mbco.R` / `test-sem-anova.R` | **new (T10, T17)** | statistic 4, alpha 0.05: p = 0.0455 (df 1, reject), 0.1353 (df 2, do not reject) | df = 2 mutation | with T10, T17 |
| H-boundary | testthat | **new (T10)** | `anova()` on a boundary null warns or refuses, same as `mbco_sem()` (`R/sem-mbco.R:140-165`) | delete the boundary check | with T10 |
| H-docs | `Rscript -e 'devtools::test(filter = "refcard\|cookbook\|model-pages\|guide")'` and article build | exists | pass; article table matches live probes (T20) | edit a table row | docs tasks |
| H-check | strict-flavor `devtools::check(cran = TRUE, args = "--run-donttest", env_vars = c(...))` (see CLAUDE.md) | exists | 0 errors, 0 warnings, notes only if pre-existing | n/a | each checkpoint, pre-release |
| H-revdep | install dev into a scratch library; run probmed and RMediation test suites | exists (manual) | no new failures vs CRAN medfit baseline | n/a | Checkpoint C, pre-release |

`T3` adds a driver, `tests/sim/run-gates.R`, with `--fast` (unit + lint + oracles), `--sim` (all `tests/sim` gates) and `--mutants` (apply each planted defect through a test-time override and assert the owning gate fails), writing a one-page summary to `tests/sim/results/`. The driver is a convenience; each gate stays runnable alone.

**Verdicts come from results, never from exit status** (Codex review of the plan, finding 1, 2026-10-11). The existing `sem-parity-gate.R` and `sem-constrained-gate.R` print PASS/FAIL lines and write their CSV without any `quit()` or `stop()`, and `sem-reliability.R` drops worker errors from its summary and states no aggregate threshold, so a script can exit 0 with failed numerical checks. The driver therefore reads each gate's results CSV and applies committed thresholds and expected cell counts (recorded in `tests/sim/gates.csv`, one row per gate: expected cells, tolerance, pass rule). It rejects: a tolerance failure, a missing or short cell count, a failed or errored run, and an unreadable or stale results file, whatever the exit status. The new gates (T18, T19) also end with `quit(status = 1)` on failure so they are safe to run alone.

## Task list

### Phase 0: Evidence and harness foundations

#### Task 1: Re-derive the S1 findings as committed fixtures (G5)
**Description:** Create `planning/specs/evidence/native-sem-2026-10-11/` (README, script, results) that re-runs the surviving `04b` stationarity table and turns the two S1 findings (stationarity depended on data units, Q14; NNLS divides 0/0 on dependent columns, S25) into reproducible fixtures. Nothing is "recovered": the scripts are gone.
**Acceptance criteria:**
- [ ] Folder with README listing each fixture, its oracle and how to run it
- [ ] Stationarity table reproduced with the 0.7.0 gate on the same cells as `04b`
- [ ] A dependent-column fixture that reproduces the 0/0 NNLS case on the old `04b` code path
**Verification:**
- [ ] `Rscript planning/specs/evidence/native-sem-2026-10-11/<script>.R` exits 0 and writes results
- [ ] Re-running gives identical numbers (seeded)
**Dependencies:** None | **Files:** `planning/specs/evidence/native-sem-2026-10-11/*` | **Scope:** M

#### Task 2: Trigger the rhub workflow once (G4)
**Description:** Run `rhub.yaml` on `dev` as the CRAN-flavor evidence for nloptr; record the outcome in `.STATUS`.
**Acceptance criteria:**
- [ ] Workflow dispatched; every job's conclusion recorded (including any failure with the flavor name)
**Verification:**
- [ ] `gh run list --workflow rhub.yaml --limit 1` shows the run; result noted in `.STATUS`
**Dependencies:** None (runs in parallel with Phase 1) | **Files:** `.STATUS` | **Scope:** XS

#### Task 3: Harness driver
**Description:** Add `tests/sim/run-gates.R` with `--fast`, `--sim`, `--mutants` modes and a results summary, wrapping the existing gates and the new ones as they land.
**Acceptance criteria:**
- [ ] `--fast` runs unit tests, lint and the oracles and prints pass/fail counts
- [ ] Verdicts are computed from each gate's results CSV against thresholds and expected cell counts in `tests/sim/gates.csv`, not from the script's exit status
- [ ] Fixtures where a script exits 0 but its CSV has (a) a tolerance failure, (b) missing cells, (c) a worker error or failed run, (d) a stale or unreadable file: the driver rejects each
- [ ] An aggregate pass threshold is defined for `sem-reliability.R` (it has none today) and recorded in `gates.csv`
- [ ] `--mutants` reports, per planted defect, that its gate failed (a mutant that passes is an error)
- [ ] Summary written to `tests/sim/results/`
**Verification:**
- [ ] `Rscript tests/sim/run-gates.R --fast` on a clean tree passes
- [ ] Each of the four "exits 0 but bad" fixtures makes the driver exit nonzero
**Dependencies:** None | **Files:** `tests/sim/run-gates.R`, `tests/sim/gates.csv`, `tests/sim/fixtures/` (the four "exits 0 but bad" fixtures), `tests/sim/results/` | **Scope:** M

### Phase 1: Foundations (W1, W2)

#### Task 4: Named errors for `Y ~ Y` and duplicate `Y ~ X` rows
**Description:** The parser or model builder rejects a self-regression and a duplicated path with a named, early error (today `Y ~ Y` fails late with "df = -1" and a duplicate fails in the RAM builder).
**Acceptance criteria:**
- [ ] `Y ~ Y` errors at parse time naming the row
- [ ] A duplicate `Y ~ X` row errors by name (or collapses, per the grammar spec; decide and pin it)
**Verification:**
- [ ] `devtools::test(filter = "sem-parse|sem-model")` passes with new tests that fail on the old code
**Dependencies:** None | **Files:** `R/sem-parse.R` or `R/sem-model.R`, `tests/testthat/test-sem-parse.R`, `test-sem-model.R` | **Scope:** S

#### Task 5: Infeasible bounds give a named error (F2)
**Description:** `a > 1; a < 0.5` currently leaks the internal `lb <= ub` assertion; raise a named infeasibility error instead.
**Acceptance criteria:**
- [ ] The message names the parameter and the conflicting bounds
**Verification:**
- [ ] New test in `test-sem-optim.R` fails before and passes after
**Dependencies:** None | **Files:** `R/sem-optim.R`, `tests/testthat/test-sem-optim.R` | **Scope:** XS

#### Task 6: Consistent but redundant inequality sets are accepted (F1)
**Description:** Dependent inequality rows (`a == b; a - b < 0`, `a+b == 0.8; a+b > 0.8`) currently fail ("status 5" or a stationarity failure) because only equality rows are reduced. Accept consistent sets and reach the optimum of the equivalent independent set (the #122 pattern).
**Acceptance criteria:**
- [ ] Both example sets fit and equal the independent-set optimum to 1e-6
- [ ] A genuinely inconsistent set still errors by name
**Verification:**
- [ ] `devtools::test(filter = "sem-constraints")`; H-constrained regression run
**Dependencies:** None | **Files:** `R/sem-constraints.R`, `tests/testthat/test-sem-constraints.R` | **Scope:** M

#### Task 7: Port the NNLS multiplier-sign gate
**Description:** Replace the warn-only least-squares sign check with an NNLS gate that has column scaling, a relative tolerance and a step guard (the evidence script's version divided 0/0 on dependent columns), using the T1 fixtures.
**Acceptance criteria:**
- [ ] The dependent-column fixture from T1 passes on `R/` code (no 0/0)
- [ ] Converged and stalled fits separate as in D19/D21 (3.2e-7 vs 0.0905)
**Verification:**
- [ ] `devtools::test(filter = "sem-constraints|sem-optim")`; planted defect: remove column scaling, the fixture must fail
- [ ] H-constrained and H-parity regression runs
**Dependencies:** T1 | **Files:** `R/sem-constraints.R`, `tests/testthat/test-sem-constraints.R`, `helper-sem.R` | **Scope:** M

#### Task 8: Unify the bound verdict (F4) with NEWS note (G1)
**Description:** The plain gate rejects a wrong-side active bound while the projected gate only warns (`R/sem-optim.R:146-155` vs `R/sem-constraints.R:309`). Make one verdict. Re-grep dependents for `fit_sem|SEMFit|mbco_sem|engine = "native"` before merging.
**Acceptance criteria:**
- [ ] The same fit with and without an inactive constraint line gets the same verdict
- [ ] NEWS `[Unreleased]` entry (behavior change, exemption reasoning)
**Verification:**
- [ ] New parity test in `test-sem-optim.R`/`test-sem-constraints.R`; H-parity and H-constrained regressions
**Dependencies:** T7 | **Files:** `R/sem-optim.R`, `R/sem-constraints.R`, `NEWS.md`, tests | **Scope:** M

#### Task 9: Close S1 with a fresh-context review
**Description:** An independent agent reviews the T7/T8 diff against the S1 findings and the ledger; its verdict goes in the ledger.
**Acceptance criteria:**
- [ ] Review recorded as a ledger entry with findings fixed or dismissed
**Verification:**
- [ ] No open S1 item in `.STATUS`
**Dependencies:** T7, T8 | **Files:** `planning/specs/GRILL-medfit-0-8-0-2026-10-11.md`, `.STATUS` | **Scope:** S

### Checkpoint A: after Tasks 1-9
- [ ] H-unit full suite, H-lint, H-parity, H-constrained, H-check pass (counts reported)
- [ ] rhub result (T2) recorded; any failing flavor decided with evidence
- [ ] Review with the human before Phase 2

### Phase 2: `anova()` and SEMFit methods (W4; unblocks RMediation)

#### Task 10: `anova()` for nested `SEMFit`s with a boundary-null guard (G9)
**Description:** `anova(fit0, fit1)` returns diffLL `n_obs * (f0 - f1)`, df from free-parameter counts, p-value, one row per model. Refuse different data or `n_obs`, non-nested pairs, `sampling_weights` fits and non-converged fits. Detect boundary nulls (an active bound or inequality on a tested parameter) and warn or refuse as `mbco_sem()` does.
**Acceptance criteria:**
- [ ] On the `memory_exp` models it reproduces `mbco_sem()` per-refit diffLL (221.045546, 0.083100) to 1e-6
- [ ] The H-oracle and H-boundary tests exist and their mutants fail
- [ ] Nesting check method chosen (parameter-table inclusion or user assertion) and documented
- [ ] Refit trap (RMediation session finding): any refit `anova()` or its helpers perform starts from a clean start, not from the full fit's estimates; fixture: the `b1 == 0` null on `memory_exp` gives diffLL 0.083100 (within 1e-6) from a clean start and never the infeasible-point value 0; planted defect: seed the refit from the full fit's estimates, the fixture must fail
**Verification:**
- [ ] `devtools::test(filter = "sem-anova|sem-mbco")`
**Dependencies:** None (T8 helps for boundary logic) | **Files:** `R/methods-sem.R`, `R/aab-generics.R` if a generic is needed, `tests/testthat/test-sem-anova.R`, `NAMESPACE`/docs | **Scope:** M

#### Task 11: `tidy()`, `glance()`, `confint()` for `SEMFit`; chi-square and df
**Description:** Registered methods behave like `MediationData`'s; report chi-square and df; decide what `@converged` means before `glance()` reports it (always `TRUE` today).
**Acceptance criteria:**
- [ ] `tidy`/`glance`/`confint` work on a `SEMFit` and match lavaan on a shared model (to 1e-4)
- [ ] `glance()` does not carry an always-`TRUE` column unless it is documented as such
**Verification:**
- [ ] `devtools::test(filter = "sem-methods|methods-tidy")`; refcard coverage test updated
**Dependencies:** None | **Files:** `R/methods-tidy.R`, `R/methods-sem.R`, `tests/testthat/test-sem-methods.R`, `test-refcard-coverage.R` | **Scope:** M

#### Task 12: One coefficient-naming convention and aligned arguments
**Description:** Unify `coef()` naming ("mediator1 ~~ mediator1" vs the accessors' "mediator1~~mediator1"); align `sampling_weights`/`weights` and `mbco_sem(fit)`/`object`. Renamed arguments use `lifecycle::deprecate_warn()` (ledger: deprecation policy).
**Acceptance criteria:**
- [ ] One spelling across `coef()`, the accessors and `tidy()`
- [ ] Old argument names still work with a deprecation warning, with tests
**Verification:**
- [ ] `devtools::test()` full; `_pkgdown.yml` and refcard tests pass
**Dependencies:** T11 | **Files:** `R/extract-sem.R`, `R/fit-sem.R`, `R/sem-mbco.R`, `R/methods-sem.R`, tests | **Scope:** M

### Checkpoint B: after Tasks 10-12
- [ ] H-unit, H-lint, H-check pass; `anova()` known answers and oracles green
- [ ] Hand the `anova()` status to the RMediation session (handoff needs T10 **and** T13-T16 before its method work starts)
- [ ] Review with the human

### Phase 3: Nonlinear constraints (W3)

#### Task 13: Nonlinear equality rows end to end (`a*b == c`)
**Description:** One complete path: parse a nonlinear equality, build a closure with the guarded evaluator, central-difference Jacobian (step eps^(1/3) * max(|x|, 1), columns scaled by u), solve with SLSQP, residual feasibility gate, SE projection from the Jacobian at the solution.
**Acceptance criteria:**
- [ ] `a*b == c` fits and matches OpenMx's constrained optimum on a fixed seed to 1e-5
- [ ] Curved-constraint covariance oracle: the projected covariance is annihilated by the Jacobian at the **solution** (`|J V|` relative to `|V|` at most 1e-8), and SEs agree with an independent oracle (reparameterized fit with delta-method SEs; fixed-seed bootstrap cross-check) within 1e-3 relative
- [ ] Planted defect: freeze the projection at the starting Jacobian, or omit it; the oracle test must fail
- [ ] The old "nonlinear constraints are not supported" error is gone only for supported forms; others still error by name
**Verification:**
- [ ] `devtools::test(filter = "sem-constraints|sem-expr|sem-se")`; planted defect: classify the row as linear, test must fail
**Dependencies:** T9 | **Files:** `R/sem-constraints.R`, `R/sem-expr.R`, `R/sem-optim.R`, `R/sem-se.R`, tests | **Scope:** M

#### Task 14: Exact k-branch split for zero products
**Description:** `a*b == 0` and `b1*b2*b3 == 0` are solved as k linear refits, keeping the smallest discrepancy (no nonlinear solve).
**Acceptance criteria:**
- [ ] `a*b == 0` on `memory_exp` equals 0.083100 (not 221.045546)
- [ ] A three-factor product fixture, including one with two factors near zero (vanishing Jacobian), returns the minimum branch
- [ ] Refit trap: each branch refit starts clean; the `b1 == 0` branch on `memory_exp` returns 0.083100 (within 1e-6), not an infeasible-point result, and the same branch built from the full fit's estimates must not be what the code does (planted defect: warm-start the branch from the full fit, the fixture must fail)
**Verification:**
- [ ] `devtools::test(filter = "sem-constraints|sem-mbco")`; planted defect: take the larger branch, test must fail
**Dependencies:** T13 | **Files:** `R/sem-constraints.R`, `R/sem-mbco.R`, tests | **Scope:** M

#### Task 15: Product inequalities, `:=` names, best-of-n multi-start
**Description:** `a*b > k`, `ab > 0` (a `:=` name inside a constraint) via closures; Lagrangian-Hessian acceptance gate; `n_starts` becomes best-of-n with the spread warning. `n_starts` meaning changes: NEWS note.
**Acceptance criteria:**
- [ ] `a*b > k` reaches the best branch in at least 90% of fixture starts with 5 starts
- [ ] The spread warning fires when starts disagree; silent when they agree
- [ ] NEWS entry for the `n_starts` change
**Verification:**
- [ ] `devtools::test(filter = "sem-")`; H-reliab regression; planted defect: Hessian of the Lagrangian replaced by H alone on a curved constraint, a fixture must fail
**Dependencies:** T13 | **Files:** `R/sem-optim.R`, `R/sem-constraints.R`, `NEWS.md`, tests | **Scope:** M

#### Task 16: Sums of products, best-effort (G12)
**Description:** `a1*b1 + a2*b2 == 0` fits via multi-start with the always-on spread warning; documented best-effort in `?"medfit-syntax"`.
**Acceptance criteria:**
- [ ] The fixture fits and warns on disagreement; the doc says best-effort
**Verification:**
- [ ] `devtools::test(filter = "sem-constraints")`
**Dependencies:** T15 | **Files:** `R/sem-constraints.R`, `R/sem-syntax-help.R`, tests | **Scope:** S

#### Task 17: `mbco_sem()` for a product of k paths
**Description:** `mbco_sem(fit, paths)` tests a product of k labeled paths by the minimum of k linear refits (current `a`, `b` form keeps working). Ships only if T18 passes.
**Acceptance criteria:**
- [ ] k = 2 equals the current result exactly; k = 3 serial model returns the minimum of three diffLLs
- [ ] Oracle test: statistic 4, alpha 0.05 gives p = 0.0455 at df 1; the df = 2 mutant fails
**Verification:**
- [ ] `devtools::test(filter = "sem-mbco")`
**Dependencies:** T10 | **Files:** `R/sem-mbco.R`, `tests/testthat/test-sem-mbco.R` | **Scope:** M

#### Task 18: Type I error gate for min-of-k MBCO (G13)
**Description:** `tests/sim/sem-mbco-k-size.R`: serial three-path model; nulls with one, two and three zero paths; several n; size and a power floor.
**Acceptance criteria:**
- [ ] Size at or below alpha plus Monte Carlo error in all configurations; power at the stated alternative above the recorded floor
- [ ] The chi-square(2) mutant fails the oracle and power floor
**Verification:**
- [ ] `Rscript tests/sim/sem-mbco-k-size.R` writes results; if size exceeds alpha, T17's k >= 3 path is withheld from the release
**Dependencies:** T17 | **Files:** `tests/sim/sem-mbco-k-size.R`, `tests/sim/results/` | **Scope:** M

#### Task 19: Nonlinear parity gate (G6)
**Description:** `tests/sim/sem-nonlinear-gate.R`: about 240 runs (4 problems x 3 models x 2 n x 10 seeds) against OpenMx with the pass rule in the harness table; one sum-of-products problem reports its hit rate without a threshold.
**Acceptance criteria:**
- [ ] Gate runs end to end and meets the pass rule, or its failures are listed and triaged
- [ ] Planted defects (row misclassified as linear; larger-branch pick; covariance projection frozen at the start) make it fail
- [ ] The gate reports SE agreement per cell and ends with `quit(status = 1)` on any failure
**Verification:**
- [ ] `Rscript tests/sim/sem-nonlinear-gate.R`; `--mutants` via T3
**Dependencies:** T14, T15, T16 | **Files:** `tests/sim/sem-nonlinear-gate.R`, `tests/testthat/helper-sem.R` | **Scope:** M

### Checkpoint C: after Tasks 13-19
- [ ] H-nonlinear, H-ksize, H-parity, H-constrained, H-reliab, H-unit, H-lint, H-check pass (counts reported)
- [ ] H-revdep run: probmed and RMediation suites against dev
- [ ] Notify the RMediation session that `anova()` and W3 are in dev (its handoff is unblocked)
- [ ] Review with the human

### Phase 4: Documentation (W5)

#### Task 20: lavaan-vs-medfit article, executed at site build
**Description:** `vignettes/articles/lavaan-comparison.qmd` runs both engines on `mediation_demo`; a test asserts every table row's status against a live probe (pattern: cookbook consistency).
**Acceptance criteria:**
- [ ] Article builds in pkgdown; statuses match probes; categorical outcomes row points to lavaan (WLSMV)
**Verification:**
- [ ] New consistency test fails when a row is edited; pkgdown article build succeeds
**Dependencies:** T11, T13 | **Files:** `vignettes/articles/lavaan-comparison.qmd`, `_pkgdown.yml`, `tests/testthat/test-lavaan-comparison.R` | **Scope:** M

#### Task 21: Docs for nonlinear constraints and audit gaps
**Description:** `?"medfit-syntax"` nonlinear syntax; `methods.qmd` (near-singular rejection, bound verdict split, nonlinear section); cookbook recipe for nonlinear MBCO; CLAUDE.md and AGENTS.md (eight classes, engines table); NEWS 0.7.0 serial/parallel wording.
**Acceptance criteria:**
- [ ] Each audit gap named in the BRAINSTORM is closed; refcard and cookbook tests pass
**Verification:**
- [ ] `devtools::test(filter = "refcard|cookbook|guide")`; `grep -rn "seven classes" CLAUDE.md AGENTS.md` empty
**Dependencies:** T13-T16 | **Files:** `R/sem-syntax-help.R`, `vignettes/articles/methods.qmd`, `vignettes/articles/cookbook.qmd`, `CLAUDE.md`, `AGENTS.md` (docs; touches more than 5 files, split into two commits) | **Scope:** M

#### Task 22: glm joint-significance recipe (G11)
**Description:** A short section on `model-glm-families.qmd` and a cookbook entry, restricted to likelihood families (quasi and estimated-dispersion families get a Wald or F procedure).
**Acceptance criteria:**
- [ ] Recipe runs; quasi families are excluded with the stated reason
**Verification:**
- [ ] `devtools::test(filter = "cookbook|model-pages")`
**Dependencies:** None | **Files:** `vignettes/articles/model-glm-families.qmd`, `vignettes/articles/cookbook.qmd` | **Scope:** S

### Checkpoint D: after Tasks 20-22
- [ ] H-docs and H-check pass; site builds
- [ ] Review with the human

### Phase 5: Release (owned by release engineering)

#### Task 23: 0.8.0 release grill
Release scope, version bump plan, what NEWS must say; the ledger asks for a grill first. **Dependencies:** Checkpoint D.

#### Task 24: Release PR
Version bump, NEWS, `.STATUS`, CI green, tag, GitHub release, r-universe check. Out of scope for this plan beyond the pointer. The E1 version-matrix row (W6) is a cross-repo write and waits for an explicit request after release. **Dependencies:** T23.

## Parallelization

- Safe to run in parallel: T1 and T2 and T3; T4, T5, T6; T10 and T11 (after Phase 1 if the boundary logic wants T8); T20 and T22.
- Must be sequential: T7 then T8 then T9; T13 then T14/T15; T17 then T18.
- Coordination: `R/sem-constraints.R` is touched by T6, T7, T8, T13-T16; do not run those in parallel branches.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Nonlinear work rests on unrecoverable S1 evidence | High | T1 re-derives it as fixtures; T9 closes S1 with an independent review; W3 starts only after T9 |
| Min-of-k LRT size exceeds alpha (my intersection-union argument is unchecked) | Medium | T18 gate; k >= 3 withheld if it fails |
| Vanishing Jacobian at products with two or more zero factors | Medium | Exact branch split (T14) with an explicit fixture |
| Silent local optimum on nonlinear rows | Medium | Best-of-n with spread warning (T15, T16); hit rate reported in H-nonlinear |
| `R/sem-constraints.R` merge conflicts across tasks | Medium | Sequence T6-T8 and T13-T16; one branch at a time |
| rhub flags an nloptr flavor failure | Low | Fallback: Suggests plus `requireNamespace()` guards; evidence first |
| The RMediation route depends on T10 and W3 | Medium | Handoff stays blocked; Checkpoint C notifies the other session |

## Open questions (carried from the ledger)

- `anova()` details left in G9: nesting check method; df with active constraints; bootstrap LRT (default: later).
- Exact fixtures for the nonlinear gate (G6): which four problems and three models.
- Whether the new gates run in CI or only locally (default: locally, results committed under `tests/sim/results/`).

## Review log

- **2026-10-11, Codex adversarial review of this plan (2 findings, both accepted, applied the same day):** (1) numerical failures must fail the harness: existing sim scripts print PASS/FAIL without a failing exit status (`sem-parity-gate.R`, `sem-constrained-gate.R`: no `quit()` or `stop()`; `sem-reliability.R`: errors excluded, no threshold), so T3 computes verdicts from results CSVs with committed thresholds and cell counts and adds four "exits 0 but bad" fixtures; (2) an independent nonlinear covariance oracle: T13 and H-nonlinear gain a Jacobian-annihilation check, an independent SE oracle and a frozen-Jacobian mutant. Evidence checked before accepting: `grep` of `quit(`/`stop(` in the three scripts found none that signal gate failure.
- **2026-10-11, self-review before approval (2 fixes, applied):** the `H-constrained` and `H-reliab` pass rules said "as recorded in its header", contradicting the verdict-from-results rule, and now point to `tests/sim/gates.csv`; T3's scope was S and is now M (driver, thresholds file, four fixtures, mutants mode). The author then approved the plan.
- **2026-10-11, RMediation session finding (refit trap), added to T10 and T14:** adding `mxConstraint(b1 == 0)` to an already-fitted OpenMx full model returned an infeasible point (diffLL 0) while the clean-start null gives 0.0830995; refits in `anova()` and the k-branch split therefore start clean, with a fixture and a planted defect each. Source: the results section of the RMediation handoff.
