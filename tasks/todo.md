# medfit 0.8.0 task list

Plan: `tasks/plan.md` (task numbers match). Gates and commands: "Verification harness" in the plan. Update `.STATUS` at each checkpoint.

## Phase 0: Evidence and harness
- [x] T1 Re-derive the S1 findings as committed fixtures (`planning/specs/evidence/native-sem-2026-10-11/`)
- [ ] T2 Trigger `rhub.yaml` once; record the result in `.STATUS`
- [x] T3 Harness driver `tests/sim/run-gates.R` (`--fast`, `--sim`, `--mutants`); verdicts from results CSVs and `tests/sim/gates.csv`, four "exits 0 but bad" fixtures, a reliability threshold
- [ ] T3b Harden the gate driver (Codex findings 1 and 4): `--sim` needs exit status 0 and a results file written during the run; stationarity checks both margins against `.sem_stat_tol` on far runs (distance saved in the CSV); four new mutants (spec `planning/specs/SPEC-gate-harness-hardening-2026-10-11.md`)

## Phase 1: Foundations (W1, W2)
- [x] T4 Named errors for `Y ~ Y` and duplicate `Y ~ X`
- [x] T5 Named error for infeasible bounds (F2)
- [ ] T5b `fit_mediation()` applies `subset`/`weights`/`offset`/`etastart`/`mustart` to the original rows (unreleased #138 regression on `dev`; own branch `fix/glm-observation-level-args`, merges before the release PR; spec `planning/specs/SPEC-glm-observation-level-args-2026-10-11.md`)
- [ ] T6 Accept consistent redundant inequality sets (F1)
- [ ] T7 Port the NNLS multiplier-sign gate (needs T1)
- [ ] T8 Unify the bound verdict (F4) + NEWS (needs T7)
- [ ] T9 Close S1 with a fresh-context review (needs T7, T8)

### Checkpoint A
- [ ] Full unit suite, lint, H-parity, H-constrained, strict `check` pass (counts reported)
- [ ] rhub result recorded; human review

## Phase 2: `anova()` and SEMFit methods (W4)
- [ ] T10 `anova()` for nested `SEMFit`s with boundary-null guard (G9); refits start clean (refit-trap fixture)
- [ ] T11 `tidy()`, `glance()`, `confint()`; chi-square and df; decide `@converged`
- [ ] T12 One naming convention; align arguments with deprecation (needs T11)

### Checkpoint B
- [ ] Unit, lint, strict `check` pass; `anova()` known answers and oracles green
- [ ] Human review

## Phase 3: Nonlinear constraints (W3)
- [ ] T13 Nonlinear equality `a*b == c` end to end (needs T9); includes the curved-constraint covariance oracle and a frozen-Jacobian mutant
- [ ] T14 Exact k-branch split for zero products (needs T13); branch refits start clean (refit-trap fixture)
- [ ] T15 Product inequalities, `:=` names, best-of-n multi-start + NEWS (needs T13)
- [ ] T16 Sums of products, best-effort (needs T15)
- [ ] T17 `mbco_sem()` for a product of k paths (needs T10)
- [ ] T18 Type I error gate `tests/sim/sem-mbco-k-size.R` (needs T17)
- [ ] T19 Nonlinear parity gate `tests/sim/sem-nonlinear-gate.R` (needs T14-T16); reports SE agreement, exits nonzero on failure

### Checkpoint C
- [ ] All gates in the harness table pass (counts reported); revdep run clean
- [ ] Tell the RMediation session `anova()` and W3 are in dev; human review

## Phase 4: Docs (W5)
- [ ] T20 lavaan-vs-medfit article, executed at site build (needs T11, T13)
- [ ] T21 Docs for nonlinear constraints and audit gaps (needs T13-T16) (class count and engines line done 2026-10-11 in CLAUDE.md and AGENTS.md)
- [ ] T22 glm joint-significance recipe (G11)

### Checkpoint D
- [ ] Docs tests and strict `check` pass; site builds; human review

## Phase 5: Release
- [ ] T23 0.8.0 release grill
- [ ] T24 Release PR (release engineering); E1 matrix row only on explicit request
