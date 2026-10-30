# Bounded FIML integration design

> Release-scope update (2026-10-30): bounded FIML is complete and merged into dev
> through PR #364. It is now included in planned, unreleased 0.16; this supersedes
> earlier 0.16 exclusions in the dated record below. Model/support limits are
> unchanged. No release or expensive CI is authorized. See the
> [current scope decision](../../SCOPE-0.16-FIML-2026-10-30.md).

> Current integration status (2026-10-30): production integration was subsequently
> authorized under the [bounded plan](../../PLAN-FIML-bounded-integration-2026-10-29.md).
> Local implementation and corrective independent QA/pre-docs gates pass at `0f40b73f`
> (numerical source `625e7280`). Documentation is verified locally after the
> explicitly authorized resume; corrective FINAL gates PASS on `32a7b98`
> (1,765 tests; built-package check OK; 96.20767% overall coverage). Earlier
> prospective wording below records its historical stage, not the current authority.
> FIML remains separate from 0.16; no push, release or expensive CI is authorized.
> See the [argument analysis](argument-design-analysis.md) for new/existing settings.

Date: 2026-10-29. Status: proposed contract for review; design work authorized,
production implementation not authorized. Separate from 0.16, with no release
assignment. No production changes, push, or expensive CI.

Numerical baseline: `dee83cae`. The bounded prototype passes 42 fits, 13 edges,
126 derivative points and 126 likelihood identities; its P2 regressions pass
61 assertions. See the [repair evidence](p2-repair-report.md). These are numerical
prototype results, not evidence that the API and guards proposed below exist.

## 1. First adopter and user need

The first engineering adopter is **medfit's native simple-mediation workflow**:
`fit_sem()` followed by `extract_mediation()`, also reachable through
`fit_mediation(engine = "native")`. The medfit maintainer owns this integration.
The target user has three continuous observed variables, incomplete observations,
and wants unstandardized direct, indirect and total effects from one Gaussian
random-X model without deleting every incomplete row.

This is a concrete internal workflow, not a claim of a verified external user,
package commitment or scientific dataset. No change to probmed, RMediation or
mbco-lrt is part of the first milestone. Their adoption needs separate evidence
and authorization. Native MBCO is not the first adopter because its constrained
refits are outside the validated prototype.

The first vertical slice must demonstrate the workflow on the frozen no-complete-
row fixture and ordinary missingness fixtures. A successful isolated fitter alone
is insufficient: the extracted path aliases, full covariance, sample count and
likelihood provenance must survive to the supported effect calculations.

## 2. Proposed opt-in API and preserved defaults

**Design examples only: these calls are not supported by the current package.**

```r
fit <- fit_sem(
  "M ~ a*X
Y ~ b*M + cp*X",
  data = dat,
  missing = "fiml", fixed_x = FALSE, meanstructure = TRUE,
  information = "observed", se_type = "model"
)
mediation <- extract_mediation(fit, treatment = "X", mediator = "M")

mediation <- fit_mediation(
  model = "M ~ a*X
Y ~ b*M + cp*X", data = dat,
  treatment = "X", mediator = "M", engine = "native", se_type = "model",
  engine_args = list(missing = "fiml", fixed_x = FALSE,
                     meanstructure = TRUE, information = "observed")
)
```

Propose adding `missing = c("listwise", "fiml")` at the **end** of the
`fit_sem()` signature, after every existing argument, preserving positional
bindings. Native `engine_args` explicitly whitelists and forwards `missing`;
other engines keep their current argument validation and missing-data behavior.
The change to the exported signature needs explicit approval against the API
freeze before implementation; design authorization does not waive that policy.

| Setting | Existing/default path | Explicit FIML path |
| --- | --- | --- |
| `missing` omitted or `"listwise"` | Existing listwise pipeline and notices | Not selected automatically |
| `fixed_x` | Current default TRUE and current resolution rules | Caller must supply FALSE; omission, TRUE or a named subset errors before fitting |
| `meanstructure` | Current default TRUE; explicit NULL/FALSE behavior preserved | Require TRUE; NULL/FALSE errors, with free intercepts for all three variables |
| `information`, `se_type` | Existing observed/expected and model/sandwich choices | Only observed/model; reject other choices |
| `weights` or deprecated weight alias | Existing behavior preserved | Reject any supplied non-NULL weights, including unit weights |
| `n_starts` | Existing NULL-to-five behavior | NULL resolves to three starts per solver; explicit 3 allowed, other values rejected initially |
| `control` | Existing native optimizer controls | Initially only the empty list; reject unvalidated overrides |

