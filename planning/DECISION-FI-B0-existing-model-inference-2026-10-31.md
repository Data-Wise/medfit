# FI-B0 decision packet: existing-model FIML intervals

Date: 2026-10-31 MDT. Status: **draft for decisions and focused review**.
Local planning only; no implementation, experiment, timing pilot, or push authorized
by this packet. The implementation plan remains inactive. No release assigned.

## 1. Decision and boundaries

Recommend an additive source-fit route in `bootstrap_mediation()` for the released
three-variable continuous Gaussian random-X model X -> M -> Y, with the direct
path free or fixed to zero. Admit ordinary row-bootstrap percentile intervals
(FI-B1) and Gaussian parameter-draw percentile intervals (FI-B2) separately.
Both target unstandardized `nie`, `nde`, and `te`, one scalar per result.

The [paired plan](PLAN-FIML-inference-and-observed-models-2026-10-31.md)
and [roadmap](medfit-roadmap.md) retain the approved 11 future observed-model
variants. They are outside this packet's implementation and study budget.
Robust SEs, likelihood intervals, generative parametric bootstrap, BCa/studentized
intervals, p-values, standardized effects, proportion mediated, weights, clusters,
latent/categorical models, and custom source-route functionals remain deferred.
Existing supported complete-data routes remain supported without behavior changes.

**Settled:** retained-row sampling, withholding on any required failure, both
interval methods, explicit existing-API extension, the Q10 rejection floors, and
Q12-Q13 power targets/separate complete admission stages. **Proposed below:**
exact formals/result metadata, method-stage interpretation, statistical manifest,
numerical tolerances not already fixed, and resource caps. None is approved merely
because it appears in this draft.

## 2. API contract proposed for approval

Append exactly matched, named-only `source_fit = NULL` and `effect = NULL` after
`...`, preserving every existing formal and positional slot, including the
required first formal `statistic_fn`. Detect `missing(statistic_fn)` before
legacy callback validation when the explicit source-fit route is selected.

Illustrative new calls (design examples; currently unsupported):

```r
bootstrap_mediation(method = "nonparametric", source_fit = fit,
                    effect = "nie", n_boot = 999L, seed = 101L)
bootstrap_mediation(method = "parametric", source_fit = fit,
                    effect = "te", n_boot = 20000L, seed = 102L)
```

| Input | Proposed source-route contract |
|---|---|
| `source_fit` | Accepted, provenance-validated FIML `SEMFit`; stored original rows, model and settings are authoritative. Extracted mediation objects alone are insufficient. |
| `method` | Must be supplied explicitly: `nonparametric` means row bootstrap; `parametric` means Gaussian parameter draws. Refuse `plugin`. Preserve legacy default outside this route. |
| `effect` | Explicit exact `nie`, `nde`, or `te`; source-coordinate functional from the central effect builder. |
| Conflicts | Refuse supplied `statistic_fn` (including explicit NULL), non-NULL `data`, `mediation_data`, or `cluster`, and nonempty `...`. Refuse `effect` without a source fit. |
| Counts/level | Preserve existing validation/defaults; require positive integer B and a valid confidence level. Study counts below are evidence settings, not new global defaults. |
| Parallel/RNG | Preserve public controls/platform policy; predraw the same row indices or canonical normals before workers. Seeded sequential/parallel results and ledgers must agree, apart from timing. |
| Invalid input | Classed error before RNG use, workers, preparation, or optimizer entry. Never mutate the source fit. |

Legacy callbacks remain `statistic_fn(data)` for rows and `statistic_fn(theta)`
for parameter draws. Never reinterpret either as a fit callback. A default
`source_fit = NULL` follows the legacy route. These reserved named options must
be documented; test that existing positional and variadic calls remain valid.

### Result and accessor contract

Reuse `BootstrapResult`; propose one additive optional `inference` list property,
empty for legacy objects. Preserve existing properties and constructor calls.
Keep `method` values `nonparametric`/`parametric`; add accurate human-readable
labels in metadata/printing so parameter draws are not described as refits.

