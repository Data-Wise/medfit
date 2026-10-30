# Bounded FIML prototype execution protocol

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

Executed locally; **NO-GO**, 38/42 regular cells and 12/13 edge checks pass.
See [prototype-report.md](prototype-report.md) for failed cells, harness method
corrections and preserved evidence. The frozen scope and limits above remain
unchanged; execution does not authorize production integration.
