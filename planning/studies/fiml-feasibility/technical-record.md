# Bounded FIML technical record

Date: 2026-10-29. Scope: the isolated research study and prototype only.
Initial numerical implementation verified at `b4a50f36`; current P2 repairs and
local PASS are documented in the [repair report](p2-repair-report.md). This document
records the plans, equations, decisions, fixes and evidence. It adds no public
API, production feature, release requirement or authorization to 0.16.

## Plan and authorization history

| Commit | Plan or result |
| --- | --- |
| `7ba7e6a7` | Freeze feasibility protocol and adversarial checks before fits |
| `59a0403c` | Record feasibility and numerical implementation research |
| `ce9b0566` | Bound prototype topology and prospective acceptance criteria |
| `3da88747` | Separate fixed-X reference probes from native acceptance |
| `4055b430` | Freeze prototype fixtures before implementation/execution |
| `c92b6fec` | Record initial prototype NO-GO with preserved failed evidence |
| `b4a50f36` | Resolve four optimizer failures; complete local acceptance PASS |

The original [protocol](protocol.md) required an independent likelihood,
explicit means, total-Hessian SE scaling, an overidentified model, missingness
nonidentification diagnostics, exact row accounting and planted defects.
The initial feasibility run passed 25/30 fits and 8/10 edges. Fixing solver
stopping, fixed-X syntax and dimensionless reference coordinates produced
30/30 and 10/10 without changing numerical acceptance limits.

Subsequent source research and six algebra probes motivated the
[memo](numerical-implementation-memo.md). Scope review separated numerical
prototype acceptance from production/API integration. The user authorized
this bounded prototype and later its optimizer repairs. Missing adopter
commitment is a product/integration issue; it did not negate that explicit
research authorization. Fixed-X probes remain reference evidence only.

The [prototype protocol](prototype-protocol.md) supersedes prospective wording
in earlier documents for execution details. The [current report](prototype-report.md)
supersedes the initial NO-GO result. Historical records remain preserved.

## Exact model and input boundary

```text
X = ix + eX
M = im + a X + eM
Y = iy + b M + cp X + eY
```

The disturbances are independent Gaussian variables with strictly positive
variances `vx`, `vm`, `vy`. Either `cp` is free or it is fixed exactly at zero.
There are three observed continuous variables, one group, free intercepts,
random X and unweighted rows. The free-path model has nine parameters; the
zero-direct-path model has eight and is overidentified in the full moments.

`prototype_prepare()` accepts a numeric matrix with columns exactly X, M, Y,
unique nonmissing row IDs, at least two observations per variable, positive
observed marginal SDs and no infinite entries. NA entries encode missingness.
It rejects fixed X, weights/extra arguments and invalid model selectors.
There are no latent variables, correlated residuals, other predictors,
interactions, feedback, parameter ties, constraints, robust SEs or bootstrap.
These settings are unsupported, not approximate extensions of this prototype.

## Implementation map and output record

| Function | Responsibility |
| --- | --- |
| `prototype_prepare` | Input checks, pattern cache, affine map and row IDs |
| `prototype_ram` | Exact free/zero direct-path RAM topology |
| `prototype_eval` | Total pattern NLL and actual RAM score |
| `prototype_hessian` | Full observed score derivative at two resolutions |
| `prototype_difference` | Stable anchored likelihood difference |
| `prototype_geometry` | Local moment-Jacobian rank diagnostic |
| `prototype_fit` | Separate solvers, gates, best candidate and covariance |
| `reference_fit` | Independently parameterized likelihood and transport |
| `lavaan_reference` | Affine lavaan fit and independent full transport |

The returned study-only list has `kind="study_only_fiml"`, `estimate`,
`covariance`, named `se`, standardized `theta`, total observed `H`, raw `nll`,
`attempts`, accepted objective `spread` and `prepared` cache/transport/row
metadata. It is not a public S7 class. Failures use
`fiml_prototype_diagnostic`. All errors after solver attempts complete retain the
attempt ledger, including spread/rank/information diagnostics and errors inside
Hessian evaluation or covariance inversion. Existing error classes/messages are
preserved. Input rejection before solving has no completed solver ledger.
No public downstream API consumes the result.

## Missingness patterns and the full likelihood