- `estimate`: original fitted functional, never the mean of replicates.
- `n_boot`: requested B; `boot_estimates`: length B in request order, NA at failures.
- `inference`: versioned schema, method label, target, source binding, sampling
  frame, retained/collected counts, seed/RNG settings, quantile type 7,
  requested/successful/failed counts, status, and complete per-replicate ledger.
- Ledger: replicate ID, source-row indices or normal-draw ID, canonical acceptance
  classification, effect availability, condition/reason, and refit protocol ID.
  Preserve all requested records after a failure; do not stop at the first one.
- Any required failed/nonfinite row result withholds both CI bounds. Printing,
  `confint()` at **every level**, and `tidy()` preserve withholding. A changed
  `confint(level=...)` must not reconstruct a survivor interval. `tidy()` reports
  NA distribution SD when withheld; an all-success SD is descriptive, not a
  robust SE. Existing tidy/glance columns retain their meanings; new diagnostics
  reside in metadata rather than changing legacy row/column contracts.
- Operational interruption is an incomplete run, never a successful interval;
  retain a checkpoint/partial ledger where feasible and mark unattempted IDs.

## 3. Sampling and covariance decisions

**Rows:** sample retained nonempty rows with replacement, holding retained N
fixed. Move whole incomplete records, preserve masks, assign unique replicate-row
IDs, and retain original-row provenance. Rebuild scaling, means and pattern
summaries per sample. Refit the identical model with the existing accepted FIML
protocol; no relaxed Hessian/rank gates, listwise fallback, replacement samples,
or retry-until-success. Warnings are recorded; acceptance comes from canonical
fit checks plus finite covariance/functional availability, not optimizer flags.
Any required failure withholds the interval, even if most samples succeeded.

**Parameter draws:** draw canonical free original-coordinate parameters jointly
from N(theta_hat, V_hat), with matched stored observed/model covariance. Exclude
duplicate aliases; retain fixed structural zeros. Use the central polynomial
functional without any refit. Negative nuisance-variance draws are not truncated:
these are parameter approximations, not generated admissible SEM models.
Any nonfinite draw/functional withholds the result and is recorded.

Proposed factor convention: order free names canonically; write V = D C D using
positive marginal SDs. Use the symmetric PSD root of C and factor F = D C^(1/2),
so F F' = V; supplied standard normals determine the exact draws. Refuse
nonfinite/asymmetric or materially indefinite V before drawing. Proposed
roundoff tolerance on C is `100 * .Machine$double.eps * q * max(1, max(abs(eigenvalues)))`;
only eigenvalues within that negative tolerance may be clipped to zero, with a
recorded diagnostic. Free coordinates with nonpositive marginal variance are
refused in this first route. This convention/tolerance needs focused numerical
review; no broad nearest-PSD repair is permitted.

Both branches use `stats::quantile(type = 7)` at equal-tail probabilities.
Report Monte Carlo error separately from sampling uncertainty; tiny testing B
never establishes accurate tail quantiles. Joint-null and local-to-null NIE
behavior is characterization, not uniformly calibrated product-null inference.

### Missingness and the retained-row target

Assume IID jointly Gaussian records, ignorable MAR with parameter distinctness,
positivity, and identified observed information. Missingness is not certified by
software. Conditional on retention, likelihood factors may be ignored only when
the retention normalization is independent of model parameters. A sufficient
bounded case is an all-empty MCAR selection independent of the complete record,
followed among retained records by the declared complete/MCAR/observed-X MAR
mechanism. The theta-free missingness/retention factors then leave the usual
observed-component likelihood. This does not justify arbitrary value-dependent
all-empty deletion or MNAR. Bootstrap inference conditions on retained N and
excludes uncertainty about the collected all-empty count. Review this argument
before closing B0-MISSING; test a non-negligible all-empty MCAR cell explicitly.

## 4. Acceptance: mechanics versus statistical admission

**Mechanical gates** precede statistical admission and cannot substitute for it.
Use the existing plan's six source cells: free/zero direct path crossed with
complete, MCAR, and observed-X MAR; 12 fixed paired resamples per cell/engine.
This means 12 source fits plus 144 resample fits = **156 fit invocations** across
medfit/lavaan, not 156 optimizer starts. Log starts/polishes separately.

