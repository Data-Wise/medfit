# Next-release plan: additional FIML mediation models

**Status: planning only, 2026-11-01.** The maintainer requests more FIML models
in the next release, starting with covariates, parallel and serial mediation.
The target below is the existing 11-variant roadmap, not a guarantee that an
unadmitted model will ship. Version, date, implementation activation, admission
gates, timing pilots, statistical studies and release remain deferred. This
plan neither executes nor waives any gate and does not authorize a study.

**Source of truth:** `PLAN-FIML-inference-and-observed-models-2026-10-31.md`
defines the model registry, order, numerical and statistical gates. This plan
organizes the requested next-release target without changing those contracts.
Bounded FI-B1/FI-B2 source inference merged to `dev` via PR #379
(`0bd99134d61837c1b1efffddc01ef7bb3d739743`);
that is not statistical admission or a released feature. The preceding 0.16.0
release already shipped bounded simple-model FIML fitting.

## Target and limits

| Release target | Variants | Explicit scope |
| --- | ---: | --- |
| Simple mediation with covariates | 2 | One or two continuous covariates. |
| Two parallel mediators | 6 | Zero, one or two covariates, crossed with independent versus explicitly free correlated mediator residuals. |
| Two serial mediators | 3 | Zero, one or two covariates; independent disturbances and all prescribed forward shortcuts. |

All variants use independent observations and continuous recursive linear
Gaussian random-X models, free means and observed/model covariance. Every
covariate predicts each endogenous variable; exogenous variables have a fully
free joint Gaussian covariance, including when covariates are incomplete. The
direct X-to-Y edge may be free or fixed exactly zero. Parallel effects include
both indirect paths and their full covariance; serial totals include every
directed path and the declared shortcuts. An estimated zero is not an omitted
edge. Arbitrary topologies, categorical/latent/multilevel models, fixed-X FIML,
interactions, weights and general constraints require separately designed scope.

The 11 are model-family/shape variants; free versus exactly fixed-zero direct
path is a required within-variant axis, not 11 additional variants. Each
variant's complete admission stage must separately cover both direct-path
policies, methods, effects and prespecified cells, including fixed-zero
correctness; record results at that granularity. Do not infer one policy's
admission from the other or pool away a failure. The 22 policy combinations
are not 22 separately admitted stages under Q13.
For serial models, only the X-to-Y direct edge may be fixed at zero; the other
prescribed forward shortcuts remain present and free. An additional fixed or
absent shortcut is not covered by this registry.

The source-fit row-bootstrap and Gaussian parameter-draw methods remain distinct.
Existing callbacks, unsupported-input guards, empty-row treatment and strict
failed-refit withholding remain intact. Each variant needs its own validated
fitting/extraction and inference evidence and its own complete statistical
admission stage; a passing related variant does not admit it.

**Exposure and release boundary:** Implementation may exist privately or on a
non-release development branch while evidence is pending. Until a variant has
its own complete admission and explicit release-scope decision, its fitting,
extraction and both source-fit inference entry points must remain unavailable
through public APIs: maintain/refine explicit rejection guards or an equivalently
fail-closed registry. Current `.sem_fiml_model()` rejects unsupported topologies
and `.sem_fiml_extract()` restricts extraction to simple mediation; these are
present guards, not evidence that future generalized code is safely gated.
Before release, independently test every unadmitted topology and direct-path
policy at all public entry points; documentation, examples and version notes
must state only the admitted scope. Never ship an unadmitted variant as merely
labelled experimental. If disabling it cannot be shown, keep the change off the
release branch or revert the relevant activation and reverify the release tree.
The same release boundary applies to the already-merged simple-model inference:
before its stage-0 admission, both public source-fit interval methods must be
withheld from the release tree by an independently tested guard or excluded by
reverting the activation; do not claim a guard exists today. Static source
inspection at `0bd99134` shows `bootstrap_mediation()` dispatches a named
`source_fit` to `.bootstrap_fiml()`, which checks the bounded source, ledger,
method, effect and topology, but does not check statistical admission status.
This is a source inspection, not a runtime test. Stage-0 and expanded-model
fit/extraction/inference exposure must be checked separately, without blocking
already released bounded simple-model fitting. The release plan must explicitly
resolve the pending stage-0 exposure before a release candidate can proceed.

