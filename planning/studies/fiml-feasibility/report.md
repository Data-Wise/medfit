# FIML feasibility: adversarial review and local evidence

Study navigation and current state: [README](README.md); equations, decisions
and complete fix history: [technical record](technical-record.md).

2026-10-29. Technical GO for a separate, bounded design study; no production
implementation or expansion of 0.16 is approved by these results.

## Review verdict

The original scope needed six safeguards: a concrete consumer decision,
fixed-X semantics, an overidentified model, explicit SE coordinates and scaling,
independent likelihood formulations, and a distinction between technical
feasibility and native medfit readiness. The revised [protocol](protocol.md)
addresses each. A downstream adopter remains unverified, so product GO remains
open. Finite-fixture agreement is not proof of global optimization or validity
under arbitrary missingness.

## Reproducible local evidence

Run `Rscript planning/studies/fiml-feasibility/study.R` from this worktree.
The baseline is dev edcf23d8705165cd2497deda0d4e8410b9754811; protocol commit
7ba7e6a precedes execution. Installed versions and platform are in [session.txt](session.txt).
No package installation or production code changes were needed.

All **30 primary cells and 10 edge checks pass**, including 255 named
parameter/SE comparisons. Two models, three fixed seeds and five missingness
masks cover observed continuous Gaussian mediation with means and random X.
Independent grouped normal likelihood, row-wise Cholesky likelihood and
complete-data conditional densities agree. Total likelihood includes constants.

| Metric | Worst observed | Acceptance limit |
| --- | ---: | ---: |
| Total log-likelihood gap per retained row | 2.20e-14 | 1e-8 |
| Standardized parameter gap | 2.54e-7 | 1e-5 |
| Relative observed-Hessian SE gap | 3.65e-6 | 1e-3 |
| Independent average-NLL gradient | 2.28e-7 | 1e-5 |
| SE change at second Hessian resolution | 4.61e-5 | 1e-4 |
| Multistart average-objective spread | 5.11e-14 | 1e-8 |

Raw parameter gap is at most 2.55e-7. Retained rows agree with lavaan in every
primary cell (296–300). Hessians are positive definite and the selected BFGS
and nlminb fits report convergence. [results.csv](results.csv) and
[coordinates.csv](coordinates.csv) retain cell and coordinate evidence.

The [edge checks](edges.csv) cover row order, empty rows, shift/rescale identity,
complete-X fixed/random-X agreement, missing-X row selection, an all-missing
variable and a constructive nonidentification example. The latter exhibits
distinct path coefficients with exactly the same observed-data likelihood;
it does not rely on optimizer success or a Hessian at a nonoptimum.

Planted defects are caught: a listwise-fitted candidate loses 0.0125855 NLL per
row on the common observed dataset; omitted means violate likelihood agreement;
inverting the average rather than total Hessian gives relative SE error 16.3205.

## Failed approaches retained

The first numerical run passed 25/30 primary cells and 8/10 edges. Initial
results and warnings are preserved in `initial-*` files (display-only trailing
whitespace normalized). Five lavaan fits with
`rel.tol=1e-12` reported nonconvergence and unavailable SEs despite close
likelihoods. A diagnostic with 1e-8 and 1e-10 converged; final fits use 1e-10.
Acceptance thresholds were unchanged. This is fixture/version evidence, not
a universal recommendation for optimizer tolerances.

Explicit free X moments made X modeled even with `fixed.x=TRUE`, invalidating
the first row-retention probe. Omitting those free moments restored the intended
fixed-X comparison: 246 retained rows, exactly as independently counted.
The standalone rescaled-data fit also initially missed its objective criterion;
dimensionless optimization coordinates resolved the numerical scaling problem.
The evaluated likelihood and its acceptance criteria did not change.

Final warnings are expected empty-row exclusions and fixed-X missing-X deletion;
see [warnings.txt](warnings.txt). They are not silently counted as complete data.

## What remains before implementation

Current medfit uses complete-case preparation (`R/sem-fit.R`) and rejects missing
values in the native likelihood preparation (`R/sem-ml.R`). Replacing those
checks alone would be insufficient. A separate design must address pattern-wise
means/likelihood derivatives, information scaling, identification, fixed-X
policy, row/context ledgers and downstream resampling/comparison contracts.

The reference initializer requires at least ten complete observations. This
study therefore does not validate identifiable datasets with no complete cases.
Nor does it validate latent/categorical models, sampling weights, robust SEs,
nonlinear constraints, bootstrap, native derivatives or public APIs. Fixed-X
missing-data evidence is a row-retention probe, not an independent conditional
FIML implementation. A named adopter and deeper numerical implementation
research are appropriate next steps, separately from 0.16.
