# PLAN: independent floored-profile comparator for the floor fixture (#276, slice 1)

Status: revised after Codex adverse review (4 findings accepted, see end), 2026-10-21. Branch `docs/plan-floor-comparator-276` (plan only, no code).
Origin: Codex design review of #276 (2026-10-21, findings 2, 4, 6, 7 and the "minimal first slice"); issue #276; plan
`PLAN-constrained-lr-solver-2026-10-19.md`; closes the evidence gap left by #281/#285.

## Overview

Fixture `var-1e6-1e-6` in `tests/sim/sem-nonlinear-profile-gate.R` has a true `Vy` below the solver floor
(`.sem_var_floor` = 1e-4 x natural unit, `R/sem-optim.R:286`), so the floor binds. Today the gate does not compare its
LR value with anything: `lr_oracle` is `NA` (gate line ~143) and a run passes on the contract "warned + at floor +
finite + q met", or on a single-start warning alone. On a CPU where the fit lands on a wrong branch with one accepted
start (the runner's OpenBLAS), the gate cannot tell a right floored optimum from a wrong one.

The existing oracle (`tests/sim/oracle213.R`) solves the unfloored problem, so it cannot serve as the comparator
(`Vy` unbounded below). Slice 1 builds the floored variant of the same independent profile, uses it to compare LR on
the floor fixture, and turns "single-start warning" from a pass into a classified outcome. It changes no package code
and no exported API.

Non-goals (separate slices of #276): Tier 1 charts, AUGLAG fallback, `solver =`, `status`/`require =`, the
`slsqp_legacy` text sync (D18), any claim that a fit is globally optimal.

## What the comparator can and cannot say

- A lower independent feasible candidate **disproves** the returned optimum (sound, one-sided).
- Agreement with the independent profile **does not certify** the optimum: the profile is a finite grid scan on each
  sign branch (RESULTS-A2 records missed basins on coarse grids). The gate may say "no disproof found", never
  "certified".
- Names in code, CSV and docs: `disproved` / `agrees`, never `certified` or `global`.

## Architecture decisions

1. **Floor enters the oracle as an explicit input, not a medfit call.** `or213_fit(d, q, vm_min = 0, vy_min = 0)`.
   The gate computes the floor value itself from the data (floor = `1e-4 x natural unit`; the natural unit is
   `.sem_step_floor()`, an internal) from the fixture with the solver's own sample-moment rule (divisor n). The check
   is numeric, not textual (Codex AR1: the warning prints only the multiplier `1e-04`): a strict row must have the
   fitted `Vy` within the solver's bound window of the computed floor (`.sem_bound_window` = 1e-6 x natural unit, absolute,
   `R/sem-optim.R:17`; the floor itself is 1e-4 x unit, so a fit reported at the floor may sit about 1% above it, and
   1e-8 relative would reject valid fits, Codex AR5), `Vy` must be in `active_bounds`, and a separate assertion
   checks the computed bound equals the solver's bound (`.sem_var_floor * .sem_step_floor`); a floor that is
   not the fit's floor therefore fails the row instead of agreeing by accident. The oracle stays free of medfit code.
2. **Inner problem stays convex.** In `or213_profile_t` the unknowns are `u = Vm^-1/2`, `z = Vy^-1/2` (strictly
   convex). A variance floor is a box `u <= 1/sqrt(vm_min)`, `z <= 1/sqrt(vy_min)`. Solve by nesting: `z(u)` clipped at
   `z_max`, then the 1-D convex profile in `u` root-found and clipped at `u_max`. Nested minimization of a jointly
   convex function over a box is exact, so the floored profile in `t` is still a one-dimensional scan per sign branch.
3. **Pass/fail on the floor fixture becomes a classification computed from numbers**, recorded in the `note` column:
   `strict` (warned, at floor with the numeric floor check above, finite, q met, `|lr - oracle| <= tol`), `flagged`
   (single-start warning or refusal, and `lr <= oracle + tol`), `disproved` (`lr > oracle + tol`, hard failure whether
   or not flagged), `oracle_above_fit` (`lr < oracle - tol`, hard failure: the oracle or the floor is wrong). A
   refusal has no LR and is `flagged` only on the fixture's known refusal message.
4. **A disproved fit is a hard gate failure, flagged or not** (Codex AR2: letting up to three of six disproved rows
   pass would ship a known wrong fit green). Consequence: the gate is red on any machine where the solver lands on the
   wrong branch. So this PR merges only if T5 shows zero disproved rows on the runner; if the runner shows disproved
   rows, the PR stays open as evidence (draft), the counts go to #276, and the gate change lands together with the
   solver slice that removes them. The existing >= 50% strict share stays as a second, independent condition: it is the only rule that catches a floor
   fixture whose rows are all refusals or all flagged (no LR to disprove). While this PR is draft evidence, `dev` stays
   green because the gate change has not merged.
5. **No new warning class, no API change.** Test-only; `NEWS.md` needs no entry; `test-api-freeze.R` is untouched.

## Review protocol

After each phase a Codex adverse review runs before the next phase starts (G1 after Phase 1, G2 after Phase 2, G3 after
Phase 3). Each review: one `codex-companion.mjs adversarial-review --wait --base origin/dev` call with a focus text
naming what to attack, findings triaged in the review tables at the end of this plan (accepted, rejected with reason,
or deferred with an issue), fixes committed before the phase is called done. A "needs-attention" verdict with an
untriaged finding blocks the next phase. The plan's own two earlier adverse reviews (AR1-AR7) are the precedent.

## Dependency graph

```
T1 floored oracle (oracle213.R)
   |-- T2 oracle self-checks (floor inactive == old oracle; floor binding vs brute force)
   '-- T3 gate uses it on floor_case rows (sem-nonlinear-profile-gate.R)
            '-- T4 driver rules + mutants + baseline (run-gates.R, results CSV)
                     '-- T5 runner validation (gates workflow on the slice branch) + docs/.STATUS
```

## Task list

### Phase 1: the comparator

- [x] **T1: floored profile in the independent oracle** (S) (done 2026-10-21; defaults bit-identical on 5 datasets x 5 q, tiny floor equals unfloored exactly, existing 110-case self-check unchanged)
  Description: add `vm_min`, `vy_min` to `or213_profile_t`, `or213_branch`, `or213_fit`, `or213_lr` with defaults 0
  (unchanged behavior). Implement the box by clipping as in decision 2. `q == 0` keeps the exact union of linear nulls
  but each null is refit with the floor: after `a = 0` or `b = 0` the remaining variances are closed form
  (`K/n`, `(E - D^2/C)/n`, `C/n`, `E/n`); floor them by `max(., min)` (valid: the variance profile is unimodal).
  Acceptance:
  - [ ] defaults reproduce every existing oracle value bit-for-bit on the 24 gate fixtures (no behavior change)
  - [ ] with a floor below the unconstrained variances the result equals the unfloored result to 1e-9
  - [ ] `stopifnot` guards that `vy_min` and `vm_min` are non-negative and finite
  Verification: `MEDFIT_ROOT=<this worktree> Rscript tests/sim/oracle213.R` (the self-check defaults to the main
  checkout, Codex AR4; change the default to the script's own repo root) and write any scratch RDS to `tempdir()`.
  Files: `tests/sim/oracle213.R`. Dependencies: none.

- [x] **T2: oracle self-checks for the floored case** (S) (done 2026-10-21: `tests/sim/oracle213-floor-check.R`, standalone, no medfit code; hand, feasible, control, grid, gridctl, equiv all pass)
  Description: extend the self-check block in `oracle213.R`.
  Acceptance:
  - [ ] a hand case with a known binding floor: `q = 0` branch where `Vy = (E - D^2/C)/n < vy_min`, expected value computed by hand in the test
  - [ ] brute-force check: on a coarse 2-D grid over `(u, z)` plus `t` for the floor fixture's data, no *floor-feasible* grid point beats the oracle value by more than 1e-6
  - [ ] planted-defect control, correctly directed (Codex AR6: removing the clip enlarges the feasible set, so the oracle can only go lower and a grid check cannot see it): the oracle returns its parameters, the check asserts `Vy >= vy_min` and `Vm >= vm_min` at the returned point, and the no-clip variant must fail that assertion (it returns `Vy < vy_min`) on the floor fixture
  - [ ] a second hand case with a binding `Vm` floor (the fixture only binds `Vy`), so the oracle's `Vm` clip is exercised and a planted removal of it is caught
  - [ ] unfloored equivalence from T1 repeated here as a check, not only a one-off
  Verification: `Rscript tests/sim/oracle213-floor-check.R` (standalone file, exits 1 on any FAIL); the control uses the oracle called without floors.
  Files: `tests/sim/oracle213.R`. Dependencies: T1.

### Checkpoint: oracle
- [ ] **Codex adverse review G1** (before Phase 2): `codex-companion.mjs adversarial-review "--wait --base origin/dev <focus: the floored oracle, T2 controls, any assumption about R/sem-optim.R>"` over the Phase 1 diff; triage every finding (accept/reject with reason) in the plan's review table; fixes land before T3 starts.
- [ ] Oracle self-checks pass, planted defect is caught, old gate results unchanged (`Rscript tests/sim/run-gates.R --sim --only nonlinear-profile` still passes).

### Phase 2: the gate

- [ ] **T3: floor-fixture rows compare LR with the floored oracle** (M)
  Description: in the `floor_case` branch compute `floor_unit` and the two floors, call `or213_lr(d, q_ach, vm_min,
  vy_min)`, store it in `lr_oracle`, store `gap`, add `disproved` (logical) to the CSV. Apply decision 3. A refused fit
  keeps gap 0 and `note = "refused"`. Assert the computed floor equals the floor quoted in the "solver floor" warning
  text (parse `1e-04`), so the oracle and the fit cannot silently use different floors.
  Acceptance:
  - [ ] strict rows have `gap <= 1e-6 * max(1, lr_oracle)` or `lr < lr_oracle` (a lower medfit value than the independent one is a failure with note "oracle above fit")
  - [ ] flagged rows record `disproved`; silent rows with `lr > oracle + tol` fail with the numbers in the note
  - [ ] the 6 q rows of the fixture report both numbers on macOS; any strict row off by more than tolerance is investigated before the baseline is regenerated
  Verification: `Rscript tests/sim/sem-nonlinear-profile-gate.R` (full), `FAST=1` variant.
  Files: `tests/sim/sem-nonlinear-profile-gate.R`. Dependencies: T1, T2.

- [ ] **T4: driver rules, mutants, baseline** (M)
  Description: `run-gates.R` nonlinear-profile: add `lr_oracle` and `disproved` to the needed columns. The driver
  recomputes the signed difference `lr - lr_oracle` from the CSV numbers itself and asserts that `note`, `disproved`
  and `native_ok` agree with it (Codex AR3: a rule that reads only `note` cannot see a planted disproof), rejects
  missing or non-finite `lr`/`lr_oracle` on every returned floor row, and fails on any `disproved` or
  `oracle_above_fit` row. Self-test kinds: `floor_disproved_silent` (a strict-labeled row with `lr` raised above the
  oracle), `floor_oracle_missing` (floor rows with `lr_oracle` NA), `floor_note_lies` (note says strict, numbers
  disagree). Gate-owned mutants `nofloororacle` (oracle called with floors 0) and `noclip` (T1 clip removed) are
  environment switches of `sem-nonlinear-profile-gate.R`; `run-gates.R --mutants` only mutates committed CSV data
  (Codex AR4), so the plan registers and executes them explicitly (see T4 verification). Regenerate the baseline CSV.
  Acceptance:
  - [ ] `Rscript tests/sim/run-gates.R --mutants` rejects every CSV mutation and passes every control, including the three new kinds
  - [ ] `MUTANT=nofloororacle Rscript tests/sim/sem-nonlinear-profile-gate.R` and `MUTANT=noclip ...` each exit 1 (run explicitly; recorded in the PR body with exit codes)
  - [ ] `--sim --only nonlinear-profile` passes on macOS; floor rows all `strict` and `gap` within tolerance
  - [ ] baseline CSV committed; `gates.csv` row count unchanged (144)
  Verification: the two commands above; lintr on the three touched files.
  Files: `tests/sim/run-gates.R`, `tests/sim/sem-nonlinear-profile-gate.R`, `tests/sim/results/sem-nonlinear-profile-gate-2026-10-21.csv` (+ dated name if the date moves). Dependencies: T3.

### Checkpoint: macOS evidence
- [ ] **Codex adverse review G2** (before Phase 3): same command over the Phase 2 diff (gate rule, driver recomputation, mutants, baseline CSV); focus on silent passes, label/number consistency and mutant coverage; triage in the review table; fixes land before T5 dispatches.
- [ ] mutants pass, sim passes, lint clean, PR opened to `dev`.

### Phase 3: runner evidence

- [ ] **T5: validate on the runner and record** (S)
  Description: run `gh workflow run gates.yaml --ref <branch>` on the PR branch (the runner is OpenBLAS, see memory
  `gates-runner-uses-openblas`). Expected outcomes and what each means:
  - all strict and agreeing: record, no further action
  - some rows flagged and `disproved`: the comparator has found the wrong-branch fit the old gate could not see; record the count in `.STATUS` and #276; this is the evidence for the solver slice, not a failure of this slice
  - strict rows disagreeing with the oracle: stop, the oracle or the floor derivation is wrong
  Update `.STATUS` and a comment on #276 with the numbers. Per decision 4, zero disproved rows is the merge condition.
  Acceptance: at least 5 gate dispatches on the implementation head, each with its floor-row counts recorded (one run
  proves little: the wrong-branch landing is CPU-dependent and repeatable only per machine, Codex AR7); no row silently
  disproved in any of them.
  Files: `.STATUS`. Dependencies: T4.

### Checkpoint: complete
- [ ] **Codex adverse review G3** (before merge): over the final PR diff plus the T5 run records (counts per dispatch); focus on whether the evidence supports the merge condition; triage in the review table.
- [ ] PR merged on green; #276 comment states what the comparator established and what it did not (no certification); the solver slice is scoped from the measured `disproved` count.

## Risks and mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Floor unit (`.sem_step_floor`) is internal; the oracle's floor drifts from the fit's | High: false disproofs or false agreement | T3 numeric check: fitted `Vy` equals the computed floor to 1e-8 relative; mutant `nofloororacle` |
| Profile scan on the floored problem misses a basin (grid of 0.02 in log t) | Medium: the comparator under-reports disproofs | Said plainly: no disproof is not certification; T2 brute-force 2-D grid control; widen the grid for the floor fixture only |
| Floored oracle has a bug that mirrors medfit's | Medium | Independent derivation, hand case in T2, brute-force grid; no medfit code in the oracle |
| Disproved rows are hard failures, so the gate is red on a wrong-branch machine | Medium | Intended (decision 4): the PR merges only with zero disproved rows on the runner, otherwise it stays draft evidence for the solver slice |
| `q = 0` floored branch closed forms wrong when both variances floor | Low | T2 hand case; the exact union is checked against the profile at q -> 0+ |
| Date-stamped baseline CSV name drifts from `gates.csv` | Low | follow the #285 precedent: regenerate in place, same name unless the date changes in `gates.csv` too |

## Open questions

0. `gates.yaml` runs automatically only on PRs to `main` and is not a required check (Codex AR7), so "zero disproved
   rows" is a manual merge condition, not an enforced one. Making `gates (rest)` required for PRs to `dev` is a
   repository setting and the maintainer's call; until then the merge condition is enforced by this plan and by the
   reviewer. Recommendation: decide before the solver slice, not before T1.

1. ~~Where does the natural unit come from?~~ Settled: the gate calls `medfit:::.sem_step_floor` for the scale only;
   the numeric check (fitted `Vy` equals the computed floor) catches a wrong unit either way.
2. Should a `disproved` flagged row eventually carry a `status` of `unresolved` in the fit result (solver slice), or
   does the single-start warning stay the only signal? Out of scope here; decide in the solver slice.
3. One floor fixture only (`var-1e6-1e-6`) or add a second, e.g. `Vm` floor binding? Recommendation: one fixture now;
   add a second only if T5 shows the first is solved on every machine.

## Adverse review triage (Codex, 2026-10-21, base origin/dev)

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| AR1 | high | warning text does not verify the oracle's floor | accepted: numeric check against fitted `Vy` and `active_bounds` (decision 1, T3) |
| AR2 | high | disproved-but-flagged rows pass | accepted: hard failure; merge condition is zero disproved on the runner (decision 4, T5) |
| AR3 | medium | driver trusts `note`/`native_ok` | accepted: driver recomputes the signed difference and cross-checks labels (T4) |
| AR4 | medium | self-check hits main checkout and `/private/tmp`; `--mutants` does not run gate-owned mutants | accepted: worktree root and `tempdir()`; explicit `MUTANT=` runs (T1, T4) |

Codex also found the inner box optimization and the floored `q = 0` variance refits mathematically sound.

### Second adverse review (Codex, 2026-10-21, base origin/dev~2)

| # | Sev | Finding | Disposition |
|---|-----|---------|-------------|
| AR5 | high | 1e-8 floor equality is tighter than the solver's active-bound window (1e-6 x unit vs floor 1e-4 x unit) | accepted and verified in `R/sem-optim.R:17`; tolerance is the bound window, plus a separate computed-bound assertion (decision 1) |
| AR6 | high | removing the clip enlarges the feasible set, so a grid cannot detect it | accepted: feasibility assertion on the returned parameters (T2) |
| AR7 | medium | one dispatch is not a durable merge gate; gates not required on dev | accepted: >= 5 dispatches with recorded counts (T5); required-check question recorded (open question 0) |