**Ordering of admission:** Q13's first complete stage is admission of existing
simple-model inference, covering both interval methods and the prespecified
effects and free/fixed-zero policies in
`PLAN-FIML-statistical-admission-2026-11-01.md`. It must be decided successfully
before any expanded variant's inference admission or release. Only then may
the 11 expanded variants be admitted in their own separately preregistered
stages. Stage-0 numerical implementation and its existing merged status do not
constitute admission. If stage 0 fails, is inconclusive or is deferred, do not
release stage-0 or expanded-model inference; keep unadmitted variants unavailable
and defer or separately decide a compliant release scope. These admissions,
their gates and studies are deferred.

## Dependencies and implementation slices

All boxes are future work. Owners are functional roles; actual people/agents,
worktrees, source revisions and resource caps must be named before activation.
`medfit-implementer` owns code and tests; `medfit-oracle-qa` owns independent
numeric verification; `medfit-docs` owns documentation; `medfit-gates` owns
required verification; the maintainer owns scope, authorization and admission.

### 0. Establish the bounded baseline and interfaces

- [ ] **Implementer:** Pin the current integration commit, map existing
  simple-model source, inference contracts and refusal paths, and record the
  retained-row, parameter naming and result invariants. Split any work into
  focused tasks before activation; preserve other worktrees and prior receipts.
- [ ] **Independent QA:** Review the exact variant registry and required
  per-variant evidence against the parent plan. Distinguish implemented,
  numerically checked, statistically admitted and released states.
- [ ] **Implementer:** Before any release candidate, have the maintainer choose
  the reviewed release treatment matching the actual stage-0 admission status.
  If pending, failed or inconclusive, use an independently verified fail-closed
  release guard or exclude/revert source-fit interval activation. If admitted,
  preserve the supported admitted route and verify its evidence and scope.
  Preserve shipped simple-model fitting and unrelated bootstrap paths. Align
  roxygen, help, NEWS and release documentation with the actual release tree.
  This task does not authorize implementation or release.
- [ ] **Independent QA and gates owner:** Before candidate preparation, pin and
  test the exact proposed candidate source. If stage 0 is pending, failed or
  inconclusive, verify both public `bootstrap_mediation(source_fit=)` methods
  refuse, and review public dispatch/accessors for bypasses. Verify scoped
  package-initiated work and error precedence from the guard design; pin and
  compare candidate and any separately authorized, variant-specific private
  study patch; keep such patches off release-bound branches. If stage 0 is
  admitted and explicitly in release scope, instead verify both methods work
  within that scope and the admitted-source evidence matches the candidate.
  For either path verify shipped fitting, unaffected bootstrap behavior,
  documentation and provenance. Block candidate preparation if the relevant
  evidence or maintainer decision is absent; a plan statement is not a guard.
- [ ] **Implementer and independent QA:** Review the proposed
  `PLAN-FIML-stage0-release-guard-2026-11-01.md` design before any separately
  authorized guard work. Failure to establish the selected treatment keeps
  stage-0 inference out of the candidate.
- **Acceptance/verification:** A reviewed contract and source/owner map exist;
  check existing tests and metadata without treating prior green checks as
  admission. Dependency: none beyond current merged baseline.

### 1. FI-G0: dimension-generic observed kernel

- [ ] **Implementer and independent QA, G0a:** Specify the dimension-generic
  internal contract and independent reference cases, starting with
  `R/sem-fiml.R` and focused tests. Record the existing X/M/Y behavior and
  refusals to preserve; do not activate a new public topology.