For nonempty pattern g, retain its observed variable set Jg, original row IDs,
count ng, observed sample mean yg and covariance Cg. Compute Cg with divisor
ng, including Cg = 0 for a singleton. Never invert Cg: a singular sample
pattern covariance is compatible with a regular model likelihood.

Let mug and Sg be the model-implied mean and covariance restricted to Jg.
Write Wg = inverse(Sg), dg = yg - mug, and Tg = Cg + dg dg'. The TOTAL
negative log likelihood, including normal constants, is:

```text
L(theta) = sum_g ng/2 * [
  |Jg| log(2 pi) + log det(Sg) + tr(Wg Tg)
]
```

`prototype_eval()` uses a Cholesky factor for each Sg. The implied covariance
must pass the existing native correlation-scale PD floor, 1e-10. Empty rows
contribute zero likelihood and are excluded from n, the number of rows with
at least one observed variable. They retain their original IDs in the ledger.
Do not use the number of observed cells or the complete-case count as n.

This likelihood models random X. It does not reproduce fixed-X missingness
policies by silently changing the model. Ignorable missingness and the stated
Gaussian model are assumptions; finite MAR fixtures do not establish validity
for arbitrary missingness mechanisms or real data.

## Affine coordinates and full covariance transport

Each variable is centered and scaled by its observed marginal mean cj and
SD sj. These statistics use available observations, not complete-case lm.
The standardized prototype starts have zero intercepts/paths and unit residual
variances, plus the two frozen deterministic trigonometric perturbations.

For standardized structural parameters (subscript z):

```text
a  = (sM/sX) az                 b  = (sY/sM) bz
cp = (sY/sX) cpz                vj = sj^2 vjz
ix = cX + sX ixz
im = cM + sM imz - a cX
iy = cY + sY iyz - b cM - cp cX
```

Omit cp terms when it is fixed at zero. Together these define an affine map
`theta_raw = offset + T theta_z`. T is not diagonal: its intercept rows
contain slope terms. Consequently, rescaling only covariance diagonals or
intercepts independently would be wrong. Large mean shifts amplify small
slope errors in structural intercepts.

```text
L_raw = L_z + sum_j n_observed_j log(sj)
g_raw = inverse(T)' g_z
H_raw = inverse(T)' H_z inverse(T)
V_raw = T inverse(H_z) T'
```

The Jacobian likelihood offset counts observations separately for each
variable. The prototype's T is analytic. The independent likelihood and
lavaan references use their own parameter maps and numerical Jacobians;
neither uses prototype transport. Full named matrices, not just SE diagonals,
are compared in original structural coordinates.

## Score, observed Hessian and N scaling

The native RAM functions supply actual mean/covariance derivatives:
`.sem_implied`, `.sem_implied_mean`, `.sem_dsigma` and `.sem_dmu`.
For parameter k, the pattern score contribution to the negative likelihood is:

```text
ng * [ tr((Wg - Wg Tg Wg) dSg/dtheta_k)/2
       - (dmug/dtheta_k)' Wg dg ]
```

The production complete-data `.sem_gate` evaluates a different likelihood and
cannot validate FIML. The research harness supplies explicit FIML objective,
stationarity, information and row gates instead of treating optimizer success
as acceptance.

`prototype_hessian()` differentiates the COMPLETE analytic pattern score.
It symmetrizes central differences and applies Richardson extrapolation:
`H = (4 H(h/2) - H(h))/3`. Initial steps are
`eps^(1/3) max(abs(theta_k), 1)`; variance steps are capped at variance/10.
A second resolution halves h. Invalid perturbations raise a study diagnostic.

The model covariance is the inverse Hessian of TOTAL L. The optimizer objective
is `2 L/n`, so its Hessian is `2 H_L/n`; do not invert that objective Hessian
as though it were H_L. The planted N-scaling defect multiplies the covariance
by n and is caught by the full covariance criterion.

If eta collects model means/covariances and D is its Jacobian:

```text
H_theta = D' H_eta D + sum_r (dL/deta_r) H_theta(eta_r)
```

The second term is mapping curvature. Model-coordinate stationarity does not
imply every unrestricted moment score is zero, especially in overidentified
models. The six numerical probes found omitted-curvature matrix discrepancies
of about 0.8–2.0% at fits and 7.9–9.5% at perturbed points. These are Hessian
matrix discrepancies, not percentages of SE error. The omission mutant fails.