| Gate | Required evidence before implementation is called verified |
|---|---|
| Independent likelihood | Hand rowwise Gaussian observed-component likelihood at supplied parameters; total NLL discrepancy <1e-7. Independent score/Hessian and exact parameter-name sets. |
| Paired fitting | Same supplied resample indices/masks in medfit and matched lavaan raw FIML, random X, means, observed information. Coefficient errors normalized to variable scales <1e-5; covariance errors normalized by reference marginal SD products <1e-3. |
| Optimum comparison | Proposal: total optimum NLL absolute difference <=1e-5 for these fixed fixtures; retain stricter existing gates. Disagreement triggers diagnosis, not silent tolerance changes. |
| Draw oracle | Independent factor and supplied normals, hand a*b / cp / cp+a*b, fixed-zero/alias/permutation checks, full covariance cross terms, zero additional optimizer calls. Different square roots tested via covariance identities rather than draw equality. |
| Interval oracle | Manual type-7 interpolation; both tails and alternate confidence levels; original point estimate. |
| Regression/defect checks | Missing-mask leakage, duplicate rows, failed fit/covariance/nonfinite effect, survivor filtering, diagonal covariance, alias duplication, RNG-before-validation, source mutation, sequential/parallel parity, withheld alternate-level CI. Each planted defect must be detected. |
| Existing contracts/docs | Legacy bootstrap/class/accessor tests unchanged; relevant native gates, package suite/check/lint and local docs checks. Explain assumptions, limits, accurate labels, runnable examples and failure output. |

No full package suite is required for this planning-only draft. Those gates apply
to a separately authorized implementation. Hosted coverage stays main PR/main
push only; expensive CI remains deferred to release/main integration.

### Statistical rejection floors (settled Q10)

For every preregistered regular cell, method, and target, let M be all generated
datasets, A those yielding intervals, and H those intervals covering the truth.
Use one-sided 95% exact Clopper-Pearson lower bounds, with zero successes giving
zero: conditional coverage H/A >= .925, availability A/M >= .95, and joint
availability-and-coverage H/M >= .90 **on the lower-bound scale**. A=0 fails.
Source-fit failures remain in M; do not discard difficult datasets. Define truth,
finite-interval eligibility and endpoint inclusion before execution.

Q12 requires >=90% per-comparison and >=80% complete-stage admission probability
at true conditional coverage .95 and availability .98, with sensitivity at
coverage .93/.94/.96 and availability .97/.99. These are operating-characteristic
references, not guarantees about actual performance. No pooled passing decision.
Q13 requires each separately preregistered stage's entire manifest to pass.

**Proposed decision unit:** each method's existing-model stage, with all three
targets included. This interprets FI-B1/FI-B2 separately; approve explicitly.
Do not claim the power bound for their combined family without a separate bound.

## 5. Candidate manifest and resource decision

This is a costed candidate, **not an approved executable manifest**:

- Retained N=500; direct cp=.2 free or structurally zero; paths
  (a,b)=(.3,.4), (0,.4), (.3,0); unit exogenous/disturbance variances and zero
  intercepts. Cross with complete, MCAR, and observed-X MAR: 18 data cells.
- Proposal for masks: X always observed; M and Y independently missing with
  probability .2 for MCAR or `plogis(-1.5 + .5 * X)` for observed-X MAR.
  These bounded evidence regimes do not restrict future valid missing-X use.
- Add two all-empty MCAR cells (one per direct-path setting, nonzero paths,
  retained MCAR): append 125 all-empty records to 500 retained records, randomize
  order, and record collected 625/retained 500. This conditions on counts.
- Three targets per data cell: **60 comparisons per method stage**. M=2000 per
  data cell, B=999 row resamples and 20,000 joint parameter draws per dataset;
  share a source fit/draw distribution across targets without claiming independence.
- Joint-null/local-to-null characterization is required separately. Its exact
  manifest, count and resource reserve are still unapproved; it must be frozen
  before execution and cannot be quietly omitted from eventual limitations.

Historical [exact-probability evidence](studies/fiml-inference-gates/report.md)
reports per-comparison power .998245 at M=2000 and the nominal reference, and a
conservative K=66 family lower bound approximately .88418. A stage with at most
60 comparisons can use that conservative envelope without assuming independence,
provided each comparison meets the reference assumptions. It does not establish
power for the combined two-method family. This draft reuses that calculation;
no new probability experiment was run. Lower-performance sensitivity remains
part of the pre-execution manifest review.