- [ ] **Implementer, G0b:** Generalize preparation, scaling and observed-mask
  handling in bounded changes. Preserve row identities, likelihood constants
  and original-scale Jacobians; independently compare observed-subvector
  likelihoods and transport against reference calculations.
- [ ] **Implementer, G0c:** Generalize parameter/variance transport, starts,
  evaluation and geometry in bounded changes, retaining numerical safeguards.
  Compare the existing model with the baseline before proceeding.
- [ ] **Implementer and independent QA, G0d:** Verify the existing public
  adapter and refusal boundary and complete the numerical checkpoint before
  FI-G1; generic internals alone expose no new topology.
- [ ] **Independent QA:** Plan rowwise Gaussian likelihood and derivative
  oracles, rank/identification and missing-mask checks, and old-model regression
  comparisons; exercise parameter transport and all-row/restart gates when later
  authorized. Include observed-information, constraints/Jacobian/Hessian and
  zero-product branch requirements from repository instructions.
- **Acceptance/verification:** Independent checks show old results/refusals are
  preserved and generic internals meet the parent numerical contract. FI-G0
  alone admits no additional public topology. Dependency: task 0's baseline and
  source/owner map and the parent FI-CKB checkpoint, including its explicitly
  unresolved statistical status. The release guard decision remains required
  for the candidate as specified in task 0; it is not a prerequisite for this
  planning work.

### 2. FI-G1: covariates

- [ ] **Implementer:** First add one-covariate fitting and extraction, then the
  two-covariate variant, with joint random-X covariance and complete
  covariate-to-endogenous paths. Keep support guards explicit.
- [ ] **Independent QA:** Compare raw-data FIML against matched lavaan and the
  independent likelihood oracle, with OpenMx supporting checks; test incomplete
  covariates, fixed-zero direct paths, mixed explicit/automatic covariances,
  unidentified masks and complete-data neutrality. Independently verify
  effect/covariance extraction and both inference methods per variant.
- **Acceptance/verification:** Each of two named variants satisfies its own
  numerical, failure, extraction and inference contracts; statistical admission
  remains a separate stage. Dependency: task 1.

### 3. FI-G2: parallel mediation

- [ ] **Implementer:** Add the two-mediator graph and independent residuals,
  then the explicitly free residual covariance; cross each with zero, one and
  two covariates. Preserve full covariance for the sum of indirect paths.
- [ ] **Independent QA:** Check the two products and their sum against an
  independently derived gradient and full oracle covariance; verify residual
  policy, fixed-zero direct paths and per-variant source-fit inference. Plant
  and detect the missing cross-path covariance defect.
- **Acceptance/verification:** Six named variants each pass their own numeric,
  failure and inference evidence; no survivor-only interval is accepted.
  Dependency: task 2 under the parent sequence.

### 4. FI-G3: serial mediation

- [ ] **Implementer:** Add the two-mediator serial graph, all mandated forward
  shortcuts and zero/one/two-covariate variants; enumerate every directed path
  for indirect and total effects and retain the complete covariance.
- [ ] **Independent QA:** Independently enumerate path products and gradients,
  compare fitting and extraction with matched oracles, and plant/detect an
  omitted-shortcut defect. Verify each variant's two inference methods and
  failures; correlated serial disturbances remain outside this scope.
- **Acceptance/verification:** Three named variants satisfy their own numeric,
  extraction, failure and inference evidence. Dependency: task 3.

### 5. Per-variant admission, documentation and release decision

- [ ] **Statistical design, independent QA and maintainer:** First complete the
  existing simple-model inference stage under its separate admission plan,
  following the agreed complete-stage rule and Q10–Q13. Its admission is a
  prerequisite for any expanded variant's inference admission and release;
  unresolved or failed stage 0 blocks those claims. All study, pilot and gate
  work requires later authorization and remains deferred now.
