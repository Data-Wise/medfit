# FIML statistical admission: proposed work plan

**Status:** Proposed, planning only. Statistical admission, timing pilots, studies,
expanded-model implementation and release remain deferred. This document does
not authorize their execution. The maintainer owns scope, resources, approval and
admission decisions. Owners below are roles, not claims that a person has accepted.

**Baseline:** PR #379 merged into `dev` as `0bd99134d61837c1b1efffddc01ef7bb3d739743`.
Integration and numerical QA are not statistical admission.
The study source commit and dependency environment must be pinned anew and
independently verified before execution; any change after review requires review.

**Authority:** Preserve Q8–Q13 and the failure policy in
`planning/PLAN-FIML-inference-and-observed-models-2026-10-31.md` and the exact
calculations in `planning/studies/fiml-inference-gates/report.md`. This plan
organizes that contract; it does not change its thresholds or expand the API.

## Scope and decisions

The first stage concerns only the implemented, continuous Gaussian, random-X
simple mediation model, with a free or exactly zero direct path and scalar,
unstandardized NIE, NDE and TE. Compare the existing source-fit row bootstrap
and Gaussian parameter-draw intervals for prespecified quantities and cells.
The later two covariate, six parallel and three serial variants each require
their own implementation, independent numerical oracles, frozen study and
complete-stage decision. No stage inherits admission from another.

Assigned functional owners: Codex (this session) owns the proposed statistical
grid and deterministic design calculations; `medfit-implementer` owns study
tooling; `medfit-oracle-qa`, independent of the design author, owns review of
the design, calculations, tooling and results; `medfit-docs` owns status and
documentation reconciliation; `medfit-gates` owns execution and CI gate checks.
Davood, as maintainer, owns scope, budget, authorization and admission decisions.
These are accountable roles, not claims that later agents have run or accepted
work. Record the actual reviewer and independence before any approval.

The proposed first-stage grid and calculations are in
`planning/studies/fiml-admission-design/README.md`; they are not an approved
preregistration or authority to run a pilot or study. That proposal defines the
complete-stage decision and structural-zero correctness checks separately from
the Q10 regular-effect gates; the calculated regular-gate power alone does not
establish Q12 complete-stage power. Independent review and a complete-stage
power argument remain open. On 2026-11-01 the maintainer selected the Q10
availability gate plus exact-zero correctness for fixed-zero effects, a
provisional 98% availability/correctness/completeness reference, one complete
stage for both methods, observed-X study-claim limits, nonregular descriptive
characterization and deferral with review if unaffordable. These decisions do
not authorize a pilot, study or release; the assumptions and resulting
conditional bound still need independent QA.

## Ordered work and gates

### 1. Establish provenance and reconcile status

- [ ] **Implementation owner:** Verify the live `dev` commit, PR and checks;
  inventory relevant source, tests, dependencies and prior receipts. Propose a
  source fingerprint and reproducible environment, including R and package
  versions. Preserve unrelated work.
- [ ] **Documentation owner:** Reconcile the current checkpoint in the roadmap
  and inference plan with the merged receipt, keeping historical failures and
  deviations visible and statistical admission deferred.
- [ ] **Independent QA:** Check that the fingerprint identifies the actual
  source used and that implemented scope, numerical evidence and outstanding
  statistical claims are accurately distinguished.

**Gate:** Named owners and a reviewed baseline exist. A changed source or
environment reopens the affected review; a merged PR is not a study result.

### 2. Specify the scientific design and expected records

- [ ] **Statistical design owner:** Write the aims, data-generating mechanisms,
  estimands, methods and performance measures. Freeze each proposed cell's
  parameters, sample size, effect and true regime; include nonzero effects,
  regular single-axis nulls, exact joint nulls and local-to-joint-null cases.
  Classify by the true functional gradient, never estimated paths. Joint-null
  and local-to-joint-null cases characterize limitations separately and do not
  imply uniform validity.
- [ ] Prespecify MCAR and observed-covariate MAR mechanisms and rates. State
  when the MAR covariate is always observed. Include a separate non-negligible
  all-empty MCAR cell, fixed retained sample size and both collected and retained
  counts. Specify positivity, identified information, ignorable missingness,
  parameter distinctness and parameter-independent retention normalization;
  explain why the retained-row conditional target is appropriate. Do not claim
  validity for arbitrary value-dependent deletion or MNAR.
