---
name: medfit-oracle-check
description: How to verify a medfit numeric change - pick an independent oracle per claim (lavaan, OpenMx, lm, the model with a parameter fixed in syntax, the fit without the feature), set tolerances, plant defects the tests must catch, and run metamorphic checks. Use whenever a medfit change alters estimates, standard errors, likelihoods, test statistics or the native SEM engine, including "verify", "check the numbers", "is this right", "add an oracle test".
---

# medfit oracle check

A test that compares the code with its own earlier output only proves nothing moved. medfit's rule (CLAUDE.md,
Testing Strategy) is to verify numeric claims against an independent oracle and to plant a defect the test must
catch. This skill is the procedure.

## 1. List the claims
From the task's acceptance criteria, write each numeric claim as one line: what quantity, for which model, under which
settings (mean structure, `fixed_x`, weights, `se_type`, constraints, bounds, products, factors).

## 2. Pick an oracle per claim

| Claim about | Oracle | Typical tolerance |
|---|---|---|
| unconstrained native estimates/SEs | `lavaan::sem(..., fixed.x =, meanstructure =, information = "observed")` | 1e-5 to 1e-6 |
| a constrained or bounded parameter | the same model with the parameter fixed in the syntax (`0*x`, `0.9*x`) | 1e-6 to 1e-8 |
| anything that a mean structure should not change | the fit without the mean structure (`meanstructure = NULL`) | 1e-8 |
| anything `fixed_x` should not change | the fit with `fixed_x = FALSE` (structural rows only) | 1e-6 |
| LR / chi-square differences | lavaan `2 * (logLik1 - logLik0)`, OpenMx `-2logL` difference | 1e-6 |
| total effect, regression paths | `lm(Y ~ X + C)` | 1e-8 |
| a nonlinear-constraint optimum | OpenMx with tight `mxOption()` tolerances | 1e-5 |
| an effect SE | delta method by hand, or a nonparametric bootstrap SD | bootstrap: a few percent |

Compare only rows that exist on both sides (`intersect()` of names); intercepts move with the data's means, so a
mean-shift check compares slopes only. Use `expect_identical(x, 0)` for structural zeros, never a tolerance.

## 3. Plant defects
For each new test, show it can fail:
- remove the fix (the pre-fix run counts if you saw it fail for the stated reason);
- replace an exact rule with a tolerance, or a named argument with its old value;
- pass the wrong setting through (e.g. `fixed_x = FALSE` where the subset belongs).

In tests, use `sem_mutate(fn, old, new)` (`tests/testthat/helper-sem.R`) with an exact, unique pattern, wrapped in
`fx_skip_covr()` when the mutation edits instrumented code. Capture internal call arguments with
`testthat::local_mocked_bindings()`; build the parent fit before installing the mock, or the mock records the
parent's own call and the test passes vacuously.

## 4. Metamorphic checks
Pick one invariance the change must respect: shifting every observed mean, rescaling a variable (estimates scale,
z-statistics do not), reordering equations, or relabeling parameters.

## 5. Report
Write one row per cell (cell, oracle, tolerance, result) and one per planted defect (mutation, caught?). Verdict PASS
only when every cell ran and agreed and every defect was caught.

## Pitfalls seen in this repo
- Centered coordinates (`.sem_center_map()`) round-trip structural zeros to about 1e-18; check pinned rows with
  `expect_identical(., 0)`.
- `.sem_fit_branches()` and `mbco_sem()` refit through `.sem_fit_syntax()`; check what settings they receive.
- lavaan's `fixed.x` is all-or-nothing; a named subset is posed as fixed rows at the N-denominator sample moments
  (`planning/specs/NOTE-compare-lr-fixed-set-2026-10-24.md`).
- semopy needs `options = {"ftol": 1e-12}` to agree at 1e-6.
