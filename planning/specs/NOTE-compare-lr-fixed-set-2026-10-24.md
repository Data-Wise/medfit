# NOTE: how `compare_lr()` represents a fixed exogenous set and a mean structure (T4a spike)

**Date:** 2026-10-24. **Task:** T4a of `planning/PLAN-0.14.0-native-defaults-2026-10-24.md` (spec R-4, ADR E-4).
**Evidence:** `planning/specs/evidence/compare-lr-fixed-set-2026-10-24/spike-t4a.R` and `spike-t4a.csv` (run from the
package root; lavaan, OpenMx).

## Question

`compare_lr()` refuses a fit with `fixed_x` or a mean structure (`R/compare-lr.R:150-157`). Removing those two lines is
not enough: `.lr_unsupported()` then refuses any table with a non-free row (`R/compare-lr.R:169`), which fixed
exogenous moments create, and lavaan's `fixed.x` is all-or-nothing while medfit's `fixed_x` (and the E-13 default)
can be a subset. Can each engine pose the same model, so its LR equals medfit's deviance difference?

## Result

Yes, in both engines, for every cell. Model: `mediation_demo`, two mediator/outcome equations, exogenous `treatment`
and `covariate1`; the restriction is `b == 0`. LR = `n * (f0 - f1)` in medfit, `2 * (logLik1 - logLik0)` in lavaan, the
`-2 log L` difference in OpenMx. Absolute difference from medfit's LR (102.3035672) per cell:

| Cell | lavaan, fixed rows | lavaan `fixed.x = TRUE` | OpenMx, fixed paths |
|---|---|---|---|
| nothing fixed | 1.1e-09 | — | — |
| all exogenous fixed | 1.5e-12 | 1.2e-12 | 4.4e-12 (cov data) |
| named subset (`covariate1`) | 1.1e-10 | — | 2.3e-13 |
| lenient subset (`treatment ~~ treatment` written, `covariate1` fixed) | 8.4e-13 | — | — |
| nothing fixed, saturated means | 3.1e-09 | — | — |
| all fixed, saturated means | 2.6e-11 | 2.4e-11 | 8.6e-11 (raw data) |
| named subset, saturated means | 4.3e-09 | — | 2.2e-11 (raw data) |
| lenient subset, saturated means | 5.0e-12 | — | — |

Conditional-likelihood check: medfit's LR with every exogenous variable fixed equals its LR with none fixed (difference
1.8e-12 without means, 1.1e-12 with): the fixed moments are the MLEs of a saturated exogenous block, so fixing them
does not move a likelihood-ratio statistic.

## Decision

1. **Translation (lavaan).** Pass `fixed.x = FALSE` always and write the fit's fixed set as fixed rows at the ML
   (N-denominator) sample moments: `x ~~ <s_xy>*y` for each pair in the set, and `x ~ <mean>*1` when the fit has a
   mean structure; pass `meanstructure =` the fit's `has_mean`. One rule covers all, named and lenient subsets;
   lavaan's own `fixed.x = TRUE` is used only as the oracle for the all-fixed cell. Rejected: `fixed.x = TRUE`, which
   cannot express a subset and would silently fix the lenient variable.
2. **Translation (OpenMx).** `mxPath(free = FALSE, values = <sample moment>)` for the pairs in the set; with a mean
   structure, raw data and a `one` path (fixed at the sample mean for the set, free otherwise); without one, the
   covariance data as today.
3. **Refined refusal at line 169.** A non-free row is allowed when it is an exogenous variance, covariance or
   intercept that medfit fixed through `fixed_x` (the fit's `internals$fixed_x` set) at its sample value; every
   other non-free row is still refused. The parameter-key comparison (`.lr_key_est()`) keeps using free rows only,
   which both sides already do.
4. **Mean structure.** Allowed when every intercept is free (saturated means): the covariance part and the LR are
   unchanged. An intercept that is fixed or constrained by the user stays refused, with that reason.
5. **No spec amendment.** R-4 is met as written.

## Sizes

- **T4b (lavaan):** M. `R/compare-lr.R` (refusal rules, model writer, `meanstructure`), tests for the six lavaan cells
  above plus a planted defect (`fixed.x = TRUE` for a named subset must fail), and new cells in
  `tests/sim/compare-lr-gate.R`.
- **T4c (OpenMx):** M. `R/compare-lr-openmx.R` (fixed paths, raw data and means path), the same cells at 1e-5.

## Limits of this spike

The restriction here is linear (`b == 0`). `compare_lr()`'s own null is the product null, which it poses to each
engine as its branch fits (`a == 0`, `b == 0`); the translation above does not depend on the restriction, so the same
rows carry over, but T4b's tests run the product null itself. Weights and factor covariates stay refused (separate
rules, unchanged).
