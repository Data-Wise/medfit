---
decisions:
  - {id: TL-1, title: "Two-level estimates match lavaan to 0.01 SE with a 1e-4 absolute floor; adapter arithmetic to 1e-10; a closed form to about 1e-5", status: decided, date: 2026-11-18}
  - {id: TL-2, title: "Two-level SEs match to 1e-3 relative only against fixed.x = FALSE at the same information", status: decided, date: 2026-11-18}
  - {id: TL-3, title: "Native two-level fits are compared with lavaan fixed.x = FALSE", status: decided, date: 2026-11-18}
  - {id: TL-4, title: "Hand-built O8 log-likelihood: absolute logLik without Z, nested-fit differences with Z, both to 1e-6", status: decided, date: 2026-11-18}
  - {id: TL-5, title: "OpenMx is a third oracle under the same rules; a disagreement beyond them stops the work", status: decided, date: 2026-11-18}
  - {id: TL-6, title: "Frozen SLSQP fixtures are pinned at 1e-6 across platforms", status: decided, date: 2026-11-18}
  - {id: TL-7, title: "Each tolerance is valid only if its matching planted defect fails it; the zeroed cross-level vcov block validates the SE bound", status: decided, date: 2026-11-18}
---

# ADR: tolerances for the two-level oracles

Status: DECIDED, 2026-11-18 (task U1 of `planning/PLAN-multilevel-remainder-2026-11-18.md`; unblock condition U1 of
`planning/PLAN-multilevel-implementation-gaps-2026-11-11.md`). Source: section 0.5 of
`planning/specs/PLAN-multilevel-mediation-2026-11-10.md`, and its section 0.8 decision S1-Q2.

## Context

Every two-level oracle (the native S4 route and the U3 three-way oracle: hand-built O8 likelihood, lavaan, OpenMx) needs fixed
tolerances before results are judged, so that a failing comparison cannot be met by widening the tolerance afterward. Section 6
of the multilevel plan set 1e-6 for estimates and 1e-3 relative for SEs against lavaan. The review in section 0.5 showed those
numbers are wrong for lavaan two-level fits: lavaan's default optimizer is about 1e-5 from the closed form, and `fixed.x = TRUE`
against `fixed.x = FALSE` moves estimates by about 5e-5 and SEs by 3-4%.

**Section 6's 1e-6 (estimates) and 1e-3 (SEs) tolerances are superseded by this ADR**, including the "paths and joint vcov to
1e-6 / 1e-3" in the cluster-only covariate fixture row. The one 1e-6 kept is the frozen-fixture pin (TL-6), which is a
cross-platform reproducibility rule, not an oracle tolerance.

## Decisions

**TL-1. Estimates.**

| Comparison | Tolerance |
|---|---|
| Estimate vs lavaan | `abs(diff) <= max(0.01 * SE, 1e-4)`, SE from the lavaan fit |
| Adapter arithmetic vs the lavaan fit's own numbers (the adapter reads, reorders or combines lavaan output) | 1e-10 |
| Estimate vs a closed form (balanced saturated `Sigma_W = S_PW`, `Sigma_B = (S_B - S_PW) / n`) | about 1e-5 (lavaan's optimizer error); `test-twolevel-likelihood-oracle.R` uses 1e-5 for means and 1e-4 for the covariance blocks |

Observed gaps behind the floor: 5e-5 against an SE of 0.17. The check is already implemented as `tl_check_paths()` in
`tests/testthat/helper-twolevel-likelihood.R` (`abs(hand - lav) - pmax(0.01 * lav_se, 1e-4) <= 0`).

**TL-2. Standard errors.** 1e-3 relative, **only** against lavaan `fixed.x = FALSE` with the same information (`observed`,
`h1.information = "structured"` unless the comparison states otherwise). Against a default `fixed.x = TRUE` fit the SEs differ
by 3-4% (`se(ab)` 0.166 vs 0.172) by design; that gap is a documented difference, not a tolerance, and no test may absorb it by
loosening the SE bound.

**TL-3. Native comparison convention.** Native two-level fits are compared with lavaan `fixed.x = FALSE` (full ML, no fixed
between-level moment). Native two-level defaults to `fixed_x = FALSE` until a fixed-moment convention has its own oracle
(S1-Q2; that oracle is unblock condition U2).

**TL-4. Log-likelihood (hand-built O8).**

- Without a cluster-only covariate Z: the hand log-likelihood at lavaan's estimates equals lavaan's absolute `logLik()` to 1e-6
  relative (`tl_check_loglik()`, `tol = 1e-6`, in `helper-twolevel-likelihood.R`). The hand maximum may not fall below the hand
  likelihood at lavaan's converged point by more than 1e-6 absolute. The reduced cluster density equals the stacked
  multivariate normal density to 1e-10 (exact arithmetic identity).
- With Z: the objective matches lavaan only up to a parameter-free constant, so the absolute value is not compared. The
  difference in log-likelihood between nested fits is compared, and must agree with lavaan's difference to 1e-6 absolute (the
  same 1e-6 as the absolute bound above: the constant cancels, so only optimizer error remains). The bound is absolute, not
  relative as for `tl_check_loglik()`, because a difference between nested fits can be near zero, where a relative bound means
  nothing. No Z fixture exists yet; this is
  the tolerance it will use.

**TL-5. OpenMx as third oracle (U3).** OpenMx estimates and SEs are judged by TL-1 and TL-2 exactly as lavaan's are (OpenMx
standing in for lavaan, with exogenous variances and means free, which is how `fixed.x = FALSE` is expressed in a RAM
model). A disagreement among O8, lavaan and OpenMx beyond
these tolerances is a stop: it goes to the maintainer as a finding, and the tolerance is not widened to absorb it.

**TL-6. Frozen SLSQP fixtures.** Optimizer outputs frozen as fixtures are pinned at 1e-6. CI Linux and macOS differ at about
1e-9 (BLAS and floating-point order), so a tighter pin fails across platforms for no statistical reason; bit identity is checked
locally only.

**TL-7. Planted-defect rule.** A tolerance is valid only if a planted defect of the size in section 0.5 fails it, and each
tolerance is validated by the defect that moves what it checks:

| Tolerance | Validating defect |
|---|---|
| SE and vcov (TL-2, the SE side of TL-5) | the zeroed cross-level vcov block: the SE of `a_w - a_b` is 0.1898 joint vs 0.1792 zeroed (5.6%), caught by the 1e-3 relative bound by a factor of about 50; the fixture's `Cov(a_w, a_b)` = -0.00195 is asserted directly as nonzero in `@vcov` |
| Estimates (TL-1, the estimate side of TL-5) | the section 0.5 estimate defects: level swap, group-1/level-1 mis-keying on unlabeled models, the `.l2` suffix mismatch |
| Log-likelihood (TL-4) | the O8 (d) term errors: a missing `(n_j - 1) log|Sigma_W|`, a wrong `n_j`, a within row for Z, a dropped `p_w log n_j` |

The zeroed block changes no estimate and no log-likelihood, so it does not test TL-1 or TL-4. The contrast `a_w b_w - a_b b_b`
(0.48%) and the bootstrap are sanity checks only. A proposed tolerance that its validating defect passes is rejected.

## Consequences

- S4 and U3 tests cite these ids in a comment where they set a tolerance.
- A change to any value here is a new decision in this file with `supersedes:`, not an edit to a test.
