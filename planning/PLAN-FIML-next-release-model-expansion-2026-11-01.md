# Next-release plan: additional FIML mediation models

**Status: planning only, 2026-11-01.** The maintainer requests more FIML models
in the next release, starting with covariates, parallel and serial mediation.
The target below is the existing 14-variant roadmap (11 before the 2026-11-09 pure-chain amendment), not a guarantee that an
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

## Adversarial review, 2026-11-07 (static; no runtime checks, no study run)

Reviewed at `ecbfb19f` (dev) against `R/bootstrap.R`, `R/bootstrap-fiml.R`,
`DESCRIPTION`, `NEWS.md`, the stage-0 guard design and the roadmap board.
Findings that change this plan; each is folded into the sections named.

| # | Finding | Severity | Amendment |
| --- | --- | --- | --- |
| R1 | **Exposure exists on `dev` today, not only at release.** `bootstrap_mediation(source_fit=)` is public on `dev` with no admission check (no admission reference in `R/`), `NEWS.md` advertises it under "development version", and `DESCRIPTION` Version is still `0.16.0`, identical to the released tag. A source install of `dev` is indistinguishable from the tag, and the documented `pkgdown.yaml --ref dev` publish (root deploy while Version has no `.9000`) would present unadmitted intervals as site documentation. The plan treats this only as a pre-candidate task. | High | Task 0 gains a maintainer decision on interim treatment: land the stage-0 guard on `dev` now, or mark `dev` with a `.9000` version and bar dev-docs publishing until stage 0 resolves. Version bump and publishing stay release-engineering actions needing separate authorization. |
| R2 | **FI-G0 can invalidate stage-0 evidence.** G0b/G0c rewrite the shared `R/sem-fiml.R` kernel that a stage-0 study must pin. Stage-0 admission is evidence about an exact source; a refactor merged first leaves it unattached, and a refactor merged after must prove parity. The plan covers shared *defects* but not shared *changes*. | High | FI-G0 may not merge to `dev` before the stage-0 decision unless a pinned parity proof (old-model numerics and refusals bit-for-bit within the frozen tolerances) is recorded and the study source is re-pinned. Otherwise keep G0 on a feature branch. |
| R3 | **"Next release" is a hostage to deferred, unauthorized work.** Expanded variants need stage-0 admission, which needs a study that is unauthorized, unscheduled and unbudgeted. Nothing states what the next release contains if that does not happen. | Medium | Add the default release content below. The 11-variant target is conditional; a missing authorization or budget decision is itself the "defer" outcome, not an open loop. |
| R4 | **Guard tests arrive too late.** Refusal of every unadmitted topology and direct-path policy is verified "before release". G1 code lands on `dev` earlier, and `.sem_fiml_model()`/`.sem_fiml_extract()` guards are the only barrier. | Medium | A per-topology, per-policy refusal test at every public entry point (fit, extract, both source-fit methods) is a merge condition for each G1-G3 slice into `dev`, not only a release condition. |
| R5 | **Stale ownership text.** `CLAUDE.md` names `PLAN-0.16.0-GitHub-release` as the active plan though it is complete; `.STATUS` headers stop at 2026-10-30. | Low | Reconcile at the next checkpoint (FI-TRACK); not part of this change. |

