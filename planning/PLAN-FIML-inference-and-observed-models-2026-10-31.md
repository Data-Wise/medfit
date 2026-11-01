# FIML inference and observed-model expansion: agreed scope and staged plan

Current checkpoint: 2026-11-01 MST. Planning PR #378 merged into dev at `5e845007`.
The maintainer has now authorized bounded FI-B1/FI-B2 local implementation and verification.
Code/tests owner: `medfit-implementer`; independent QA owner: `medfit-oracle-qa`.
The [active execution plan](PLAN-FIML-bounded-inference-implementation-2026-11-01.md) owns task state.
The [reviewed checklist](DECISION-FI-B0-existing-model-inference-2026-10-31.md) remains the bounded contract.
Statistical admission, simulation/timing pilots, expanded models and release remain deferred.
Implementation push/PR/merge requires separate authorization. Older execution-status wording below is historical;
it does not override this checkpoint, the active plan, or preserved Q10-Q13 statistical admission gates.

## 1. Decisions and release boundaries

Settled by the user:

- Finish inference for existing bounded FIML, starting with bootstrap intervals.
- Plan **both** ordinary case-resampling intervals and Gaussian parameter-draw
  intervals; name the procedures distinctly.
- Extend the existing bootstrap entry point through an explicit source-fit route,
  preserving current callbacks/positional calls. Withhold row-bootstrap intervals
  on any failed required replicate and retain the complete diagnostic record.
- Expand next to continuous observed-variable Gaussian models with covariates,
  parallel mediation and serial mediation, including correlated parallel
  mediator residuals and covariate combinations in the initial planned scope.
  Admission remains individually gated. Latent/categorical/multilevel and
  interaction models need separate design and admission.
- Q12: >=90% per-cell and >=80% complete-stage admission power at nominal
  reference coverage .95 / availability .98, with lower-performance sensitivity.
  The Q10 rejection floors remain unchanged; no high-power guarantee is made
  for every performance point above those floors.
- Q13: admission proceeds through separately preregistered complete stages:
  existing simple-model inference first, then each of the 11 variants. Preserve
  all variants in the roadmap; no pooling away failing cells or shipping an
  unadmitted variant.
- Performance priorities concern repeated fitting workflows. The separate
  eight-cell baseline remains 64 fits total; no bottleneck means stop optimization
  and reassess. That budget does not cover this future inference validation.
  The baseline is not a prerequisite for the inference design. An unaffordable
  inference timing pilot does not automatically reopen optimization: propose a
  separately authorized measured bottleneck task or defer/rebudget the study.

Proposed sequence: FI-B0 contract -> FI-B1 row bootstrap -> FI-B2 parameter draws ->
FI-G0 generic observed kernel -> FI-G1 covariates -> FI-G2 parallel -> FI-G3 serial.
Each admitted family subsequently gets the FI-B1/FI-B2 checks. A failure does not
authorize broadening methods or weakening the released numerical gates.
Robust SEs and likelihood-based inference are later designs, not implied by this
plan. Bootstrap percentiles do not create a calibrated product-null test.
No version is assigned: 0.16.1 would be confirmed fixes only; a future minor
release must deliver an accepted user-facing capability. The earlier 0.17/0.18
sequences were alternatives, not commitments or schedules.

## 2. Verified architecture and traps

| Current source | Consequence for design |
|---|---|
| `R/bootstrap.R:202-267` rejects FIML before dispatch/RNG | Add an explicit object-aware route; do not merely remove the guards. Existing complete-data callbacks and positional calls stay unchanged. |
| `R/bootstrap.R:374-460` predraws row indices, drops failed estimates and needs only ten survivors | Reuse deterministic draw ordering, but design an explicit FIML failure/evidence contract; ten survivors is not adequate inferential validation. |
| `R/bootstrap.R:283-355` draws from parameter MVN | This is a Monte Carlo/asymptotic interval, not a data-generating parametric bootstrap. Retain existing method strings for compatibility, label FIML output accurately. |
| `R/sem-fiml-interface.R:17-56,182-240` specializes fitting/extraction to simple X/M/Y | Admit richer fitting and richer extraction separately. Retaining full covariance and canonical path roles matters. |
| `R/sem-fiml.R:8-70,107-110,172-183,225` hardcodes dimensions/transport/variance steps/starts/scaling | Generalize the whole numerical preparation contract; deleting the three-variable validator is insufficient. |
| `R/sem-fiml.R:73-105,126-170`; `R/sem-ml.R` | Grouped observed likelihood, scores and RAM moment derivatives offer reusable components, subject to independent checks. |
| `R/sem-fiml.R:320-333` checks pattern geometry and observed information | Observation counts or a connected missingness graph cannot replace numerical identification/curvature gates. These remain local checks. |
| `R/classes.R:552-631` defines scalar BootstrapResult | Reuse compatibility where possible; explicitly design additive metadata for method/source/requested-successful-failed counts and per-replicate evidence. Do not fabricate successful counts. |