## Stable likelihood differences and solver refinement

`prototype_difference()` avoids subtracting two large total likelihood
values by using an exact, locally accurate likelihood-difference formula. For an
anchor S0, mu0 and current S, mu, define deltaS = S-S0 and dd = mu0-mu.
With L0 L0' = S0, the log-determinant ratio is computed from:

```text
E = inverse(L0) deltaS inverse(L0)'
log det(S) - log det(S0) = sum_i log1p(eigenvalue_i(E))
W - W0 = -W0 deltaS W
```

For T0 = C + d0 d0', the remaining quadratic difference is:
`tr((W-W0) T0) + 2 dd' W d0 + dd' W dd`.
Constants cancel. Summing each term with ng/2 gives `L(theta)-L(anchor)`.
The refinement objective is `1 + 2 difference/n`. The constant 1 leaves all
derivatives unchanged while giving relative stopping a nonzero scale.
All 126 final identities agree with the independently computed likelihood.

Three starts are fitted separately by native scaled SLSQP and nlminb. Native
SLSQP uses `xtol_rel=1e-12`, `ftol_rel=1e-14`, `maxeval=10000`.
Nlminb uses `rel.tol=1e-10`, `x.tol=1e-12`, `iter.max=3000`, `eval.max=6000`.
It first fits the ordinary objective, then refines its OWN candidate against
the stable objective with the full `2 H_L/n` callback. No SLSQP candidate is
passed to nlminb. At least one accepted candidate from each solver is required.
The candidate with smallest total NLL is selected; accepted spread is gated.
SLSQP retains the native allowed statuses 1, 3, 4 and -4; even the allowed
roundoff-limited status -4 must pass the same independent stationarity and
likelihood checks. Nlminb refinement requires status 0. No status alone is
sufficient.

The ledger has 252 solver/start groups, not 252 total optimizer calls:
nlminb groups contain an initial fit and refinement, recording both statuses.
Extra fits used by edge checks are not part of the 42-cell primary ledger.
The independent reference's 126 start groups contain BFGS plus nlminb polish.
These ledgers are not complete per-iteration traces.

## Independent references and identification diagnostics

The standalone reference parameterizes marginal means, paths and log residual
variances. It constructs moments directly from the structural equations.
Its pattern likelihood uses solve/determinant operations, while a separate
case evaluator uses Cholesky whitening. Complete data additionally admit an
independent conditional-normal regression factorization.

For the prototype's 42-cell reference comparison, BFGS is followed by nlminb
with numerical gradients AND Hessians of this independent likelihood. Its
polish uses relative stopping 1e-10. The original feasibility default remains
1e-13 with nlminb's own numerical derivatives. Both selected stage statuses
must be zero; independently checked gradients and start agreement must pass.
No reference optimization uses RAM derivatives or prototype estimates.

The 42-cell lavaan reference uses `missing="fiml"`, `fixed.x=FALSE`, free
means, normal ML, standard SEs, and observed Hessian information. It fits
standardized data and independently transports all parameters/covariances.
Its transformed likelihood is also evaluated by the independent original-data
likelihood. The original raw-data 30-cell/10-edge harness still runs unchanged
in its default numerical settings, including the two reference-only fixed-X
probes. Namespace-only objects require `lavaan::vcov` and `lavaan::logLik`.

Numerical observed curvature alone previously gave the deliberately
nonidentified no-overlap fixture tiny positive curvature and finite SEs.
The study therefore additionally checks observed-pattern moment geometry:

```text
G_kl = sum_g ng [ mu_k' Wg mu_l
                 + tr(Wg S_k Wg S_l)/2 ]
```

This positive Gram matrix diagnoses LOCAL observable-moment rank. It is not
a global identification certificate or an expected-information SE estimator
under MAR. Both G and the observed Hessian must pass the native 1e-4
Jacobi-scaled minimum-eigenvalue diagnostic; conditioning is retained.
The no-overlap fixture has 150 XM-only rows and 150 Y-only rows and must raise
a typed diagnostic. Expected-information agreement probes do not establish
repeated-sampling coverage under MAR. Robust/sandwich SEs remain deferred.