**Grill decisions, 2026-11-07** (`GRILL-next-release-FIML-2026-11-07.md`): the goal
stays finishing FIML across the model set. Recorded intent, each still needing its own
activation: timing pilot and stage-0 preregistration draft first, with FI-G0 to FI-G3
built on a branch kept off `dev`; one pre-registered remediation round if stage 0 fails;
a hard compute and wall-clock cap set from the pilot with a mandatory decision on
overrun; the pilot runs locally under `medfit-implementer` and `medfit-oracle-qa` with a limit of
2 h total wall-clock and 15 min per cell (set 2026-11-07; start still needs activation).
Pilot result (2026-11-07, `studies/fiml-timing-pilot/REPORT.md`): a 999-refit call costs about
114 s. The maintainer set the stage-0 cap at 25 core-days with a smaller design (G6); at B=999 that
buys about 315 datasets per cell, per-decision power about 0.44, below the Q12 target, so the
design must be reworked (B, cell count) and independently reviewed before preregistration.
Superseded the same day (G7): stage 0 runs on UNM CARC Hopper with the full preregistered design and a
250 core-day cap; pinned Hopper environment and the maintainer's approval of job scripts come first.
G8 shares refits across NIE/NDE/TE with a study-only patch kept out of `R/` (about 208 core-days;
local parity 12/12 (originally 8/8), planted defect caught); it still needs a parity re-run in the pinned Hopper
environment and a preregistration that names it. The pilot's cells 11-12 were untimed and one call
was sleep-contaminated (85 valid units).
The default release content below governs what ships until a variant is admitted.

**Default release content (applies unless the maintainer decides otherwise):**
the next release ships no expanded FIML variant and no source-fit inference.
Stage-0 inference ships only if admitted and in scope; otherwise it is withheld
by the guard (R1). Shipped bounded simple-model fitting is unchanged. Expanded
variants ship only individually, after their own admission and a release-scope
decision. If the maintainer wants a dated release, they must either authorize
the stage-0 study with a budget, or accept this default.

## Hopper stage-0 queue (parked 2026-11-08 at the maintainer's request)

Stage-0 work is parked while FI-G1 starts. Open items, in order:
1. Maintainer reads and accepts OPEN-10 (retained-row estimand, .10 empty probability, 228/72/60 classification).
2. Hopper timing chunk (4 h debug partition): must project at most 200 core-days, confirm the 2026-11-01 snapshot, rerun parity at B = 40. Needs approval.
3. ~~PR #382 merges~~ done (`ba50f998`, 2026-11-08); the study pins the post-guard `dev` commit (at or after `ba50f998`, plus the final harness) and rebuilds the fingerprint.
4. Enumerate returned-interval status strings from the pinned source (P7); independent review of the whole draft (P3); freeze.
5. Submit the 6,000-task array only with the maintainer's approval of the exact job file.
Everything else in the preregistration is decided (OPEN-2, 4 to 9 closed; OPEN-7 QA-passed and accepted).

## FI-G1 slice 1 (one covariate), 2026-11-08

Branch `feature/fiml-g1-covariates` (worktree `~/.git-worktrees/medfit/feature-fiml-g1-covariates`), commit `e0374d92` on the FI-G0 tip, locally verified only (not pushed, no PR). Model `M ~ X + Z`, `Y ~ M + X + Z`, free X-Z covariance; vs lavaan raw FIML, an independent rowwise likelihood and closed-form complete-data checks; 4 planted defects caught; 20 unadmitted models refused. I reran: g1 13 tests/210, golden 17/738, sem-fiml 20/312, guard 4/11, all 0 failures. Not run: full suite, R CMD check, OpenMx, admission checklist, docs/NEWS (still say three variables). Maintainer decisions pending: both Y paths required; either exogenous variable may be treatment; covariate source-fit gets its own refusal.

## FI-G1 independent QA, 2026-11-08

QA (`medfit-oracle-qa`, own code, report in the session scratchpad `qa-g1/REPORT.md`) on branch `feature/fiml-g1-covariates` @ `7f61b813` (rebased on `origin/dev`, backup branch `backup/fiml-g1-pre-rebase`): PASS in all six areas. 90 lavaan cells (coef 4.8e-6, SE 1.4e-6, logLik 1e-9), 12 OpenMx cells, independent EM/Hessian check, delta-method SEs for every treatment, 49 of 49 unadmitted topologies refused (R4 evidence, guard on and open), edge cases, and 3-variable results `identical()` to `origin/dev` in 24 cells. 4 of 5 planted defects caught; the fifth is refused by another layer. Full suite on the rebased branch: 1932 tests, 11530 expectations, 0 failures. Not covered: `R CMD check`, OpenBLAS runner, admission checklist, statistical coverage. Not pushed, no PR.