## 3. Proposed statistical and public API contract

### FI-B0: explicit source-aware inference

User-selected API direction (Q6): extend `bootstrap_mediation()` with an
optional trailing named source-fit argument rather than invent a second fitting
API. Freeze its exact name, conflict rules and callback semantics before coding.
Existing `statistic_fn(data)` nonparametric callbacks and
`statistic_fn(theta)` parameter-draw callbacks retain their contracts.
For the new source-fit route, an effect selector or parameter-vector functional
must be unambiguous; never silently feed a fit to a data callback. The validated
source `SEMFit` owns syntax, rows, settings and parameters. Extracted-object-only
support requires reconstructible validated source provenance and is not assumed.

Initial effect targets: unstandardized NIE, direct effect and total effect;
one scalar per result. Proportion mediated, standardized effects, arbitrary
cluster dependence and bootstrap p-values remain refused. All defaults outside
the explicit FIML route stay unchanged. Pin `confint()`/`tidy()` behavior and
exact object/result class propagation before exposing either method.

### FI-B1: ordinary row bootstrap

IID observed records, with ignorable missingness under the fitted joint Gaussian
model and the usual regularity conditions. Resample whole incomplete rows, not
observed cells or residuals. Preserve each row's missing mask and column roles;
do not impute or hold pattern frequencies fixed by stratification.

User-selected sampling frame (Q8): the source fit's retained nonempty model rows,
conditional on its retained sample size. Record that all-empty rows contributed
no likelihood and are excluded; do not claim unconditional empty-row-count
uncertainty. Each draw gets unique replicate-row IDs plus source-row provenance,
so repeated source rows count with multiplicity. Rebuild means/scales/pattern
summaries for each replicate; no full-data sufficient statistics may leak in.

Refit the identical original model with the accepted FIML solver/acceptance
protocol. No relaxed Hessian/rank checks, hidden retry-until-success, survivor
replacement, listwise fallback, or optimizer-default change. Warnings alone
need not mean failure: classify via canonical acceptance plus covariance/
functional availability and preserve all notices/conditions.

User-selected first failure rule (Q7): retain the entire requested
replicate ledger, but return no percentile interval if any required refit is
unresolved, invalid or nonfinite. A later explicitly conditional survivor policy
would require a separate design; an arbitrary allowable failure percentage is
not statistical justification. An all-success distribution uses explicitly
declared `stats::quantile(type = 7)` percentiles. Small B is a testing fixture,
not support for accurate tail quantiles. Report requested B, effective B, failed
IDs/reasons, confidence level, seed, method and the original point estimate.

### FI-B2: parameter-draw intervals

Draw canonical **free** original-coordinate parameters jointly from
`N(theta_hat, V_hat)` using the matched stored observed/model covariance.
Use the full covariance, including cross-path terms; do not independently draw
aliases or duplicate tied coordinates. Fixed structural zeros stay fixed.
Transform each draw with the central effect functional; do not refit or call
an optimizer. Call the result a Gaussian parameter-draw percentile interval.
Use `stats::quantile(type = 7)` for both methods; interpolation mutants must
exercise both branches, not only row-bootstrap intervals.

This distribution is an asymptotic approximation, not a sample of admissible
SEM models: nuisance variance draws can be negative without invalidating a
polynomial path functional. Do not reject/truncate such draws to produce a
different distribution. Invalid source covariance is refused; functionals
undefined on sampled parameters require an explicit unsupported-result rule.
Define the PSD factorization and its roundoff-only tolerance in FI-B0; never repair
a materially indefinite covariance silently. State Monte Carlo error separately
from sampling uncertainty. Existing complete-data RNG/result contracts persist.

