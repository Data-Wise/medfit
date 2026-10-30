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

## Post-run evidence — 2026-10-30

This section records execution after the frozen contract above; it does not
change that contract. The four added fixture types are observed-X MAR, all seven
observed patterns plus an empty row, joint affine changes, and near-singular
estimable models. Free and zero direct paths give eight accepted cells. Two
existing no-overlap controls give exact numerical-stage rank refusals, preserving
completed attempts and solver calls. Public coefficient and full covariance
outputs from both medfit and raw lavaan references must have the independent
free-nine/zero-eight names, counts and multiplicities before reference indexing
or affine transport. Fast tests reject missing, duplicate and extra parameters
and evidence fields.

At source `f23b69d5`, the implementation run recorded 10 tests with 132 passed
assertions, no failures/errors/skips and two expected lavaan warnings about
intentional empty rows (134 testthat conditions). The fast harness passed
5 tests/31 assertions. The unchanged base-R derivative helper was calibrated
before renewed candidate fitting using 12 independent reference probes; its
worst relative information discrepancy was 5.43705970907512e-6. That calibration
was reused after the naming/schema repair, not rerun.

`fiml-regression-results-2026-10-30.csv` contains exactly these columns:
`cell`, `outcome`, `coefficient`, `covariance`, `nll`, `fixed_nll`,
`geometry_min`, `geometry_max`, `information_min`, `information_max`,
`modelcov_min`, `modelcov_max`, `modelcov_at`. Error columns use the frozen
criteria above. Geometry and information columns record normalized spectral
extrema; model-covariance extrema are labeled by evaluation point. Eight fitted
rows use the reference optimum; the two refusals use generating parameters and
have no fitted coefficient/covariance/information result. Near-singular minimum
model-covariance eigenvalues are 0.000760042984485444 (free) and
0.00114061610175568 (zero), both below the unchanged .01 diagnostic criterion.

Independent re-QA at the same source passed. It reused the previously completed
ten off-optimum row-density, observable-rank and input-identity probes, three
accepted public-fit/lavaan comparisons and the exact zero-direct refusal. Fresh
re-QA verified every model-covariance spectrum and actual-fit parameter/schema
defects. Four in-memory production mutations were detected: omitted Gaussian
constant, diagonalized intercept transport, diagonalized full covariance
transport with names preserved, and bypassed rank geometry. Two additional
validator mutations were detected. No production source changed. These checks
provide bounded numerical evidence, not MAR validity, global optimality or
confidence-interval coverage.

Pre-docs gates freshly passed 117 tests/1245 assertions with one documented
help-availability skip and no failures/errors/warnings, plus 24/24 existing FIML
simulation checks and zero package-context lints. The ten-cell implementation
results and derivative calibration were reused explicitly. Full final-suite
verification remains pending after the docs stage.

Earlier failed implementation and QA checkpoints remain in the active plan and
archived workspace reports. The repaired implementation, independent re-QA and
pre-docs PASS reports supersede those stage verdicts without deleting them.
Detailed commands and provenance are in
`_agents_workspace/fiml-regression-oracles/{implementer,qa,gates-pre-docs}.md`.