- [ ] **Statistical design and independent QA:** Only when separately authorized,
  preregister and review each variant's own cell grid, functional-gradient
  regularity classification, expected-record ledger, missingness assumptions,
  reference-power calculation, budget and seed allocation. Retain Q10–Q13,
  structural-zero decisions, complete-stage power and all failures. No timing
  pilot or study is authorized here.
  Draft the design first; pin and independently verify the variant-specific
  study source and environment before final preregistration and its review.
  Follow the separate pilot and confirmatory execution authorization sequence in
  `PLAN-FIML-stage0-release-guard-2026-11-01.md`.
- [ ] **Statistical design and independent QA:** For each later variant count
  the actual complete family across both direct-path policies, all quantities,
  methods, regimes and any structural-zero checks; compute its own Q12
  per-decision and complete-stage power, including justified treatment of
  nonstatistical requirements. The first-stage illustration is not a power
  result for any expanded variant and no later stage family size is fixed here.
- [ ] **Documentation owner:** After capabilities are accepted, align help/Rd,
  README, NEWS, syntax, examples, guides and site with actual admitted variants
  and limitations; render and inspect applicable outputs.
- [ ] **Gates owner:** When authorized, run applicable project numeric oracles,
  admission checks, full suite, lint, package check, coverage and release checks;
  record source revision, results, warnings and skipped checks. No check is
  treated as evidence of statistical admission beyond its stated scope.
- [ ] **Maintainer:** Decide each admission and the final release contents
  explicitly. A failed or incomplete variant stays unadmitted; do not weaken
  thresholds or combine failing cells to meet the target. A revised scope or
  budget requires a separate decision, and release requires separate authority.
- **Acceptance/verification:** Evidence and status agree for every claimed
  capability, all applicable release gates pass, and the maintainer approves
  final scope and release. Dependency: applicable implementation slices and
  separately authorized admission work.

## Checkpoints and risks

After FI-G0, verify unchanged simple-model behavior before activating any new
public topology. After each family, independently review its numerical evidence
before implementing the next family; statistical admission can remain pending
while later implementation is considered under separate authorization. An
earlier family's failed admission does not by itself prove a shared numerical
kernel is defective: investigate and resolve any shared defect, rerun affected
evidence and preserve guards for all unadmitted variants. If shared code cannot
be safely isolated and independently reverified, keep it off the release branch
or revert the affected activation. Reconcile documentation and release metadata
with the exact release tree, not the development state. Never use later-family
implementation as a substitute for an earlier family's admission. Retain each
variant's complete admission as a separate decision and obey the stage-0 order.

| Earlier-stage outcome | Effect on later stages |
| --- | --- |
| Stage 0 failed, inconclusive or deferred | No expanded-model inference admission or release; do not expose unadmitted inference. |
| A family has a localized statistical failure with no evidence of a shared defect | That variant remains unadmitted; later separately preregistered variants may be considered under Q13 and the implementation order, subject to maintainer and independent QA review. No result is inherited or pooled. |
| Evidence indicates a shared kernel, extraction, guard or inference defect | Suspend affected later admissions and release claims; repair or isolate the defect, independently rerun the affected numerical oracles and regressions on the exact revised source, then reassess each affected stage. |
| The evidence is incomplete or cannot distinguish local from shared failure | Treat affected decisions as unresolved until independent QA and the maintainer determine scope; retain release guards. |

Any finding that contradicts an established numerical oracle, exposes a shared
implementation defect, or invalidates source/record provenance triggers an
affected-scope investigation and rerun after correction. A statistical
nonpass alone does not establish a software defect; it never admits the failing
variant or automatically clears downstream stages.

The principal risks are model-identification failures with missing patterns,
incorrect covariance transport or omitted paths, expensive strict bootstrap
refits, and limited empirical coverage outside the frozen study cells. Plan
review and bounded implementation can proceed only under their own
authorizations; admission gates, timing pilots and statistical studies remain
deferred. If evidence or resources are insufficient, record the limitation and
defer the affected claim rather than implying the release target is achieved.