### Nonregular inference is an explicit limit

At a*b with a=b=0 the first-order gradient vanishes. Both ordinary resampling and
Gaussian plug-in parameter draws require special scrutiny; neither is promoted
to uniformly calibrated inference or a product-null test. Test axis-null,
joint-null and local-to-null regimes, report limitations, and do not use estimated
distance from zero as an unvalidated automatic method selector. Adaptive/null-
restricted bootstrap, BCa/studentization, profile and MBCO are separate research
milestones. An interval implementation passing a numerical oracle is not a
coverage theorem under MAR or at singular points.

## 4. Observed-model admission matrix (proposed limits)

Common domain: independent observations; numeric continuous variables; recursive
linear Gaussian SEM; explicit random-X `fixed_x = FALSE`; free observed means;
observed/model covariance; no weights, products/interactions, factors,
nonlinear constraints, parameter ties, nonzero fixed slopes or user bounds.
Only the direct X-to-Y path may be structurally fixed zero in the initial
11-variant registry. Other absent edges are outside this first admission.
Incomplete exogenous covariates are modeled
jointly, not deleted by an inherited fixed-X policy. Joint Gaussian assumptions
on X/covariates must be explicit; categorical X is not admitted by numeric coding.

| Stage | First proposed family | New admission evidence |
|---|---|---|
| FI-G0 | Generic observed-variable kernel, old X/M/Y API only | Transport all means, covariance entries and path scales; classify variance coordinates from RAM maps; preserve old result/status/refusal contracts. No broader public acceptance yet. |
| FI-G1 | Simple mediation with one, then two continuous covariates | Verify the frozen all-covariates-predict-all-endogenous rule and joint exogenous covariance completion. Test mixed explicit/automatic covariance declarations. No auxiliary-only-variable shortcut. |
| FI-G2 | Two parallel mediators, with zero, one or two continuous covariates | Include both independent mediator residuals and one explicitly free mediator residual covariance as separately checked variants within the initial scope. Full path covariance and summed indirect effects must survive extraction. |
| FI-G3 | Two serial mediators, with zero, one or two continuous covariates | All declared forward shortcuts are included; total effect includes every directed X-to-Y path. Disturbances remain independent; correlated serial disturbances require a separate identification design. |

Q9 includes correlated residuals and covariate combinations initially; this does
not admit arbitrary numbers of variables or arbitrary residual graphs. The
bounded user-approved registry (Q11) has 11 variants: two simple-mediation covariate
variants, six parallel variants (three covariate counts x two residual policies),
and three serial variants. Every included covariate predicts every endogenous
variable; treatment/covariates have a fully free joint Gaussian covariance.
Parallel models include both X-to-mediator paths and both mediator-to-Y paths;
serial models include X-to-M1, X-to-M2, M1-to-M2, M1-to-Y and M2-to-Y.
The direct X-to-Y path is free or explicitly fixed zero. Missing shortcut edges are future named variants outside this registry,
not licenses to omit existing paths from effect calculations. Free coefficients
may estimate to zero; that is distinct from omitting/fixing an edge. Fewer-path
topologies need named checks before public support claims.
Do not enumerate all 2^p masks: process observed masks only, at most
min(n, 2^p - 1) nonempty patterns. Bound memory/evaluation cost, diagnose absent
variables and covariance-unidentified masks, and preserve row identities.

Latent means/scaling, Heywood rules, ordinal/generalized likelihoods, fixed-X
FIML with missing covariates, multilevel dependence, weights and arbitrary
constraints remain outside these stages. Later latent support needs its own
measurement-model and marker-invariance oracles; it is not unlocked by FI-G0.

## 5. Independent oracle and regression acceptance

### Numerical acceptance (implementation correctness)

1. **Fixed-parameter likelihood:** hand-constructed structural moments plus a
   rowwise observed-subvector Gaussian density independent of production RAM,
   grouping and scaling. Include constants, singleton/one-variable patterns,
   no-complete-case inputs and all-empty exclusions. On ordinary standardized
   fixtures require absolute NLL difference <1e-7; original-scale likelihood
   comparisons explicitly include the observed-cell Jacobian.