## Fixtures, fixed gates and regression evidence

The 30 original cells cross seeds 271, 613, 997; free/zero direct paths; and
complete, monotone MCAR, nonmonotone MCAR, observed-X MAR and missing-X MCAR
masks. Each has n=300 before empty-row exclusion.
The 12 additional cells apply both models to six predeclared fixtures:
no complete rows with all three pair patterns; singleton patterns; all seven
nonempty patterns; shifts (100,-200,300); scales (100,0.01,3); and Y residual
SD 0.03 with seeded nonmonotone missingness. The current construction uses
`(.03 / .9) * noise` because the base generator uses residual SD 0.9. An
independent seeded reconstruction using `rnorm(sd = .03)` tests both model
variants. Earlier results accidentally used SD 0.027; that history is preserved
in the [P2 baseline](p2-review-baseline/README.md), not silently rewritten. The
current construction matches the frozen [prototype protocol](prototype-protocol.md).

Acceptance limits are unchanged: likelihood/row 1e-8; standardized estimates
1e-5; relative SEs and SE-product-normalized full covariance 1e-3; gradient
discrepancy 1e-6; stationarity 1e-5; Hessian discrepancy 1e-4; second-resolution
SE change 1e-4; and accepted objective spread/row 1e-8. Require the same
coordinate names and multiplicities, finite matrices and positive reference
SEs. Covariance differences use independent-reference SE products as the
normalizer, even when the reference covariance entry itself is zero.

U is diagonal with intercept SDs, outcome/predictor SD ratios for paths and
squared SDs for variances. Stationarity uses `max(abs(U grad(L/n)))`.
Derivative comparisons use `U grad(L/n)` and `U H_L U`, dividing maximum
absolute error by `max(1, max(abs(reference)))`.
The independent Hessian check uses Richardson orders 4 and 6, eps=0.01, and
relative variance perturbations to stay in the positive domain. The analytic
score-derived Hessian is independently checked at two resolutions.

The final run passes 42/42 fits, 13/13 edge checks, 126/126 derivative points
and 126/126 likelihood identities. It retains 12,600 original row IDs and
1,071 gradient coordinates. All four defects are caught: listwise fitting,
omitted means, wrong Hessian N scaling and omitted mapping curvature.
Other edge checks cover row order, empty rows, affine shift/scale, all-missing
variables, unsupported settings, invalid implied PD and nonidentification.
The [report](prototype-report.md) gives the worst errors against every limit.

## Fix history and rejected alternatives

| Problem/evidence | Repair or decision |
| --- | --- |
| Initial 25/30 fits, 8/10 edges | Fix syntax, stopping and scales |
| Covariance dispatch failed | Use `lavaan::vcov` |
| No complete rows | Initialize from marginal statistics |
| No-overlap fixture returned SEs | Add local moment-rank diagnostic |
| Noisy default Hessian steps | Larger steps, two Richardson resolutions |
| Variance probes crossed zero | Relative variance perturbations |
| Shifted nlminb stationarity failed | Supply full Hessian to own refinement |
| Tight stopping alone failed | Reject; retain independently checked gates |
| Near-singular oracle status 1 | Own derivatives and revised stopping |
| Raw lavaan intercept missed limit | Affine fit and full covariance transport |
| Tighter relative tolerance failed | Reject as ineffective |
| Tighter parameter tolerance: status 1 | Reject despite improved point |
| BFGS failed parameter comparison | Reject for this fixture |
| Intermediate full run: 41/42 | Preserve and diagnose before final PASS |

Initial prototype runs and smoke results remain in the named historical
artifact directories. The 38/42 NO-GO snapshot is retained at `c92b6fec` and
in `optimizer-repair-baseline/`. Rejected optimizer/reference probes and the
41/42 run remain in `optimizer-repair-probes/`. No acceptance threshold or
required status was widened to turn a failure into a pass.

## Decisions, consequences and deferred work

Accepted FOR THIS STUDY: cache pattern moments; include means explicitly;
standardize without listwise initialization; reuse real RAM derivatives;
use full observed curvature; transport full covariance; require solver/status,
stationarity and rank evidence; retain failed attempts; preserve independent
parameterization and numerical derivative checks.

