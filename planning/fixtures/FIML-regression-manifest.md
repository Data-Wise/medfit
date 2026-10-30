# Frozen FIML regression fixture contract

This manifest and `fiml-regression-manifest.csv` were generated and committed
before any candidate fits for this milestone. Fixture definitions are in
`tests/testthat/helper-fiml-oracle.R`; identities are MD5 of R serialization v2
(`saveRDS(data, version = 2)`) and freeze the complete input, including row order.
All inputs have roles X -> M -> Y and optional X -> Y, independent Gaussian
innovations, random X, free structural intercepts, and 300 retained rows.
The combined-pattern case alone appends all-empty row 301. Fixed seeds, RNG draw
order, missingness rules and near-singular innovation SD .03 are source-defined.
Affine data use scale (3,.5,2) and shift (2,-3,4), jointly; the paired base is MAR.

## Parameters and independent references

Public names are a,b,(cp),X~~X,M~~M,Y~~Y,X~1,M~1,Y~1. The final three are
structural intercepts, not marginal means. The oracle constructs the triangular
structural loading matrix explicitly, then mu=L*intercepts and Sigma=L*D*L'.
For each row it selects exactly the observed marginal and uses a Cholesky
Gaussian NLL with the dimension-specific log(2*pi) constant; empty rows add zero.
The fixed shared parameter vector is the generating coefficients .5,.6,(.25),
variances 1.21,.64,.81 (near: last variance .0009), intercepts .8,-.4,.7, with
cp omitted for zero-direct models. Affine transform that vector for affine data.
Compare the independently mapped production objective at this off-optimum
vector, and row oracle versus public logLik at the returned optimum.

lavaan must use missing='ml', fixed.x=FALSE, meanstructure=TRUE,
information='observed', matching free/zero direct path. Compare full named
coefficient/covariance outputs in base units. For affine fixtures compare to a
lavaan reference fitted in base coordinates, then transport both medfit outputs
back to base coordinates before checks. The affine NLL offset is
sum_j n_observed_j * log(scale_j); both intercept and full covariance transport
use the complete affine Jacobian, not a diagonal path-only rescaling.

## Identification and conditioning

CSV eigenvalues are independently computed at the generating vector, using
numerical derivatives of explicit structural moments, and pattern-wise Gaussian
Fisher geometry in data-standardized solver coordinates. No production geometry
helper was used. Full rank is expected for all accepted fixtures; disjoint
(X,M)/Y controls have rank 7 of 9/free or 8/zero. Rank threshold for this manifest
is normalized geometry eigenvalue >1e-7; it is not a production cutoff.
Report reference observed-information and observable-moment geometry normalized
minimum/maximum eigenvalues at the reference optimum. Also report normalized
model-covariance spectrum to demonstrate near-singular data geometry; the near
fixture must have minimum covariance-correlation eigenvalue <.01. The production
acceptance cutoff remains 1e-4 for normalized information/geometry, unchanged.

## Fixed acceptance criteria

Absolute coefficient error <=1e-5; max full covariance discrepancy divided by
outer(reference standard errors) <=1e-3; absolute NLL discrepancy <=1e-7.
Affine comparisons use base coordinates and account for the NLL offset.
Retained row/pattern counts must match the CSV exactly. Deliberate unidentified
controls must raise medfit_sem_fiml_error with stage='numerical' and exact reason
'observed-pattern moment Jacobian is rank deficient', retaining genuine completed
attempts and solver calls. A different refusal does not pass this control.
Neither MAR validity, global optimization nor CI coverage is claimed.

Every candidate cell must be recorded, including failures/refusals. No tolerance
changes or fixture substitutions after observing fits are permitted without a
separately reviewed numerical justification. Existing pair-only no-complete-row
oracle gate and route/no-RNG/provenance controls remain unchanged.