- [ ] Specify all effect/method/cell combinations, attempted dataset counts
  `M`, row-refit count `B`, parameter-draw count, truth values, random-number
  streams and permitted reuse. Freeze separate pilot and confirmatory seeds.
  Include a complete expected-record ledger, including failed and timed-out
  attempts, nested refits and requested/usable draw counts. Freeze keys,
  statuses, denominators, identity fields and the failure-reporting policy.
- [ ] **Independent QA:** Check the generation mechanism, truth, regularity,
  retention argument and ledger against the implementation and independent
  calculations. Challenge whether all required regimes and combinations are
  present and whether missing records or duplicate keys can be detected.

**Gate:** A complete proposed manifest and expected-record contract exist;
unresolved scientific assumptions or unspecified cells block approval.

### 3. Determine decision power and feasibility before outcomes

- [ ] **Statistical design owner:** For each regular cell, method and quantity,
  retain all three nominal 95% interval gates, each based on a one-sided exact
  95% binomial lower bound: conditional coverage >= 92.5% among returned
  intervals; availability >= 95% among attempted datasets; and usable-and-covering
  probability >= 90% among attempted datasets. Zero returned intervals cannot
  pass. Do not pool away failures or count unavailable intervals as covered.
- [ ] Calculate the joint probability of passing these linked gates, with the
  shared success counts represented correctly. At conditional coverage .95 and
  availability .98, require >= 90% per-cell power and >= 80% simultaneous power
  for the complete first stage. Model dependence between methods/cells with
  justification or use a valid conservative bound. Report sensitivities at
  coverage .93, .94 and .96 and availability .97 and .99; these sensitivities
  are not additional high-power guarantees. Distinguish reference performance,
  rejection floors and any proposed indifference region.
- [ ] **Independent QA:** Independently reproduce exact calculations, counts,
  family size and any bound. Record assumptions and check boundary cases. These
  deterministic calculations do not require FIML simulations.
- [ ] **Statistical design owner and maintainer:** Propose `M`, `B`, draws,
  cell count and an explicit resource envelope, including optimizer restarts,
  failures and all requested methods. The historical `M=500`, `B=999`, 20,000
  draws is a screening proposal, not an approved design; its linked-gate power
  is about 64.66% per cell at the reference. `M=2000` and a 66-cell bound are
  illustrative, not an approved grid or proof for the eventual manifest.

**Gate:** Independent review establishes the Q12 targets for the exact frozen
stage and the maintainer agrees to a feasible design and budget before any
FIML simulation outcomes. If not feasible, stop and propose a separately
reviewed scope, budget or decision-design amendment; do not relax floors or
silently select cells.

### 4. Prepare and validate study machinery

- [ ] **Implementation owner:** Specify and, when authorized, build the runner,
  result schema, immutable manifest and expected-record ledger. Record run and
  source identity, seed, cell, dataset, method, quantity, true value, estimate,
  interval, requested/usable draws, diagnostics, failure reason and elapsed
  time. Preserve all attempted fits, including failures and timeouts.
- [ ] **Independent QA:** Verify source fingerprints independently and test
  expected versus observed keys, duplicates, missing/unexpected records,
  nonfinite successes, failed refits, zero returns, mismatched counts, seeds
  and timeouts. Use controlled fixtures and planted defects. The validator must
  distinguish incomplete output from complete output containing documented
  failures; failed attempts remain in the appropriate denominators.
- [ ] Check deterministic, independently calculated examples of the three
  acceptance bounds and summaries. A partial run may support diagnosis only;
  it cannot receive a final acceptance decision. Record validation evidence.

**Gate:** Reviewed tooling and independently verified provenance and completeness
checks pass before a pilot or confirmatory run. Tool validation is not admission.

### 5. Freeze and separately authorize a bounded timing pilot

- [ ] **Statistical design owner:** Prespecify the representative fixed cell
  and regime list, exact work counts, disjoint pilot seeds, workers, CPU and
  wall-time caps, timeout handling, stop conditions and retained logs. Confirm
  that pilot seeds cannot enter the confirmatory ledger.
- [ ] **Independent QA and maintainer:** Review the pilot manifest and budget;
  obtain explicit authorization before execution. Capture all runtime and
  failures, including timeouts, rather than timing only successful fits.
