# FIML numerical implementation: research and design options

2026-10-29. Separate from 0.16. Research artifacts only; no production changes,
external submissions or expensive CI. This memo supplements the bounded
[feasibility report](report.md), rather than granting implementation approval.

## Recommendation and evidence boundary

Proceed to a narrow native-kernel design, retaining medfit's existing optimizer
and acceptance infrastructure initially. Start with single-group observed
continuous Gaussian models, explicit random X, free means and observed-Hessian
model SEs. Preserve listwise deletion as the default. Require an explicit
future FIML request and an explicit random-X choice; do not silently change
medfit's current fixed-X default. Fixed-X FIML needs its own design and oracle.

The local study passes 30/30 fit cells and 10/10 edges. This follow-up adds
six algebra probes and verifies that 12 inspected functions in the downloaded
lavaan 0.7-3 source have identical bodies and formals to installed lavaan.
Neither result validates a native medfit FIML implementation. No downstream
adopter has yet been verified.

## Source provenance

The owning source is the [CRAN lavaan 0.7-3 source archive](https://cran.r-project.org/src/contrib/lavaan_0.7-3.tar.gz),
SHA-256 `c1e9ecbd01dde0ada6bda11f0f9e84babfefebf06d1ab5887b4bd8d24ebb6787`.
[source-manifest.json](source-manifest.json) records file hashes;
[source-functions.csv](source-functions.csv) records installed/source matches.
Line references below refer to this archive, not an assumed current GitHub head.
GitHub links are navigation aids; the archive/hash pins the inspected version.
Installed R/package versions are in [session.txt](session.txt).

## 1. Cache missingness patterns, not one global covariance

For pattern g, cache observed indices O_g, retained row IDs, count n_g,
observed mean ybar_g and ML covariance C_g (divisor n_g). Let
V_g = Sigma[O_g,O_g], d_g = ybar_g - mu[O_g], and
T_g = C_g + d_g d_g'. The total negative log likelihood is

```text
L = (1/2) sum_g n_g {p_g log(2*pi) + log|V_g| + tr(V_g^-1 T_g)}.
```

Pattern covariance need not be invertible: only model-implied V_g is inverted.
A singleton pattern has C_g = 0. Empty rows contribute zero and must be
reported separately. Retain original row IDs for later resampling and comparisons.

Lavaan implements this representation in `R/lav_samplestats.R:2519`
(`lav_samp_mi_patterns`) and evaluates it in
[`R/lav_mvnorm_missing.R:77`](https://github.com/yrosseel/lavaan/blob/master/R/lav_mvnorm_missing.R#L77).
The latter computes a global inverse and obtains observed-block inverses with
`lav_mvn_mi_pattern_inv` (`R/lav_mvnorm_kernels.R:198`), using an inverse-update
routine. This is an optimization, not a statistical requirement.

**Design choice:** begin with a Cholesky factorization and triangular solves
per observed block. Keep the existing row-wise evaluator as an independent
oracle. Benchmark inverse updates only after agreement is established; no
speed advantage for medfit's small models has been measured. Do not use a
generalized inverse to turn an invalid implied covariance into a valid density.

## 2. Means and objective scaling are part of the contract

FIML cannot generally be obtained by globally centering incomplete data and
running a covariance-only objective. Pattern means contribute to the objective
and its derivatives. Lavaan's FIML route uses mean structures; see
`R/lav_options.R:998` and the [mean-structure tutorial](https://lavaan.ugent.be/tutorial/means.html).
medfit already computes implied means, but its complete-case centering and
coordinate transport must be audited for pattern data.

Keep three quantities distinct:

| Quantity | Required relationship |
| --- | --- |
| Total NLL L | Includes all observed normalizing constants |
| Discrepancy F | Possible scale: 2L/n + parameter-independent offset |
| Total observed information | H_L = (n/2) H_F |

Lavaan's `lav_model_objective_fiml` (`R/lav_objective.R:174`) evaluates
-2 log likelihood/n without constants and optionally subtracts an unrestricted
h1 offset. The model objective subsequently applies the ML factor 1/2
(`R/lav_model_objective.R:432`). Its information is in
per-observation units; `R/lav_model_vcov.R:879` divides the inverted matrix by n.
The study instead directly inverts the Hessian of total NLL. These conventions
agree only when the factors are carried through consistently.

Do not compare optimized discrepancies across different row masks, or call
them absolute log likelihoods. An h1 offset is unnecessary for fitting H0,
although saturated fits and fit indices are a separate reporting problem.
The [official estimator documentation](https://lavaan.ugent.be/tutorial/est.html)
also distinguishes normal-ML N scaling from Wishart N-1 scaling.

## 3. Reuse RAM derivatives; replace the data-side score

For parameter theta_k, restrict existing implied-mean and implied-covariance
derivatives to O_g. With W_g = V_g^-1, the pattern contribution is

```text
dL/dtheta_k = sum_g n_g {
  (1/2) tr[(W_g - W_g T_g W_g) dV_g/dtheta_k]
  - (dmu_g/dtheta_k)' W_g d_g
}.
```

Lavaan accumulates mean and covariance scores in
`R/lav_mvnorm_missing.R:403` and `:471`, then maps them to model coordinates
through its model-gradient machinery. medfit's reusable interfaces are
[`.sem_dsigma`](../../../R/sem-ml.R) and `.sem_dmu`; the new piece is the
pattern-specific weighting and summation. Cached data statistics remain fixed
throughout optimization; implied moments and block factorizations change.

The follow-up checks this algebra at fitted and perturbed points in complete,
nonmonotone-MCAR and observed-X-MAR datasets. Maximum gradient discrepancy is
3.44e-8 under the recorded relative metric, below the fixed 1e-6 probe limit.
The mapping derivatives in these probes use numerical differentiation; they
do **not** test medfit's analytic RAM derivatives. The first probe attempt used
parameter-relative steps near a nearly zero coordinate and missed that limit.
Centering finite-difference perturbations at zero fixed the step selection;
the acceptance limit was unchanged.

## 4. Observed and expected information are different designs

For a nonlinear mapping eta(theta) = (mu, vech Sigma), observed information obeys

```text
H_theta = D' H_eta D + sum_j (dL/deta_j) H_theta(eta_j).
```

At a structural optimum, dL/dtheta = 0 does not imply every dL/deta_j = 0.
Thus dropping the second term is unsafe even at fitted overidentified models.
The six probes find maximum-entry relative discrepancies of 0.8–2.0% at the
fitted points and 7.9–9.5% at perturbed points when that term is omitted.
These are Hessian differences, not claimed SE-error percentages.

Lavaan's default single-level observed-Hessian path numerically differentiates
the model gradient using Richardson extrapolation
[`R/lav_model_hessian.R:15`](https://github.com/yrosseel/lavaan/blob/master/R/lav_model_hessian.R#L15),
then selects it through `lav_model_info_observed`
(`R/lav_model_information.R:396`). A distinct `h1` information option exists;
it must not be silently substituted for the full observed Hessian.

**Design choice:** first differentiate the full pattern analytic gradient,
with medfit's unit-aware steps and coordinate transport. Validate against a
direct total-NLL Hessian at multiple resolutions. Preserve covariance
diagnostics; never accept an invertible indefinite matrix as valid covariance.
Nonlinear active-constraint Lagrangian curvature, already present in
[R/sem-se.R](../../../R/sem-se.R), is a further term and remains out of scope.

For fixed missingness patterns under the model-based MCAR calculation,
expected information has contributions

```text
I_kl = sum_g n_g {
  (dmu_g/dtheta_k)' W_g (dmu_g/dtheta_l)
  + (1/2) tr[W_g dV_g/dtheta_k W_g dV_g/dtheta_l]
}.
```

This matches lavaan's expected-information matrices after named-coordinate and
total-N scaling transforms to within 9.79e-8 relative maximum-entry error in
the three tested cells. But `R/lav_mvnorm_missing.R:826` explicitly limits this
expected-information construction to MCAR usefulness. Agreement in the MAR
cell is only an algebra/software comparison: it does not validate that
inference under MAR. Missingness depending on observed outcomes changes the
distribution within selected patterns. Observed information should therefore
remain the initial target, consistent with lavaan's documented FIML default.

## 5. Optimizers, initialization and identification

Lavaan uses NLMINB by default (`R/lav_options.R:1080`), has parameter scaling
and alternative optimizers, and checks the optimizer-coordinate gradient after
success (`R/lav_model_estimate.R:1165`). These are distinct from proof of a
global optimum. medfit already uses scaled SLSQP, restarts and acceptance gates
([R/sem-optim.R](../../../R/sem-optim.R)); FIML alone supplies no evidence for
replacing that solver. First compare the same likelihood under existing SLSQP
and an independent optimizer. Any solver recommendation needs those results.

The current study requires at least ten complete rows for its regression-based
initializer. A production design must not confuse this harness limitation with
FIML identifiability. Lavaan estimates unrestricted missing-data moments using
EM (`R/lav_mvnorm_missing_h1.R:11`), initializing with marginal means and
diagonal variances. That offers a separate starting-value strategy, rather
than requiring EM for every structured fit. Its source warns about zero
covariance coverage; EM or positive definiteness cannot repair nonidentification.

The existing no-overlap fixture constructively demonstrates different paths
with equal observed likelihood. Add an identifiable *no-complete-row* fixture
before a native design GO. Coverage graphs are useful diagnostics, not a
complete identification certificate, particularly with constrained structure.

## 6. Fixed X is a policy and likelihood choice

Ordinary lavaan FIML deletes missing exogenous-X rows with fixed X, while
`ml.x` retains them (`R/lav_data.R:1128`). Its missing-data likelihood can
subtract the marginal observed-X likelihood pattern by pattern
(`R/lav_mvnorm_missing.R:135`). This is more subtle than simply setting a flag.
The [official version history](https://lavaan.ugent.be/history/dot6.html)
documents the separate `ml.x` behavior.

The study verifies complete-X structural estimate/SE agreement and ordinary
fixed-X row retention. It does not independently validate `ml.x`, multiple
exogenous variables with different masks, or conditional-X likelihood/SEs.
Explicit free X moments also make X modeled and invalidate a naive fixed-X
probe. These distinctions need explicit future API semantics and independent
conditional-density tests; preserve the present default until then.

## Options and next milestone

1. **Native pattern kernel, observed information, random X (recommended).**
   Reuses RAM derivatives and acceptance gates with a bounded API surface.
2. **Full fixed-X/`ml.x`, expected and robust inference immediately.** Defer:
   distinct policies and casewise-score integration are unvalidated.
3. **Lavaan fits through existing extraction support.** Practical existing
   route while native design proceeds; verify support for each desired
   downstream operation separately.

The next separately authorized milestone should produce a design/prototype
outside production, with the following go/no-go gates:

1. Recover all existing 30-cell likelihood, estimate, row-count and observed-SE
   agreements without changing thresholds; require named covariance entries,
   not only SE diagonals.
2. Validate actual RAM analytic gradients at multiple nonoptimum points and
   full observed Hessians at two resolutions, including overidentified models
   that catch omitted mapping curvature and wrong N/2 scaling.
3. Add identifiable no-complete-row data, singleton/high-pattern-count masks,
   large shifts/rescalings, near-singular implied blocks and constructive
   nonidentification. A valid initializer must not require complete cases.
4. Preserve original/retained/empty row ledgers and comparable likelihood
   domains. Audit resampling, logLik/AIC/BIC, profile and MBCO callers before
   allowing FIML objects into them; gate unsupported operations explicitly.
5. Keep weights, robust SEs, latent/categorical models, nonlinear constraints
   and broad fixed-X behavior unsupported until their independent gates exist.
   Do not treat a kernel test as downstream support.

NO-GO for integration if any unexplained mismatch remains, if valid patterns
are rejected solely because their sample covariance is singular, if no-complete-
row initialization fails, or if existing listwise/default behavior changes.
Technical design work can proceed now; product scope/adopter and production
implementation still need separate decisions. Nothing here blocks 0.16.

## Reproduction

From this worktree, run:

```sh
Rscript planning/studies/fiml-feasibility/numerical-probes.R /path/to/extracted/lavaan
```

The optional source root must be the inspected archive's `lavaan` directory.
Without that argument, only numerical probes run. Results are in
[numerical-probes.csv](numerical-probes.csv). Source comparison checks parsed
function bodies/formals, not environments or compiled dependencies. Expected-
information probes establish implementation agreement, not repeated-sampling
coverage. No simulation study or performance benchmark was run.