2. **Parameters/information:** explicitly matched lavaan raw-data FIML
   (`missing='ml', fixed.x=FALSE, meanstructure=TRUE`, observed information),
   independent numerical score/Hessian of the rowwise likelihood, and OpenMx
   supporting comparisons for each new model family. Require exact coefficient/
   covariance name sets before alignment. Standardized coefficient max error
   <1e-5; covariance max error normalized by reference marginal SD products
   <1e-3; discrepancy in total NLL <1e-7 at identical supplied parameters.
   Optimum-to-optimum likelihood tolerance is predeclared separately from the
   fixed-parameter identity and must account for optimizer stopping differences.
   Retain existing stricter gates on unchanged paths.
3. **Paired resamples:** predraw one exact index manifest, then independently fit
   medfit and lavaan to every same incomplete resample. Compare per-replicate
   parameters/effects/likelihood and classification before comparing quantiles.
   Different RNG engines or a similar final interval are not an oracle. Manual
   type-7 order-statistic interpolation checks interval construction; boot.ci's
   interpolation convention is not assumed identical.
4. **Parameter draws:** an independently constructed factor using the FI-B0-declared
   square-root convention and explicit supplied normal variates reproduces
   full-covariance draws and effect quantiles. Different valid square roots with
   the same normal variates need not produce identical draws; test those against
   covariance/distribution identities instead. Check
   covariance cross terms, canonical-name permutations, aliases and fixed-zero
   paths. Instrument optimizer/preparation entry points: zero extra refits.
5. **Metamorphic and bridge checks:** affine/permutation/statement-order
   invariance with parameter/covariance transport; complete-data lm or native
   bridge under matched likelihood conventions. For serial/parallel effects use
   hand-enumerated products/sums and a separately computed gradient times full
   oracle covariance; do not call the production effect builder in the oracle.
6. **Adversarial failures:** rank-loss resample, constant/absent variable, invalid
   information, solver disagreement, stale source ledger, wrong mask/row IDs,
   source mutation, unsupported topology, malformed callback, Inf/NaN return,
   invalid seed/confidence/B settings. Verify early guards precede RNG/workers,
   requested/success/failed accounting, source immutability and no added warnings
   on unchanged complete-data paths. Sequential/parallel index manifests and
   results agree under the same per-replicate protocol; Windows fallback is
   explicit, and core counts stay <=2 in checks.

Mandatory planted defects: complete-case resampling, reuse of original pattern
summaries, dropped duplicate rows, survivor-only CIs, diagonal-only parameter
covariance, alias double-drawing, wrong percentile interpolation, missing affine
Jacobian, omitted serial shortcut, and ignored parallel cross-path covariance.
Each must fail a named independent assertion. No benchmark or mutant is run
during this planning stage.

### Statistical acceptance (scope of interval claims)

Freeze a separate simulation manifest before outcome inspection. Include MCAR,
MAR depending on an always-observed covariate, regular nonzero indirect effects,
axis nulls, joint null and local-to-null cases; keep model specification and
missingness assumptions explicit. Summarize bias, empirical coverage/width,
failure probability, and Monte Carlo uncertainty separately for both methods.
Never count an unavailable interval as covered or silently drop its dataset.
Report unconditional availability plus coverage conditional on interval return.

**Retained user-selected screening targets (Q10):** for nominal 95% intervals,
one-sided 95% exact binomial lower bounds must be >=92.5% conditional coverage,
>=95% availability, and >=90% joint usable-and-covering probability, separately
by prespecified cell and method. Conditional coverage uses returned intervals;
availability and joint coverage use all attempted datasets. Zero returns cannot
pass. Single-path axis nulls with nonzero effect gradient are regular and must
meet these same gates; report both tail-miss frequencies. Local-to-joint-null
sequences and exact joint-null cases get distinct, frozen regime labels and
characterize limitations rather than inherit a uniform validity claim. For
expanded path-sum effects, classify regularity using the full functional gradient,
not by a simple-product label. Do not classify a cell using estimated paths.

