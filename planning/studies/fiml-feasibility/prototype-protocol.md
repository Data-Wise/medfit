# Bounded FIML prototype execution protocol

Study navigation and current state: [README](README.md); equations, decisions
and complete fix history: [technical record](technical-record.md).

Authorized 2026-10-29, separately from 0.16. Baseline medfit dev edcf23d8;
scope/criteria commit 3da8874. Local research only; no production changes,
push, public API, expensive CI, release or integration.

## Frozen scope and comparisons

Use exactly the three-variable Gaussian mediation models in the
[memo](numerical-implementation-memo.md): free or zero direct path, random X,
free intercepts, independent disturbances, positive variances, unweighted rows.
Reject all other settings. Keep the original 30 cells and 10 reference edges;
only eight of those edges apply to the prototype. Fixed-X probes remain
reference-only, with prototype fixed-X requests rejected.

Prototype implementation and harness belong only in this study directory.
Read existing RAM moment/derivative functions and `.sem_solve_one` through the
local package namespace. Do not modify or shadow functions in that namespace.
The native complete-data acceptance gate is inapplicable to FIML; explicitly
evaluate FIML likelihood, stationarity and information in the research harness.

## New fixtures fixed before prototype execution

Each regular fixture below is fitted under both free/zero direct-path models,
in addition to the 30 original cells (42 regular fits total).

| Fixture | Deterministic construction |
| --- | --- |
| No complete rows | seed 613; cycle XY, XM, MY observed pairs over 300 rows |
| Singleton patterns | seed 997; first six rows have each incomplete mask once |
| All seven patterns | seed 997; cycle the seven nonempty three-variable masks |
| Shifted | seed 271 MAR-X; add (100,-200,300) to X,M,Y |
| Rescaled | seed 271 MAR-X; multiply X,M,Y by (100,0.01,3) |
| Near-singular regular | seed 271 nonmonotone MCAR; residual Y SD 0.03 |

The singleton fixture's other 294 rows are complete. Near-singular regular data
are generated from the same equations with Y residual SD 0.03, then the same
seeded missingness procedure; no covariance is manually repaired.

Diagnostic fixtures: all-missing variable; existing no-overlap nonidentification
construction; model-implied covariance below the existing correlation-scale PD
floor (Y residual variance 1e-14 in standardized units); and unsupported-setting
requests. Empty rows are excluded with exact row-ID accounting, not fit failures.
Single-observation pattern covariance is zero and need not be inverted.

## Numerical methods and fixed gates

Use marginal means/SDs for affine data standardization, not listwise regressions.
Initialize independent paths at zero, marginal means at their observed values
and positive diagonal variances. Three deterministic standardized starts:
zero paths/unit variances/zero intercepts and signed 0.12/0.15 trigonometric
perturbations. Run scaled native SLSQP and independent nlminb; retain every
attempt/status. Compare accepted candidates without cross-solver polishing.

Use a Cholesky pattern likelihood and actual RAM analytic mean/covariance
derivatives. Differentiate the complete pattern gradient for observed Hessians;
transport covariance back to original intercept/path/variance coordinates.
Compare with a separate marginal-mean/log-variance likelihood optimizer and
lavaan observed-Hessian full covariance. The independent initializer uses
marginal statistics so identifiable no-complete-row data remain testable.

All limits in the memo remain unchanged: likelihood/row 1e-8, standardized
estimates 1e-5, SEs and SE-product-normalized covariance 1e-3, scaled gradient
discrepancy 1e-6, stationarity 1e-5, scaled Hessian discrepancy 1e-4, second-
resolution SE stability 1e-4 and accepted objective spread/row 1e-8. Original
primary-cell raw-gradient, independent-formulation and optimizer gates also
remain in force. Report conditioning, not just positive eigenvalues; reuse
the native Jacobi-scaled information diagnostic threshold where applicable.

Record full named covariance entries, gradients/Hessians at the fit and two
deterministic perturbations per cell, and exact row ledgers. Required planted
defects: listwise fitting, omitted means, wrong Hessian N scaling and omitted
moment-mapping curvature. Check row ordering, empty rows and known affine
likelihood/estimate/covariance transformations. Diagnostic fixtures must never
return an ordinary successful finite-SE result.

Freeze these choices before running. Preserve failed attempts, diagnose them
without widening gates, and distinguish reference-only checks from prototype
outcomes. A local PASS authorizes neither production integration nor changes
to 0.16. Acceptance is pending until every required check has run and passed.

## Execution result

The initial local run at `c92b6fec` was NO-GO (38/42 regular cells and 12/13
edges). The authorized optimizer repair now passes **42/42 cells, 13/13 edges
and 126/126 derivative checks**. Full Hessian refinement, independent numerical
oracle derivatives and affine lavaan reference fitting change numerical
methods without changing the frozen fixtures or acceptance limits above.
See [prototype-report.md](prototype-report.md) for methods, failed alternatives
and evidence. The original raw-data reference study still passes 30/30 cells
and 10/10 edges with its previous default solver settings. Local PASS does
not authorize production integration or change the 0.16 scope.

## Authorized post-review corrections

The review at `c7430172` found two implementation/evidence gaps. The near-singular
fixture had multiplied residuals of generating SD 0.9 by 0.03, yielding SD 0.027.
The correction divides by 0.9 first, restoring the predeclared SD 0.03 without
changing seeds, masks or acceptance limits. Earlier SD-0.027 results remain
archived as historical evidence.

Every error after all solver attempts now carries the completed attempt table.
The no-overlap edge requires and exports all six solver/start records. Four
standalone regression tests (61 assertions) cover both corrections; they first
failed on the original behavior. Full local acceptance passes with corrected
data. See the [repair report](p2-repair-report.md). This is still research only,
separate from 0.16 and production integration.