**Cost:** 20 * 2000 = 40,000 source fits plus 39,960,000 row refits = **40 million
native fit invocations**; 800 million joint parameter vectors. Targets share
these operations. Six-start solver work, independent comparisons, retries under
fixed protocol, characterization, storage and parallel overhead add cost.
There is currently **no demonstrated affordability and no full-run budget**.
Do not authorize this grid simply because its nominal power is adequate.

| Future phase | Proposed hard cap and authorization boundary |
|---|---|
| FI-B0 packet/review | Documents only now; no fits or statistical calculations. Focused independent read-only contract review next, if authorized. |
| Timing pilot | Separate authorization: six source cells above, one source plus two fixed row resamples per engine/cell = 36 total fit invocations; 20,000 draws per medfit source. Maximum 30 wall minutes, 60 CPU minutes, two workers, 4 GiB RAM. Stop on any cap. |
| Mechanical oracle matrix | Separate implementation/run authorization: 156 paired fit invocations; proposed ceiling two CPU hours, two workers, 4 GiB RAM. Failures/timeouts count; no discretionary extra fits under this ceiling. |
| Statistical admission | Not authorized. After pilot, report conservative total CPU/wall/storage estimates, including failures/timeouts and full solver work; obtain a fixed resource allocation and complete manifest before touching confirmatory seeds. No automatic cloud/Hopper/GitHub execution. |

Pilot seed namespace is disjoint from confirmation; freeze exact seed allocation,
fixture constants, execution versions and artifact locations before the pilot.
Record every attempt including timeouts; never estimate cost from successes only.
The pilot informs affordability, not cell selection or interval performance.
If the candidate is unaffordable, return for an explicit pre-outcome scope/budget
amendment or defer admission. Do not reduce M/B, weaken floors, omit failures,
change labels, or claim support based only on numerical fixtures. The separate
64-fit efficiency baseline is not reopened or made a dependency here.

## 6. Decisions still needed and progress ledger

| ID | Current state / closure evidence |
|---|---|
| B0-API | Proposed above; approve named-only route, scalar targets, conflicts and additive result metadata; focused compatibility review required. |
| B0-POLICY | User sampling/withholding choices preserved; review all accessor and interruption consequences. |
| B0-POWER | Q10/Q12 settled; approve separate method-stage family and verify its complete manifest against existing probability evidence. |
| B0-PILOT | Proposed work counts/caps only; separate run authorization and frozen seed/artifact manifest required. |
| B0-MISSING | Sufficient conditional-retention argument drafted; independent review outstanding. |
| B0-EMPTY | Candidate 20% collected all-empty MCAR cases specified; approve fixture. |
| B0-MANIFEST | Candidate costed, affordability unresolved; characterization manifest, exact seeds, resource agreement and focused review still block closure. |

FI-B0 remains **draft, not complete**. FI-B1/FI-B2 are not authorized. After review,
update the paired plan/roadmap ledger once with accepted decisions and evidence;
keep their reviewed historical snapshot intact until that reconciliation is
explicit. No version/date promise, model expansion, implementation or study run
follows automatically from approving this packet.

## Source anchors checked for this draft

- [Existing API and engines](../R/bootstrap.R): signature at line 202; parameter
  draws around 283 and row branch around 374; current FIML refusal is intentional.
- [Result validator](../R/classes.R): `BootstrapResult` around 552; requested
  distribution length and allowed method strings constrain additive design.
- [Base accessors](../R/methods-base.R): around 755-833; changed-level `confint()`
  currently recomputes quantiles, making withholding a cross-accessor contract.
- [Tidy/glance](../R/methods-tidy.R): around 590-640; distribution SD and existing
  columns must remain coherent with withheld results.
- [FIML validation/source binding](../R/sem-fiml-interface.R): accepted source,
  supported model/settings, canonical coordinates and original rows.
- [Central effects](../R/effect-se.R): simple `nie`, `nde`, `te` gradients around
  190-213. Independent tests must not reuse this implementation as their oracle.