The agreed M=500, B=999 row refits / 20,000 parameter draws are a **screening
proposal with inadequate multi-cell decision power**, not a release-clearance
manifest. Exact calculations in [the gate report](studies/fiml-inference-gates/report.md)
show that a truly 95%-covering method with all intervals returned passes the
coverage gate only 70.3875% of the time (473/500 successes required). At true
availability 98% and conditional coverage 95%, the probability of passing all
three gates is 64.6571% in the declared IID dataset model. Across six independent
such cells it is 7.3063%; independence across methods/cells is not assumed for
actual release decisions. This corrects Opus's approximate 75-80% figure.
An inconclusive screen is neither a numerical defect nor statistical admission.

**FI-B0 decision-design blocker:** before any FIML simulation outcomes, freeze
cell grid (sample sizes, effects, missingness and all-empty rates), regime labels,
methods/targets, seed allocation, and the exact decision rule. Calculate per-cell
and whole-manifest pass probabilities, accounting for shared numerators and
method/cell dependence or using an explicit conservative bound. Q12/Q13 now
require >=90% per-cell gate power and >=80% probability of admitting each
complete, separately preregistered stage under reference performance
(coverage .95, availability .98), accompanied by sensitivity scenarios at
coverage .93/.94/.96 and availability .97/.99. FI-B0 must distinguish the
unacceptable floors from reference performance and any indifference region.
Q12 selects power at the nominal reference, with lower-performance sensitivity
reported explicitly; those lower scenarios are not approved high-power targets.
Q13 makes a complete admission stage the family-wide decision unit, not one
all-model study. The entire 11-variant roadmap remains in scope. These choices
do not approve a particular sample size, resource budget or execution. Keep the
coverage/availability floors;
select a feasible M or a justified decision structure **before outcomes and with
explicit agreement**. No pooling away a failing model or automatically accepting
some inconclusive cells. If unaffordable, defer the statistical admission or
seek a pre-outcome scope/budget decision; do not weaken claims silently. The
current 11-model scope is preserved. Passing numerical fixtures alone cannot
remove this blocker or authorize an interval release.

The timing pilot must be specified and authorized separately. Its fixed cell
list/regime labels precede execution; use disjoint pilot seeds excluded from the
confirmatory study, fixed work counts and a CPU/wall-time cap. Pilot data may
inform resource feasibility only. Log failures transparently; never use them to
remove cells, relabel regimes, loosen acceptance, or silently change M/B. Any
new performance/feasibility concern is recorded as a pre-study amendment requiring
review; confirmatory seeds remain untouched. Retain/annotate timeouts; never use
only successful fits to estimate runtime. No confirmation by repeated optional
runs. This gate-probability calculation executes no FIML fits or simulations.

The retained-row target is conditional on nonempty retention; zero empty-row
likelihood alone is not a general missingness-validity proof. FI-B0 must supply
the ignorable-missingness/parameter-distinctness argument and a prespecified
non-negligible all-empty MCAR cell at fixed retained n, recording collected and
retained counts. Do not claim an unconditional empty-record-count target.
Under the strict refit rule, (1-q)^999 is a conditional illustration for IID
replicate failures at fixed dataset-specific q; marginal availability averages
this quantity across datasets, not the same formula applied to pooled q.
Report all failed attempts. User reseeding until a CI appears is retry-until-
success and must not be recommended as a remedy. No simulation is authorized.

## 6. Task index, dependencies and checkpoints