Rejected as acceptance substitutes: optimizer status alone, diagonal-only SE
agreement, saturated-model evidence alone, one shared likelihood implementation,
positive numerical Hessian alone, survivor-only summaries and expected-pattern
information algebra as proof of MAR SE validity. These choices add computation
and ledgers but keep numerical failure visible.

Not authorized or demonstrated: production missing-data API/default changes,
fixed-X missing-covariate policy, weights, robust/expected-information SEs,
latent/categorical models, nonlinear constraints, bootstrap, profiles, MBCO,
fit indices, AIC/BIC or broad extraction compatibility. An adopter/use case,
API contracts, downstream support/rejection rules, production tests, independent
QA and applicable gates need a separate integration decision. There is no
inference-coverage simulation, global optimization certificate, performance
benchmark or cross-platform validation. These open items do not block 0.16.

## Reproduction and evidence integrity

Use the isolated worktree root with already installed R/package dependencies:

```sh
Rscript planning/studies/fiml-feasibility/prototype-acceptance.R
```

This command rewrites `prototype-results/`; preserve the current receipt
before rerunning. It reruns the original study in `prototype-results/reference/`
and exits nonzero if any required acceptance cell/edge fails. It is not a
production package test runner or a hosted gate.

The final numerical receipt reports R 4.6.2, lavaan 0.7-3 and numDeriv
2016.8-1.1. Local R links OpenBLAS 0.3.34; that does not mean the deferred
hosted OpenBLAS/platform workflow was run. Final local runtime was about
37 seconds. See [session information](prototype-results/session.txt).

[Source provenance](source-manifest.json) records the inspected CRAN source
archive, its SHA256 and source-file hashes. Twelve selected installed function
bodies/formals match inspected source, as recorded in
[source-functions.csv](source-functions.csv). This comparison does not verify
all compiled dependencies or every installed function.

[Evidence hashes](evidence-manifest.json) cover study artifacts recursively;
the manifest excludes itself. [Validation receipt](optimizer-repair-validation.json)
records final counts and the four baseline-fail/current-pass regressions.
R parsing and namespace lint pass for all three numerical scripts. Markdown
lint, relative-link checks, hash verification, diff whitespace checks and a
scoped secret-pattern scan validate the documentation/evidence change.
The original documentation-only consolidation did not rerun numerical acceptance;
the subsequent P2 repair did, as recorded below.
No production package suite, coverage collection, expensive CI, push, release
or dev-to-main merge is implied or performed.

## P2 review repairs and regression evidence

The authorized follow-up resolved the two findings at reviewed baseline
`c7430172`. A single post-solver condition handler attaches all six solver/start
records to any later error without changing its class or message. The acceptance
harness requires these records on the no-overlap diagnostic and saves them in
[diagnostic_attempts.csv](prototype-results/diagnostic_attempts.csv).

The near-singular fixture now implements the intended SD 0.03 rather than the
previous unintended SD 0.027. This changes only the two near-singular data cells;
thresholds, seeds, missingness masks and the remaining 40 fixtures are unchanged.
Four standalone regression tests pass 61 assertions. They cover real rank
failure for both models, forced spread/information rejection, typed and ordinary
Hessian errors, and independent fixture reconstruction. New tests first failed
on the original behavior; the failing log remains in the historical baseline.

Current acceptance still passes 42/42 fits,13/13 edges,126/126 derivative points
and126/126 likelihood identities. The original reference harness passes30/30
fits and10/10 edges. Six study scripts parse and pass namespace lint. See the
[P2 repair report](p2-repair-report.md) and [validation receipt](p2-repair-validation.json).
No production code, 0.16 scope, push or expensive CI is involved.

## Bounded integration design authorized, implementation deferred

After the P2 repair review, the user authorized defining the adopter, opt-in API,
preserved defaults and downstream rules. The [integration design](integration-design.md)
proposes medfit's native simple-mediation workflow as the first engineering
adopter, an appended explicit missing-data option, mandatory random X, and a
bounded support/refusal matrix. It identifies the finite-discrepancy ledger and
extraction-provenance seams that must change under a future implementation plan.
The design is proposed for review, not an implemented API or a verified external
adopter commitment. Production implementation remains unauthorized and separate
from 0.16; no numerical evidence or historical acceptance criterion changed.