- [ ] **Implementation owner:** If separately authorized, run the bounded pilot
  and provide the complete logs and resource estimate; **independent QA** checks
  completeness and feasibility against the approved caps.

**Gate:** The pilot informs resource feasibility only. It cannot remove cells,
relabel regimes, change gates, or silently change `M`/`B`. If unaffordable or
unexpected, stop; any redesign or bottleneck investigation needs review and
separate authorization. An unrelated 64-fit efficiency baseline is neither a
prerequisite nor inference-validation evidence.

### 6. Preregister and authorize the confirmatory stage

- [ ] **Statistical design owner:** Freeze the final manifest, complete expected
  ledger, source/environment fingerprint, analytical power evidence, seed
  allocation, failure and timeout policy, formulas, reports and stopping rules.
  Retain immutable, independently checked receipts and checksums.
- [ ] **Independent QA:** Reconcile the final manifest with all prior decisions,
  the pilot's limited role, Q8–Q13 and the exact stage family. Check that no
  pilot information selected favorable outcomes or weakened the design.
- [ ] **Maintainer:** Review and approve the preregistration and budget; provide
  separate explicit authorization for the confirmatory study before execution.
  Record approver, date, scope and source. An amendment requires review before
  affected outcomes are observed; preserve the original and rationale.

**Gate:** All preceding gates and explicit study authorization are required.
No optional reruns, reseeding until an interval appears, or post-outcome changes
to the family, labels, thresholds or denominators.

### 7. Execute, audit, and decide admission

- [ ] **Implementation owner:** Only after authorization, execute the frozen
  stage within its resource limits; retain every attempted dataset, requested
  draw/refit, diagnostic and timeout. Stop and record deviations under the
  preregistered policy; do not silently retry or replace failures.
- [ ] **Independent QA:** Verify source identity, complete and unique expected
  records, seeds and statuses before analysis. For each regular cell and method,
  calculate the three exact lower bounds and pass/fail decisions. Report bias,
  interval width, both tail misses, conditional coverage, availability, joint
  usable-and-covering probability, failure probabilities and Monte Carlo
  uncertainty with explicit denominators. Report nonregular regimes separately.
  Strict failed required refits withhold the interval. Dataset-level failures
  matter: `(1-q)^B` is an IID conditional illustration, while marginal
  availability averages over dataset-specific failure probabilities.
- [ ] **Maintainer with independent QA:** Review the complete stage against the
  frozen criteria and issue an explicit admission, failure or inconclusive
  decision with limitations and evidence. A failed or incomplete cell cannot be
  hidden by aggregation. Statistical admission alone does not authorize release,
  broader model claims or changes to public defaults.

### 8. Subsequent model stages and release

- [ ] **Maintainer and independent QA:** Under Q13, successful complete-stage
  admission of existing simple-model inference is required before admission or
  release of expanded-model inference. If this first stage is failed,
  inconclusive or deferred, withhold stage-0 and expanded-model source-fit
  intervals from the release tree; keep unadmitted variants unavailable.
  Separately decide any compliant release scope. Already shipped bounded
  simple-model fitting is not withdrawn by this planning rule.
- [ ] **Maintainer:** Order all eleven later variants and assign owners without
  assuming their priority or approval today. Each requires its own separately
  authorized numerical implementation, tests, independent oracles, frozen
  stage, power/resource review, pilot if needed, study authorization and
  independent admission decision. Use the full functional gradient for path sums.
- [ ] For each later variant, freeze its actual family including both free and
  fixed-zero direct-path policies, effects, methods and relevant structural-zero
  checks, then establish its own complete-stage Q12 power. The first-stage
  228-regular/60-structural illustration already includes both policies and is
  not a transferable family size or power guarantee for expanded models.
- [ ] **Release owner:** After the relevant admission decision, separately review
  documentation, limitations, project holds, release checks and authorization.
  Preserve any remaining holds; no automatic release follows a green study.

## Open inputs before approval

Named owners; exact grid and stage family; fixed values for `M`, `B`, draws and
sample sizes; the missingness and retention specifications; justified dependence
or a conservative stage bound; pilot and full-study resource caps; run and
failure policies; pinned source/environment; and explicit approval receipts.
Do not infer approval of these values from illustrative calculations.