| Task | Acceptance (all required) | Verification | Depends on / likely files |
|---|---|---|---|
| FI-TRACK Tracking contract | Namespaced task IDs, pinned roadmap revision, explicit state/gate mapping and negative fixtures specified | Planning consistency check and independent review | Prerequisite to activation; no checker implementation authorized now |
| FI-B0 Contract | Reviewed short checklist fixes API, sampling/failure/accessor policy, factor/tolerances and bounded local verification ceiling. Statistical manifest/pilot/resource agreement deferred to admission; Q10-Q13 preserved | Read-only design review: no blocking findings; runtime validation pending | Ready for separate bounded implementation authorization and owner assignment; statistical admission unresolved |
| FI-B1 Row intervals | Same-model incomplete-row refits; complete failure ledger and chosen no-survivor rule; percentile/point-estimate oracle | Paired index manifest, mask/failure/RNG mutants, unchanged API tests | FI-B0; bootstrap.R and focused new tests, split metadata changes into a small preceding task if needed |
| FI-B2 Parameter intervals | Joint canonical MVN with full covariance; no refits; accurate method labels and fixed-zero handling | Independent factors/normal variates/quantiles; diagonal/alias mutants | FI-B0; bootstrap.R and focused tests; metadata shared with FI-B1 |
| FI-CKB | Independent numerical QA and preset statistical acceptance or explicitly unresolved status; complete-data neutrality | Separate QA role, admission checklist, relevant local suite | FI-B1/FI-B2; no broader model activation |
| FI-G0 Dimension-generic kernel | General scaling/preparation/starts verified; old X/M/Y behavior preserved; generic masks/rank gates checked | Rowwise likelihood/derivative/transport oracle, old protocol receipts | FI-CKB for execution order; sem-fiml.R, sem-fiml-interface.R, dedicated tests; split kernel/preparation/adapter work |
| FI-G1 Covariates | Exact Gaussian joint-X and covariance contract; fit/extraction oracle; each admitted combination has FI-B1/FI-B2 validation | lavaan + rowwise likelihood; supporting OpenMx; unidentified masks | FI-G0; adapter/kernel and family tests, then separate extraction task |
| FI-G2 Parallel | Explicit residual covariance policy; full path/effect covariance; admitted combinations bootstrapped | Independent path-sum gradient and paired oracle fits | FI-G1; family adapter/extraction/tests in separate slices |
| FI-G3 Serial | Explicit shortcut graph; every-path total effect; full covariance and bootstrap parity | Hand path enumeration, omitted-shortcut mutant, rowwise likelihood | FI-G2; family adapter/extraction/tests in separate slices |
| FI-CKG | Per-family admission registry; failures stay explicit; no implicit latent/fixed-X support | Independent QA, relevant native Jacobian/Hessian/all-row/restart gates, complete-data neutrality | Each family individually, not one all-or-nothing rewrite |
| FI-DOCS | Matching help/Rd/README/NEWS/site/refcard/cookbook support; executed minibook unit for methods/limits | Rforge docs/lint, actual rendered artifacts/link checks, visual inspection | Accepted source of each milestone; no unapproved manuscript rewrite |
| FI-FINAL | Full required suite/check/lint and numerical gates; >90% overall coverage plus critical-path coverage/evidence; exact warnings/skips recorded | medfit required local pipeline; independent review of final tested head | All admitted slices; no push/CI/release authorization implied |

These are milestone indices, not permission for an XL implementation task. Split
each family/kernel change into focused ~3-5-file tasks before activation.
Use implementer -> independent oracle QA -> local gates -> docs -> final gates,
with the orchestrator's failed-stage/retry stop rule when implementation is later
authorized. The completed 0.16 work is not reopened as an unbounded revalidation.
Hosted coverage stays main PRs/main pushes only; expensive hosted checks remain
release-only. Public versions/dates require a separate release scope.

### Progress tracking and roadmap reconciliation gate

User-requested addition: make progress reconciliation part of each milestone's
harness and local gates, rather than a separate recurring documentation audit.
This section specifies future work; it does not install or execute a checker.

- Maintain one evidence ledger keyed by the stable FI-B0/FI-B1/FI-B2/FI-G0/FI-G1/FI-G2/FI-G3 IDs
  and separately admitted model/method combinations. Each entry records its
  acceptance criteria, owner, current state, blockers, tested source revision,
  exact check command/configuration, outcome and evidence artifact. Keep
  numerical correctness, statistical acceptance and documentation evidence
  separate; a single percentage cannot stand in for them.
- Use branch-specific delivery states and a separate check-outcome field
  (pass/fail/inconclusive/not run). Include planned, in progress, blocked,
  locally verified, merged-dev, merged-main, released and reverted/withdrawn.
  Advancing a state requires its evidence; failed or inconclusive checks stay visible.
  Locally verified work must not appear as shipped support. Historical evidence
  remains attached to its tested revision; source changes require a documented
  relevance review and rerunning affected checks before renewed acceptance.