## FI-G2 parallel, parity proof and PR #383, 2026-11-08

Slices 1 (independent residuals, `M1 ~~ 0*M2` required) and 2 (free label-less `M1 ~~ M2`) are on `feature/fiml-g1-covariates`. Independent QA PASS (lavaan 12 cells, OpenMx 3, OLS, hand SE of the indirect sum, 9 of 9 planted defects, refusals, near-boundary fails closed). R2 parity proof PASS: the stage-0 simple model is bit-identical to the pinned `ba50f998` on 72 of 72 datasets (reduced B, local BLAS, not Hopper). Decisions: delta Wald intervals stay available; extract refusals are classed (`medfit_error_fiml_extract_unsupported`); the parallel exact-origin NIE guard is fixed in the PR. Gates: new `fiml-ext` gate (65 rows), full suite 187 files / 12,388 expectations / 0 failed at tip `369b1533`, `R CMD check` 1 NOTE (version jump, same on dev). PR [#383](https://github.com/Data-Wise/medfit/pull/383) squash-merged into `dev` as `64c17b2e` on the maintainer's instruction (lint, pkgdown and risk-tier green on head `369b1533`); branch `feature/fiml-g1-covariates` kept. Slice 3-4 (parallel x covariates) is under way in worktree `feature-fiml-g2-covariates`, which needs a rebase onto the new dev. Freeze caveat: cut the Hopper harness commit on `ba50f998`, not on a later dev. Remaining: parallel x covariates (six variants), serial FI-G3, the Hopper queue above.

## FI-G2 slices 3-4 (parallel x covariates), merged 2026-11-09

PR [#384](https://github.com/Data-Wise/medfit/pull/384) squash-merged into `dev` as `c5389f6d` on the maintainer's yes (lint, pkgdown and risk-tier green on head `f704ab02`; one lint run failed on a Quarto download 504 and passed on rerun). Four new variants (1 or 2 covariates x `M1 ~~ 0*M2` or free `M1 ~~ M2`), 8 policy cells. Independent QA PASS on 9 items (lavaan 24 cells, OpenMx 4, 12 of 12 planted defects, parity with dev bit-identical). Full suite on the rebased tip: 188 files, 13,037 expectations, 0 failed. `fiml-ext` gate: 8 structures, 129 rows. Unverified: independent Hessian on 2 of 8 cells, OpenMx on 1 cell, no Hopper or OpenBLAS run. Remaining model structure: serial FI-G3. Parity caveat for the Hopper freeze still stands (cut the harness commit on `ba50f998`).

## Critical path and open decisions (2026-11-08)

Status: Hopper environment install running (46 packages at last check; the first attempt
installed nothing because a `#` inside quoted R code commented out `install.packages`, fixed at
`a92e8d4a`); three parallel tracks started in isolated worktrees (stage-0 preregistration draft,
FI-G0a/b contract and reference oracles on an unmerged branch cut from the guard branch tip,
FI-TRACK reconciliation, merged here at `f85ecee4`). Nothing is submitted to Hopper; no push, PR
or merge.

Critical path to the stage-0 study, in order (each step needs its own approval where marked):
1. Hopper environment: DONE 2026-11-08 (R 4.4.0 module, dated 2026-11-01 package snapshot, `pkgload`
   replacing `devtools` because `ragg` cannot build there, fingerprint pinned to `34a3e9cc`). Load test on
   Hopper passed: medfit 0.16.0 loads from the pinned source, a fit takes 0.6 s, the guard refuses. The
   fingerprint must be rebuilt at the final study commit at freeze (it pins one commit).
2. Re-run `parity-check.R` inside the pinned Hopper environment (QA gating item). Submitting it
   as a job needs your approval.
3. Time one real chunk on the 4-hour debug partition and check `MaxArraySize` (QA items 3d/3e);
   re-estimate the 187 to 208 core-day cost against the 250 cap. Needs your approval.
4. Preregistration draft -> independent review -> freeze. The unfrozen draft exists
   (`studies/fiml-stage0-hopper/PREREG-DRAFT.md`, merged 2026-11-08) with ten open decisions
   (OPEN-1 to OPEN-10: remediation method and trigger; per-study versus total core-day cap and a
   wall-clock cap; collection cap and cap-hit counting; `unattempted_budget` rows; action at cap
   breach; final M; complete-stage power argument; pinned study commit; R module and parity scope;
   retained-row/MAR and regularity classification), a 15-item reviewer checklist and 11 freeze
   prerequisites. Known gap: `check-complete.R` does not check seeds, `retained == n`, truth values,
   nonfinite or nonzero NDE successes, count consistency or `unattempted_budget` rows.
5. Submit the full 6,000-task array, only after step 4 and your approval of the exact job file.
6. Run `check-complete.R`; analyze gates; decide stage-0 admission (separate decision).

FI-G0 (generic kernel) proceeds in parallel but stays off `dev` until the stage-0 decision
(finding R2). Remediation if stage 0 fails is decided (G9: rerun only inconclusive failed cells on fresh seeds, one round,
no pooling; see the preregistration draft section 10). FI-G0a/b are done on the unmerged branch
`worktree-agent-a4f9ed5f1273b3b20` (spec plus oracle tests, 7/7 planted defects caught, no `R/` change).
Cap decided (G10, G11): 250 core-days per study (main and remediation separately), 7 days wall-clock
from the first task starting, queue wait excluded.
FI-G0 questions decided (G13 to G16): G0c/G0d may edit `R/sem-fiml.R` on a branch only, no merge to `dev`
before the stage-0 decision and parity proof; base is the guard-branch tip, rebased onto `dev` after the guard
merges; `NaN` stays missing (change decided separately); the two entry points are the two methods of
`bootstrap_mediation(source_fit=)`.
Open decisions for the maintainer: the all-empty-cell collection cap and the failure/denominator policy;
the FI-G0 branch base commit (currently the guard branch tip, an assumption); whether the guard
branch is pushed and merged to `dev` (it is local only).

## Target and limits

| Release target | Variants | Explicit scope |
| --- | ---: | --- |
| Simple mediation with covariates | 2 | One or two continuous covariates. |
| Two parallel mediators | 6 | Zero, one or two covariates, crossed with independent versus explicitly free correlated mediator residuals. |
| Two serial mediators | 6 | Zero, one or two covariates, crossed with two shortcut states: the saturated forward graph (X-to-M2 and M1-to-Y free) and the pure chain (X-to-M2 and M1-to-Y absent); independent disturbances written as zero covariances. |

All variants use independent observations and continuous recursive linear
Gaussian random-X models, free means and observed/model covariance. Every
covariate predicts each endogenous variable; exogenous variables have a fully
free joint Gaussian covariance, including when covariates are incomplete. The
direct X-to-Y edge may be free or fixed exactly zero. Parallel effects include
both indirect paths and their full covariance; serial totals include every
directed path and the declared shortcuts. An estimated zero is not an omitted
edge. Arbitrary topologies, categorical/latent/multilevel models, fixed-X FIML,
interactions, weights and general constraints require separately designed scope.

The 14 are model-family/shape variants; free versus exactly fixed-zero direct
path is a required within-variant axis, not 14 additional variants. Each
variant's complete admission stage must separately cover both direct-path
policies, methods, effects and prespecified cells, including fixed-zero
correctness; record results at that granularity. Do not infer one policy's
admission from the other or pool away a failure. The 28 policy combinations
are not 28 separately admitted stages under Q13.
For serial models two shortcut states are covered: both forward shortcuts
(X-to-M2, M1-to-Y) present and free, or both absent. Within either state only the
X-to-Y direct edge may be free or fixed exactly at zero. A single present
shortcut, a fixed or labeled shortcut, and any other fixed or absent edge are not
covered by this registry. Serial totals include every directed path of the
declared state; for the pure chain the total indirect effect equals the chain
indirect effect. (Amended 2026-11-09 per `planning/specs/SPEC-fiml-serial-FI-G3-2026-11-09.md` section 1.2, maintainer decision Q1.)

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
the 14 expanded variants be admitted in their own separately preregistered
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
- [x] **Maintainer (R1, 2026-11-07 review):** Decided 2026-11-07: guard on `dev`
  now. Implemented on branch `claude/restore-b0bd19` (not yet merged): public
  `source_fit` refused first with class `medfit_error_fiml_inference_unavailable`;
  `.fiml_source_inference_admitted()` returns `FALSE`; guard tests plus a planted
  defect (flip to `TRUE` fails 3 expectations, 2 errors); existing source-fit
  tests mock the binding. Flip only with a recorded stage-0 admission decision.
  Local evidence: guard, bootstrap-fiml, execution, sem-fiml, bootstrap,
  methods-base and docs/guide/refcard files pass; full suite, lint of the whole
  tree and PR not yet run.
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
- [x] **Implementer, G0c** (done 2026-11-08 on branch `worktree-agent-a4f9ed5f1273b3b20`, tip `56471d59`, not merged, not pushed): Generalize parameter/variance transport, starts,
  evaluation and geometry in bounded changes, retaining numerical safeguards.
  Compare the existing model with the baseline before proceeding.
- [x] **Implementer and independent QA, G0d** (done 2026-11-08, same branch; I reran the tests: golden 17/738, oracle 71/446, four-var 4/25, sem-fiml 20/312, sem-fiml-oracles 10/134, guard 4/11, bootstrap-fiml 17/131, 0 failures; 2 warnings in `test-sem-fiml-oracles.R` (free and zero patterns) not yet traced; full suite, lint on the branch and native-defaults/fixed_x regressions not run; golden snapshot predates the only `R/` edit, `R/sem-fiml.R`): Verify the existing public
  adapter and refusal boundary and complete the numerical checkpoint before
  FI-G1; generic internals alone expose no new topology.
- [ ] **Independent QA:** Plan rowwise Gaussian likelihood and derivative
  oracles, rank/identification and missing-mask checks, and old-model regression
  comparisons; exercise parameter transport and all-row/restart gates when later
  authorized. Include observed-information, constraints/Jacobian/Hessian and
  zero-product branch requirements from repository instructions.
- **Ordering constraint (R2):** G0 changes to `R/sem-fiml.R` stay off `dev`
  until the stage-0 decision, or until a pinned old-model parity proof exists
  and the stage-0 study source is re-pinned.
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
- **Merge condition (R4, applies to FI-G1 to FI-G3):** before a slice merges to
  `dev`, independent tests show every still-unadmitted topology and direct-path
  policy is refused at fit, extract and both source-fit entry points.
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

- [ ] **Implementer:** Add the two-mediator serial graph in both shortcut states
  (saturated and pure chain) and the zero/one/two-covariate variants of each; enumerate every directed path
  for indirect and total effects and retain the complete covariance.
- [ ] **Independent QA:** Independently enumerate path products and gradients,
  compare fitting and extraction with matched oracles, and plant/detect an
  omitted-shortcut defect, and, for the pure chain, a freed shortcut (and, for the saturated graph, a wrongly dropped shortcut). Verify each variant's two inference methods and
  failures; correlated serial disturbances remain outside this scope.
- **Acceptance/verification:** Six named variants satisfy their own numeric,
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