Match the two missing-method strings exactly; reject unknown, NA, zero-length
and non-scalar user values rather than guessing or partially matching. Do not
introduce a global option, infer FIML from NA values, silently select random X,
or fall back to listwise deletion or another engine after failure. Explicit
FIML remains FIML on complete data and retains its supported-operation limits.

Old calls must preserve estimates, full covariance, class, parameter ordering,
row counts, warnings/messages, default resolution, statuses and downstream
behavior. No new FIML metadata is required on an existing listwise object.
Historical objects without a missing-method marker continue down the existing
listwise path. Preserve the [native-default decisions](../../specs/ADR-native-defaults-2026-10-24.md).

## 3. Exact model and data boundary

Accept only the completed RAM topology already tested: one group; exactly three
observed numeric continuous variables with arbitrary names mapped to X, M, Y;
X -> M -> Y with X -> Y either free or fixed exactly at zero; independent
Gaussian disturbances, positive residual variances, and free intercepts.
Validate topology after syntax completion, not by matching text or labels.
There are nine free parameters with a free direct path and eight with cp = 0.

No extra predictors, latent variables, factors/dummy expansion, product columns,
correlated disturbances, feedback, parameter ties, user bounds, user-fixed
means/variances, general constraints or `:=` parameters. The single zero-direct-
path restriction is a fixed RAM coefficient, not permission for other constraints.
Reject unsupported structure before numerical work; do not treat a parseable
native model as a supported FIML model. Extra data columns outside the model
are ignored and never used to select rows.

Permit NA in model variables. Reject infinities and invalid column types.
Require at least two observations and a positive finite marginal SD per variable;
these are input checks, not identification guarantees. Retain all rows with any
observed model variable; all-empty rows contribute zero likelihood and are
excluded with exact original-row indexing. Singleton pattern covariance is zero
and is never inverted. No complete-case initialization is allowed.

`n_obs`/`nobs()` count retained rows, not observed cells or complete rows.
`n_dropped` counts only all-empty model rows under FIML. The stored model data
have `n_obs` rows and may contain NA. Preserve original positional row IDs,
retained/empty sets, pattern membership, counts, and complete-row count in a
FIML record. Do not identify rows by potentially duplicated row names.

