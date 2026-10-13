# medfit 0.8.0 task list

Plan: `tasks/plan.md` (task numbers match). Gates and commands: "Verification harness" in the plan. Update `.STATUS` at each checkpoint.

**Closeout (2026-10-12):** T1-T24 and implementation gates are complete; 0.8.0 is published on GitHub and r-universe. Review dispositions below preserve what was waived versus performed. The RMediation notification and explicitly requested E1 matrix update remain follow-ups, not release gates.

## Phase 0: Evidence and harness
- [x] T1 Re-derive the S1 findings as committed fixtures (`planning/specs/evidence/native-sem-2026-10-11/`)
- [x] T2 Trigger `rhub.yaml` once; record the result in `.STATUS`
- [x] T3 Harness driver `tests/sim/run-gates.R` (`--fast`, `--sim`, `--mutants`); verdicts from results CSVs and `tests/sim/gates.csv`, four "exits 0 but bad" fixtures, a reliability threshold
- [x] T3b Harden the gate driver (Codex findings 1 and 4): `--sim` needs exit status 0 and a results file written during the run; stationarity checks both margins against `.sem_stat_tol` on far runs (distance saved in the CSV); four new mutants (spec `planning/specs/SPEC-gate-harness-hardening-2026-10-11.md`)

## Phase 1: Foundations (W1, W2)
- [x] T4 Named errors for `Y ~ Y` and duplicate `Y ~ X`
- [x] T5 Named error for infeasible bounds (F2)
- [x] T5b `fit_mediation()` applies `subset`/`weights`/`offset`/`etastart`/`mustart` to the original rows (unreleased #138 regression on `dev`; own branch `fix/glm-observation-level-args`, merges before the release PR; spec `planning/specs/SPEC-glm-observation-level-args-2026-10-11.md`)
- [x] T6 Accept consistent redundant inequality sets (F1)
- [x] T7 Port the NNLS multiplier-sign gate (needs T1)
- [x] T8 Unify the bound verdict (F4) + NEWS (needs T7) (#146)
- [x] T8b Close the F4 gap found by T9 (ledger G14, defects 1, 2, 5): the projected gate's bound test uses the plain gate's `abs(g_k)/sqrt(H_kk)` statistic and a positive-definite guard, and blames a bound only when its own statistic exceeds `.sem_stat_tol`; tests with an indefinite Hessian and a bound beside a wrong-sign inequality (needs T8)
- [x] T9 Close S1 with a fresh-context review (needs T7, T8): review recorded as ledger G14; F4 closed by T8b (#147)

### Checkpoint A
- [x] Full unit suite, lint, H-parity, H-constrained, strict `check` pass (counts reported; `.STATUS` progress_0_8_0, 2026-10-11)
- [x] rhub result recorded (`.STATUS` rhub_0_8_0_t2)
- [x] Human review release gate waived; review not recorded as performed (GRILL-0.8.0-release R2)

## Phase 2: `anova()` and SEMFit methods (W4)
- [x] T10 `anova()` for nested `SEMFit`s with boundary-null guard (G9); refits start clean (refit-trap fixture) (#148)
- [x] T11 `tidy()`, `glance()`, `confint()`; chi-square and df; decide `@converged` (#149: always TRUE for a returned fit, so `glance()` omits it)
- [x] T12 One naming convention; align arguments with deprecation (needs T11) (#150: lavaan's unspaced names, loadings `eta=~m2`; `weights`/`object` with `lifecycle` warnings)

### Checkpoint B
- [x] Unit, lint, strict `check` pass; `anova()` known answers and oracles green (release evidence: `.STATUS` release_0.8.0; T10/T11 evidence: progress_0_8_0)
- [ ] Human review not recorded as performed; no longer a release blocker (release proceeded on evidence, GRILL-0.8.0-release R2)

## Phase 3: Nonlinear constraints (W3)
- [x] T13 Nonlinear equality `a*b == c` end to end (needs T9); includes the curved-constraint covariance oracle and a frozen-Jacobian mutant (#151: closures over validated call trees, central-difference Jacobian, projected covariance)
- [x] T14 Exact k-branch split for zero products (needs T13); branch refits start clean (refit-trap fixture) (#152: up to 64 branches, clean default start each, `internals$branch`)
- [x] T15 Product inequalities, `:=` names, best-of-n multi-start + NEWS (needs T13) (#153: `a*b > k`, Lagrangian-Hessian gate, best-of-n with spread warning)
- [x] T16 Sums of products, best-effort (needs T15) (#154: best-effort, documented)
- [x] T17 `mbco_sem()` for a product of k paths (needs T10) (#155: `mbco_sem(fit, paths = )`, minimum of k refits against chi-square(1))
- [x] T18 Type I error gate `tests/sim/sem-mbco-k-size.R` (needs T17) (#156: size at most 0.055 at alpha 0.05, power 0.838, chi-square(2) mutant fails)
- [x] T19 Nonlinear parity gate `tests/sim/sem-nonlinear-gate.R` (needs T14-T16); reports SE agreement, exits nonzero on failure (#157: 240 runs, four planted defects fail; #160 Newton polish: estimates within 1e-5 of the exact optimum, 5.5e-11 observed)

### Checkpoint C
- [x] All gates in the harness table pass (counts reported); revdep run clean (2026-10-11, see .STATUS progress_0_8_0_phase3)
- [x] Human review release gate waived; review not recorded as performed (GRILL-0.8.0-release R2)
- [ ] Tell the RMediation session `anova()` and W3 are released in 0.8.0 (notification not recorded as sent)

## Phase 4: Docs (W5)
- [x] T20 lavaan-vs-medfit article, executed at site build (needs T11, T13) (#161: article, 18-row table checked by live probes)
- [x] T21 Docs for nonlinear constraints and audit gaps (needs T13-T16) (class count and engines line done 2026-10-11 in CLAUDE.md and AGENTS.md) (#162: cookbook recipe 12, polish in methods, 0.7.0 native-route wording fixed, CLAUDE.md and AGENTS.md)
- [x] T22 glm joint-significance recipe (G11) (#163: joint_test(), recipe 13, LRT for known dispersion and F otherwise)

### Checkpoint D
- [x] Docs tests and strict `check` pass (2026-10-11, dev 743d9e8: 0/0/0); site builds (pkgdown job green on #161-#163); human review waived (GRILL-0.8.0-release R2)

## Phase 5: Release
- [x] T23 0.8.0 release grill (planning/specs/GRILL-0.8.0-release-2026-10-11.md: GitHub only, release on the evidence, 0.8.0)
- [x] T24 Release PR (release engineering): #164 bump, #165 release merge commit 37171ec, tag v0.8.0, GitHub release; r-universe verified 2026-10-12: 0.8.0, release SHA 37171ec, status success (`.STATUS` release_0.8.0); E1 matrix row only on explicit request