- At task start, read the current `planning/medfit-roadmap.md`, applicable scope
  and active plan. At each checkpoint and before PR preparation, reconcile the
  affected roadmap rows, scope claims, plan ledger and `.STATUS` against the
  evidence. Reread these files before editing to preserve concurrent updates.
  Activation requires the revised roadmap and this plan to be reviewed and
  integrated on the same execution base, or an explicit pinned snapshot agreed
  by the author. The [revised roadmap](medfit-roadmap.md) and this plan are now
  assembled together on the planning branch derived from `cc3fd887`.
  [The evidence index](studies/fiml-inference-gates/README.md) distinguishes original
  review payloads from this assembled revision. Verify repository-relative
  `planning/studies/fiml-inference-gates/revised-documents.sha256` from the repository root.
  Revised roadmap SHA-256: `8c4cc6212110b9f40bb0bf001f2e6a24c18b5d36128a400d5266b78d44a8f239`.
  This content pin is not a merge receipt or implementation authorization.
  Assembly is authorized; publication, implementation and activation are not.
- Add a bounded local consistency check to the future verification harness:
  require globally namespaced IDs (FI-B0..FI-B2, FI-G0..FI-G3, FI-CKB,
  FI-CKG, FI-DOCS, FI-FINAL and FI-TRACK), existing evidence anchors, explicit blockers for
  blocked tasks, and required gate results for every claimed completion state.
  Reject contradictions between the ledger and affected roadmap/scope rows,
  unsupported model/method combinations, and release claims without a verified
  release receipt. Check semantics as well as links in independent review;
  an existing artifact alone does not establish that it supports a claim.
- The checker diagnoses drift and fails the local planning/docs gate; it must
  not silently rewrite priorities, assign versions, close issues, or infer
  completion from optimizer success. Authors update the affected documents
  within the authorized task; external issue/PR changes and publication retain
  their separate authorization requirements. No new hosted job or recurring
  automation is required.

Acceptance for this addition: fixtures must catch a missing task/evidence
anchor, a failed gate marked complete, an old receipt claimed for changed source,
a locally verified or merged-dev feature labeled released, duplicate IDs
across roadmap/plan, missing independent review, unrecorded revert/withdrawal,
and a support-matrix mismatch.
A consistent unchanged ledger must pass. Record any allowed evidence reuse with
its rationale rather than forcing unrelated expensive checks. Split this small
tracking/checker task from statistical implementation; include its reconciliation
check at FI-CKB/FI-CKG, FI-DOCS and FI-FINAL. It tracks delivery
evidence, not a proof of inferential validity or automatic release clearance.

| Delivery state | Required evidence (not authorization) |
|---|---|
| Planned / in progress / blocked | Owner, accepted scope, current work/blockers; last check outcome remains visible |
| Locally verified | Named slice's numerical/regression/docs gates, independent oracle QA and code/design review as applicable, all tied to tested revision; statistical admission separate |
| Merged-dev | Locally verified receipt plus reviewed PR head, applicable live fast checks, merge SHA/target and ancestry; no shipped-support claim |
| Merged-main | Promotion review and required release/main checks plus main merge SHA/ancestry; a merge alone is not publication |
| Released | Merged-main receipt plus verified tag/release artifacts and matching public support/docs; deployment separately recorded |
| Reverted / withdrawn | Affected revision/claim, reason and reversal receipt; prior evidence retained as historical, current support withdrawn |

A source change invalidates affected acceptance evidence until relevance review;
statistical pass/fail/inconclusive is never inferred from delivery state. Release
and external actions still require separate authorization. IDs are qualified by
this plan, preventing collisions with categorical backlog B1/B2/B3 or Ext D.

## 7. Proposed bounded execution manifests (not run)

- Bootstrap numerical oracle: free/zero direct path x complete/MCAR/observed-X
  MAR = six source cells; 12 explicitly supplied resamples/cell per engine.
  This is 144 refits across two engines plus 12 source fits = 156 fit invocations;
  solver starts/polishes are additional work and recorded separately. Small B
  supports mechanics tests only. Unit mutants and no-refit parameter draws are
  separately counted. Any budget adjustment is declared before execution.
- New-family oracle: the approved 11-variant registry x complete/MCAR/MAR x two
  seeds x free/fixed-zero direct path =132 cells; medfit/lavaan =264 source-fit
  invocations. Supporting OpenMx, rejection cells, solver starts and FI-B1/FI-B2
  validation are additional, explicitly budgeted work. This matrix covers
  declared topologies only, not arbitrary graph variants or all missing masks.