The likelihood assumes ignorable missingness under the stated Gaussian model
(e.g., MAR with the usual ignorability conditions). The finite MCAR/MAR fixtures
do not establish arbitrary-mechanism robustness or repeated-sampling coverage;
see the [technical record](technical-record.md#missingness-patterns-and-the-full-likelihood).

## 4. Likelihood, results and error contracts

Return the existing `SEMFit` interface, with ordered/named coefficients and full
covariance. Proposed FIML metadata in `internals$likelihood` records
`method = "fiml"`, `x_policy = "random"`, raw total NLL including constants,
retained N, free-parameter count, and row/pattern evidence. Diagnostics record
local rank/information checks and every solver/start attempt, including failures.
Do not expose the prototype's standardized coordinates as the public coefficients.

Use the validated full observed Hessian and affine covariance transport. Retain
three separate starts for each of SLSQP and nlminb, its own refinement for nlminb,
raw initial/final statuses and gate failures. Require accepted candidates from
both solvers, stationarity, objective agreement, local moment rank and observed
information. Preserve the frozen limits and both P2 regressions. Report groups,
actual solver calls and accepted candidates separately; neither a refinement nor
a failed attempt disappears from the counts. Local numerical acceptance is not
a global optimum, global identification or inference-coverage certificate.

**Existing complete-data fields cannot be repurposed.** `SEMFit@f` is the
complete-data discrepancy; it is not raw NLL, average NLL or a FIML chi-square.
For FIML, propose `f = NA_real_` and model-test `df = NA_real_`; store k = 8/9
separately as the free-parameter count. No saturated missing-data model is fitted
in this milestone. Structural moment-count df is not reported as a tested
missing-data model-test df.

This requires a dedicated, discriminated FIML validation path. In particular,
`.sem_outcome()` and `.sem_require_outcome()` currently rely on finite `f`:
a new FIML ledger schema must bind acceptance to the actual NLL, retained rows,
model, settings and selected attempt. It must not fabricate finite `f` or pass
through the existing complete-data acceptance gate. Existing version-1 ledgers,
status meanings, counts and complete-data validators remain unchanged. No broad
branch-certificate redesign is included; FIML has no general constraint search.

Pre-solver rejections carry no invented attempts. FIML failures carry a structured
condition with stage/reason, original parent condition and all completed attempt
records. Covariance failure is an error with diagnostic candidate evidence,
not an ordinary converged `SEMFit` with unavailable SEs. Any reuse of existing
covariance-error classes needs an audited compatible partial-result contract;
otherwise use a FIML-specific condition. Preserve original condition messages
and status values rather than reclassifying failures as successful fits.

## 5. Downstream support rules

These are **requirements for a future implementation**, not claims of current
support. Only operations listed as supported may consume a FIML fit normally.

| Operation | First-milestone contract | Required independent check or refusal |
| --- | --- | --- |
| `coef`, `vcov`, `nobs` | Support existing shapes/names; full covariance | Independent likelihood and lavaan, including missing X and no complete rows |
| `logLik` | Support -raw NLL, `df = k`, `nobs = retained N` | Full constants and affine offset; never reconstruct via `.sem_sample()` |
| AIC/BIC | Support -2 logLik + 2k / log(N)k | Compare to lavaan using identical random-X model/rows; no claim that unlike contexts are comparable |
| SEMFit print, summary, parameter tidy/Wald `confint` | Support coefficients/SEs, visibly identify FIML/random X and row counts | No complete-data discrepancy or chi-square leakage; unavailable model-test fields explicitly NA with reason |
| SEMFit glance/model-fit summaries | Keep established columns; FIML logLik/AIC/BIC allowed, chi-square/df/p-value NA | FIML-specific reason, not the existing product-model reason; no hidden saturated refit |
| `extract_mediation`, native `fit_mediation` wrapper | Support simple unstandardized two-way mediation only | a, b, cp aliases and every covariance alias agree with direct mapping; fixed cp has zero variance/covariance |
| `paths`, `nie`, `nde`, `te`, extracted-object `coef`/`vcov` | Support path values, NIE = ab, NDE = cp, TE = cp+ab; `coef(type = "paths"/"effects"/"all")` keeps current names/shapes and `vcov()` keeps the full alias covariance | Independently map values and delta gradients; getters return estimates, not covariance; preserve cov(a,b) and all cross terms |
| Extracted-object print/summary and tidy | Support existing simple-mediation paths/effects output, with FIML/random-X identification; tidy supports `type = "all"/"paths"/"effects"` | Preserve estimate/SE names and FIML context in the summary; tidy and normal CI must share the central effect-gradient builder |
| Extracted-object normal confidence intervals | Support `confint(parm = "paths"/"effects", method = "normal")` and tidy normal intervals on regular cases | Retain the NIE approximation warning but do not recommend deferred bootstrap; at a=b=0 retain point values and mark NIE inferential fields unavailable with reason |
| `med`, `quick` and extracted-object glance | Defer FIML support; no new fitting entry point | `med()` builds formulas and refits; it is not an effect getter. `quick()` and extracted glance call deferred `pm()`; explicitly refuse tagged FIML objects |
| Standardized effects, ratios/`pm`, other decompositions | Defer; reject FIML-specific requests | No pairwise/listwise moment substitution; no silent generic fallback |
| Bootstrap/plugin simulation and external consumers | Defer package-owned FIML routes; reject before RNG or worker launch | Test both original fit and extracted-object entry points; arbitrary user code/external packages are not controlled |
| Profiles, MBCO, `anova`, `compare_lr`, fit indices and prediction/residual APIs | Defer; reject FIML-specific requests before refits/statistics | Negative tests include complete-data FIML objects and mixed FIML/listwise objects |

The supported effect getters are `nie(x)`, `nde(x)` and `te(x)`, not `med(x)`.
`med()` remains the existing data/formula-building convenience fitter; its current
native-formula rejection remains in force for attempted FIML use. Do not teach
it as an accessor or expand it into a third FIML fitting route. `quick()` must
explicitly refuse a tagged FIML object rather than reaching deferred `pm()`.
`confint(method = "boot")` remains a refusal, without recommending a resampling
route unavailable for FIML. At the NIE origin, tidy SE/test/p-value/interval
fields and the NIE normal interval are unavailable with a reason; the algebraic
zero delta variance may be retained as diagnostic evidence, not regular inference.
Ordinary listwise messages remain unchanged. Known fixed cp = 0 is distinct from a vanishing indirect-effect delta gradient:
its zero covariance reflects a fixed parameter, not evidence of a precise NIE.

Before-RNG refusal is required when a tagged FIML object reaches an object-aware
package entry point. The generic nonparametric bootstrap accepts raw data and
an arbitrary callback; hidden FIML refits inside that callback cannot be detected
in advance. Such user callbacks remain outside this guarantee; there is no
requirement to inspect closures or prohibit general raw-data resampling.

Extraction must preserve a durable FIML discriminator and capability/row context.
The current `MediationData` has no such property: setting `source_package` to a
new spelling or attaching a fragile incidental attribute is insufficient.
Propose an internally registered `MediationData` subclass with a validated
`fit_context` property; the ordinary extractor constructs it, without a new
public constructor. It must inherit supported effect methods and retain
`source_package = "medfit"`. Existing extraction results remain unchanged.

Future implementation must verify S7 inheritance, serialization, copying and
all package-owned entry guards. Passing a FIML-derived base-class value onward
without provenance is not acceptable. Refusal rules cannot be enforced by a
flag on `SEMFit` alone once an extractor returns a different class. No claim
is made that arbitrary coercions or unaudited external consumers are guarded.

## 6. Prospective implementation acceptance

No implementation or new numerical execution is authorized by this design.
Before a future implementation is accepted:

1. Reproduce all 42/13/126 prototype gates, likelihood identities, independent
   optimizer gates and the 61 P2 assertions with unchanged limits; retain failures.
2. Exercise both public entry routes on the no-complete-row, ordinary missing-X,
   affine, free/zero-cp and rank-failure fixtures, with arbitrary variable names.
   Compare coefficients/full covariance, likelihood and counts independently.
3. Test exact opt-in validation, every unsupported input, all-empty rows and
   topology restrictions; no optimizer invocation for unsupported settings.
4. Verify old calls, positional calls, explicit listwise, stored old objects and
   both fixed-X defaults against a pre-feature baseline. Compare values, shapes,
   notices, statuses/counts and context; FIML failure must never alter that path.
5. After **both** fitting entry routes, call the actual public accessors:
   `paths(x)`, `nie(x)`, `nde(x)`, `te(x)`, `coef(x, type = "paths")`,
   `coef(x, type = "effects")`, `coef(x, type = "all")` and `vcov(x)`.
   Independently check a, b, cp, ab and cp+ab, including all names/aliases and
   fixed cp = 0. Over coordinates (a,b,cp), independently check gradients
   (b,a,0), (0,0,1), (b,a,1) and their g'Vg against tidy SEs and normal CIs;
   implementation uses the existing central effect-gradient builder, not a copy.
   Exercise extracted print/summary, tidy types all/paths/effects (including
   `conf_int = TRUE`) and `confint(parm = "paths"/"effects", method = "normal")`.
   Require matching SEs/intervals, retained provenance through serialization/copy,
   FIML-specific notices without bootstrap advice, and unavailable NIE inferential
   fields/interval at a=b=0 rather than an artificial precision claim. Other valid effects may
   remain available; fixed cp = 0 must not be confused with the NIE-origin case.
   Returning an untagged object is a failed acceptance.
6. For every deferred object-aware package operation, test an explicit refusal
   before refitting, RNG changes or worker launch. Include extracted objects,
   complete-data FIML and mixed-method comparisons. Assert `quick(x)`, `pm(x)`,
   extracted-object `glance(x)` and bootstrap/boot-CI routes refuse tagged FIML
   input; SEMFit glance must still return its explicitly supported fields.
   Attempted FIML use of
   `med()` must retain the current native-formula rejection, not refit or masquerade
   as `nie(x)`. Do not infer support by substituting `med()` for an effect getter.
   Opaque raw-data callbacks are excluded from the early-refusal guarantee.
   Existing listwise behavior must still pass unchanged.
7. Plant wrong-N covariance, complete-case retention, dropped covariance terms,
   lost extraction provenance and missing-method guard defects; each must fail
   its corresponding test. Check direct NLL rather than inventing discrepancy.
8. Run independent oracle QA, applicable local package/numerical gates, and docs
   consistency checks under a separately authorized implementation plan. Expensive
   hosted/platform CI remains deferred until release to main as instructed.

**GO now:** review this bounded design. **GO for implementation later:** explicit
implementation/API-change authorization and an approved, testable version of this
contract. **NO-GO:** expanding topology to make an adopter fit, silently changing
fixed-X/listwise defaults, synthesizing a complete-data discrepancy, losing
provenance, unexplained numerical misses or unsupported downstream fallthrough.

There is no automatic production implementation, release, dependency update,
external issue, PR or 0.16 blocker triggered by a design GO.

## 7. Decisions and rejected alternatives

- Add an explicit missing method to the existing entry point, with the new
  argument appended: avoids parallel fitting APIs and preserves positional calls.
  Automatic NA detection and a global switch were rejected because they change
  old calls. Exported-signature policy approval remains required.
- Require explicit random X: silently overriding current `fixed_x = TRUE` would
  change the statistical model. Conditional/fixed-X FIML is a separate design.
- Use observed information and full transport: expected/robust SE support has
  not been validated for this missing-data scope.
- Preserve `SEMFit` extraction shapes but add a FIML-specific likelihood/ledger
  path and extracted subclass: blindly reusing complete-data `f` and base objects
  would let inappropriate model tests and resampling run silently.
- Enable direct likelihood/AIC/BIC without saturated-model fitting; defer global
  fit statistics and constrained refits. A broader all-API implementation would
  exceed the tested prototype and the first adopter's needs.

## 8. Current source anchors and evidence

These are inspected local sources, not evidence that the proposal is implemented:

- [fit_sem and native wrapper](../../../R/fit-sem.R): current signatures, defaults,
  argument whitelist, and `.sem_as_semfit()` conversion.
- [complete-data pipeline](../../../R/sem-fit.R): listwise row selection and
  outcome/covariance handling.
- [SEMFit and MediationData](../../../R/classes.R): property and validation seams.
- [native methods](../../../R/methods-sem.R): complete-data logLik reconstruction,
  summary/model-test and glance behavior.
- [extraction seam](../../../R/extract-sem.R) and [shared extractor](../../../R/extract-lavaan.R):
  path aliases, covariance mapping and the returned mediation object.
- [effect getters](../../../R/generics-effects.R), [coefficient/CI methods](../../../R/methods-base.R),
  [central gradients](../../../R/effect-se.R), [tidy/glance](../../../R/methods-tidy.R)
  and [convenience fitters](../../../R/med.R): actual extracted-object public methods
  and deferred convenience operations.
- [outcome ledgers](../../../R/sem-outcomes.R): finite-discrepancy acceptance and
  context binding; [anova](../../../R/sem-anova.R), [MBCO](../../../R/sem-mbco.R),
  [reference comparisons](../../../R/compare-lr.R) and [bootstrap](../../../R/bootstrap.R):
  downstream paths that require FIML guards or dedicated implementations.
- [prototype protocol](prototype-protocol.md), [technical record](technical-record.md),
  [numerical memo](numerical-implementation-memo.md) and [repair receipt](p2-repair-validation.json):
  demonstrated numerical scope and limits.

## 9. Accessor-contract review resolution

The initial static review of `9e6d95d9` identified one P2: `med()` was incorrectly
listed as an effect accessor. This revision names the actual NIE/NDE/TE and
coefficient/covariance accessors, bounds extracted summaries/normal intervals,
and tests deferred convenience routes explicitly. The
[revised design review](integration-design-review.md) records closure and limits.
No production API or numerical code changed; implementation remains unauthorized.
