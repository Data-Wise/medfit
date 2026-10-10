# Plan: fix the mixed equality and inequality Jacobian in the native SEM engine

**Status:** implemented 2026-10-10 (tests first, red on the old source, green after the fix; see the PR). One plan deviation: the active-inequality oracle uses lavaan with `rel.tol = 1e-12`, because lavaan's default stop leaves it 3e-6 from its own converged solution (b 0.299433 default, 0.2994357 tight; native 0.2994353). Branch `fix/sem-mixed-constraint-jacobian` (off `dev` `5274eac`).
**Origin:** Codex adversarial review of `main...dev`, finding 1 (high), reproduced here.

## The defect

`.sem_nlopt_constraints()` (`R/sem-constraints.R:88-104`) builds the equality and the inequality
callbacks in one function environment and assigns both Jacobians to the same name, `jac`. The
closures capture the environment, not the value, so when both blocks exist the inequality
assignment overwrites the binding the equality callbacks read. The solver then enforces the
inequality's row as an equality, and `eval_jac_g_eq` returns a matrix of the wrong shape.

Introduced in PR 5 (#114, `0ff25e2`). `dev` only: 0.7.0 is unreleased, so no released version
carries it and no NEWS "Bug fixes" entry is needed (the constraints bullet under "New features" is
already unreleased).

## Reproduction (run 2026-10-10 against `5274eac`)

Model `M ~ a*X; Y ~ b*M + cp*X`, n = 500, seed 11.

| Constraints | Native engine (bug) | lavaan |
|---|---|---|
| `a == 0` (control, equality only) | a = 0, b = 0.4029, cp = 0.1726 | same |
| `a == 0`, `b + cp < 1` (1 eq, 1 ineq) | error: `a == 0` violated by 4.63e-01; callback `eval_g_eq` returns 0.3536 where the row gives 0.1 | 0, 0.4029, 0.1726 |
| `a == 0`, `b + cp < 1`, `cp > -5` (1 eq, 2 ineq) | same error | n/a |
| `a == 0`, `b + cp < 0.3` (active inequality) | same error | 0, 0.2994, 0.0006 |
| `a == 0`, `cp == 0.1`, `b + cp < 1` (2 eq, 1 ineq) | nloptr error: "wrong number of elements in jacobian of equality constraints (is 6, but should be 2 x 6 = 12)" | 0, 0.4323, 0.1 |

Gap in the tests: `test-sem-constraints.R` covers equalities alone, inequalities alone, and
two equalities, never one of each. The oracle test's case list (line 89) is all one kind per case.

## The fix

Two bindings, `jac_eq` and `jac_ineq`, one per block. Nothing else changes: `.sem_active_set()`
already builds the equality and inequality rows separately (`rbind` of the two), so only the
nloptr callback construction is affected.

## Tests, written first (all in `tests/testthat/test-sem-constraints.R`)

1. **Callback level** (no optimizer): for 1 eq + 1 ineq, 2 eq + 1 ineq and 1 eq + 2 ineq, with
   scale vector `u` both all-ones and non-trivial, assert `eval_g_eq`, `eval_jac_g_eq`,
   `eval_g_ineq`, `eval_jac_g_ineq` against an independent computation:
   `A %*% (u * x) + b` and `sweep(A, 2, u, "*")`.
2. **End to end against lavaan** (`skip_if_not_installed("lavaan")`, tolerance 1e-5, the file's
   existing pin): the three shapes in the table, covering an inactive inequality, an active
   inequality and two equalities with one inequality.
3. **Planted defect** using `sem_mutate()` (helper-sem.R), applied twice because the bug is a
   rename: rebuild `.sem_nlopt_constraints` with the inequality block writing `jac_eq`, then
   assert the callback test fails. The pattern must match exactly once per mutation.
4. **Positive control for the record:** revert the fix in the source, run the new tests, confirm
   they fail, restore. Quote the transcript in the PR body (`e2e-before-pr.md`).

Order: tests 1-3 red on the current source, then the fix, then green.

## Side effects to check

- `mbco_sem()` appends `a == 0` and `b == 0` to the user's model. A model that already has an
  inequality was broken in the same way before this fix; add one `mbco_sem()` case on a model with
  an inequality constraint (in `test-sem-mbco.R`) once the fix is in.
- Run the full suite and lint; the 10 s per-file runtime budget still applies.

## Out of scope (the review's other two findings, separate fixes)

- `R/bootstrap.R:495-506`: the few-cluster advisory is caught as a refit failure, so a
  cluster bootstrap with fewer than 25 clusters discards every replicate. This is in released
  0.6.0 code; needs its own reproduction and a condition-class fix.
- `R/methods-sem.R:58`: `logLik()` and model df ignore the rank of explicit equality constraints
  (`a == b` gives df 9 instead of 8, model df 0 instead of 1).