- Screening targets and M/B proposal are retained, but exact power shows the
  decision design is not admission-ready. Full statistical manifest, total cost,
  timing-pilot cap and generic-kernel limits remain gated in FI-B0. No expensive
  run is hidden in a mandatory quick unit test.

## 8. Research sources and their limits

- [lavaan estimators, missing values and bootstrap](https://www.lavaan.ugent.be/tutorial/est.html):
  observed-information default with FIML, MLR for incomplete data and bootstrap
  interfaces. This documents a comparator, not medfit support or a proof.
- [lavaan history](https://www.lavaan.ugent.be/history/dot6.html): historical
  failed/nonadmissible bootstrap handling and FIML bootstrap bugs justify
  pinning comparator source/version and inspecting each replicate.
- [boot.ci](https://stat.ethz.ch/R-manual/R-devel/library/boot/help/boot.ci.html):
  method distinctions, interpolation and unreliable extreme-order-statistic
  warnings. Its interval definition is not silently substituted for type 7.
- [He, Song and Xu, adaptive bootstrap tests](https://pmc.ncbi.nlm.nih.gov/articles/PMC11090400/):
  ordinary product bootstrap has nonregular behavior around the joint null.
  The paper's proposed tests are not automatically a validated FIML extension.
- Existing package oracles: `tests/testthat/helper-fiml-oracle.R`,
  `test-sem-fiml-oracles.R`, `test-bootstrap-reproducibility.R`; existing design
  limits in `planning/SCOPE-0.16-FIML-2026-10-30.md`.

## 9. Grill frontier / unresolved decisions

- Q6 settled: explicit source-aware extension of the existing bootstrap entry point.
- Q7 settled: no CI on any failed required refit; complete diagnostics retained.
- Q8 settled: retained nonempty rows and fixed retained sample size;
  the alternative resamples original all-empty records and permits variable
  retained sample size. These target different sampling contracts.
- Q9 settled: include correlated parallel residuals and covariate/mediator
  combinations in the initial scope, each with its own admission evidence.
  Q11 confirms the exact bounded 11-variant registry above.
- Q10: thresholds and initial M/B proposal retained; exact gate calculations
  exposed insufficient decision power. A pre-outcome power/resource decision
  remains blocked in FI-B0 until a feasible stage-specific manifest/budget is
  reviewed. Q12 settles the operating-characteristic reference and power targets.
- Q11 settled: all 11 variants remain in scope, including correlated parallel
  residuals and 0-2 covariate combinations. No arbitrary serial disturbance graph.
- Q12 settled: >=90% per-cell and >=80% complete-stage power at coverage .95 /
  availability .98; lower-performance sensitivity is reported, not guaranteed.
- Q13 settled: existing-model inference first, then separately preregistered
  complete admission stages for each approved variant. No survivor-cell pooling.

Q8-Q13 answers were received on 2026-10-31. Revisions address Opus's inference
and roadmap findings without production edits or silent scope reduction. Exact
API/conflict/result behavior, a feasible study design meeting the agreed power
within each stage, resource agreement and the timing protocol remain FI-B0
prerequisites. Roadmap reconciliation ends here; these implementation-planning
items are deferred to a separately authorized next task, not more work in this
roadmap session. The revised contract must pass a
focused independent review before implementation authorization is considered.
No implementation, simulation, push, merge or publication is authorized.

Resolve current independent choices first, then recompute the frontier. The
human confirms shared understanding before this draft is activated. No completed
implementation, inferential coverage, performance gain or publication readiness
is claimed.

Independent read-only design review identified one P2 gap: conditional coverage
could pass despite almost no intervals being returned. The statistical contract
above now requires a separately frozen availability/failure criterion at intended
B, plus joint usable coverage. The review also clarified covariance-square-root
coupling for exact parameter-draw oracles. Neither review nor correction executed
fits or numerical acceptance checks.

## Roadmap-level handoff (2026-10-31 MDT)

The owning roadmap now has an ordered delivery table with accountable roles,
completion criteria and blockers. Q12/Q13 are recorded. Roadmap reconciliation
is complete locally; FI-B0 is the next bounded decision packet, not a research
campaign. No detailed API design, new calculation, experiment or implementation
is performed in this handoff. Publication and implementation remain separate
authorization gates.
