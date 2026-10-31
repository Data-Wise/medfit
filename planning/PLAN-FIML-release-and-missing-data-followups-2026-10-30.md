# FIML release readiness and missing-data follow-ups

Date: 2026-10-30. Status: A1 completed through separately authorized PR #367;
remaining milestones are planning and review only. This document does not
authorize further implementation. This reconciles the completed FIML milestone,
the 0.16 scope decision, the release audit, missing-data research, and the missingmed inventory.
It does not replace either package's detailed acceptance contracts.

## Current state and authority

- Regression-oracle milestone A1 and bounded minibook preface clarification:
  merged via PR #367 (`fb879fac`) after six fast checks passed on exact head
  `9ea8b45a`. Post-merge coverage and Codecov patch passed on `fb879fac`
  (run `41147354533`; 8,789 passes, zero failures, five expected warnings,
  140 skips). Merged local branch and worktree removed; 200 evidence files archived and hash-verified. This does not
  complete A2's proposed full teaching unit or expand model/inference support.
- medfit bounded FIML: merged through PR #364 (`a894e45e`). Independent QA and
  historical local/hosted verification are recorded in
  [the completed implementation plan](PLAN-FIML-bounded-integration-2026-10-29.md).
- Coverage scope: PR #365 merged as `2c4bd65c`.
- 0.16 scope/docs: PR #366 merged as `c4b76fb5` after six live fast checks passed
  at `02f908e3`, including test-coverage and Codecov patch. Reviewed and merged
  trees were identical; local dev was fast-forwarded and merged local branch/
  worktree removed after exact-head/ancestry checks. 140 evidence files were
  archived and verified. Local-only receipt:
  `_agents_workspace/0.16-fiml-scope-merged-2026-10-30.receipt.json`;
  archive SHA-256 `92bf4c8cf4af3b7961afe208353b21b47154d5a8559e7cda612a18a4e17eabf9`.
- Post-#366 dev coverage
  [run `41106465575`](https://github.com/Data-Wise/medfit/actions/runs/41106465575)
  completed successfully at merge commit `c4b76fb5`: 8,626 passes, zero failures,
  three warnings and 140 skips. The reported Codecov patch status also passed.
  Both results were verified live at 2026-10-30 18:42 UTC by the authorized
  monitor. Local branch/worktree cleanup is complete; remote feature branches
  remain retained. Metadata reconciliation is local only, without a push.
- Bounded FIML is included in **planned, unreleased 0.16**. No release, main
  merge, deployment, submission, push, or expensive CI is authorized here.
- missingmed local source: `feature/lavaan-mbco-medfit`, version 0.10.0.9000,
  clean at inspection. Its `tasks/plan.md` and `.STATUS` dated 2026-10-26/27 still
  leave D4 independent closure, D5 consumer integration, and T5 acceptance open.
  Their dependency descriptions predate medfit's later work. This is a local
  inventory, not a refreshed remote-branch or release audit. Do not mark these
  consumer gates passed merely because medfit merged related work.

The [0.16 scope](SCOPE-0.16-FIML-2026-10-30.md) owns release inclusion; the
completed implementation plan owns historic evidence; this file owns the
proposed ordering below. missingmed's owner files remain unchanged: its portion
here is a proposed handoff, requiring reconciliation in that repository.

## Preserve the bounded contract

Only three continuous observed variables in Gaussian random-X simple mediation,
free or exactly zero direct path, free means and positive independent errors.
Exact `missing = "fiml"` opt-in; listwise defaults unchanged; explicit
`fixed_x = FALSE`; observed/model covariance; current validated starts/solvers.
Retain partially observed model rows and exclude only all-empty model rows.
Raw observed likelihood, retained-row nobs, supported ICs, unstandardized effects
and documented normal intervals retain their existing meanings and limitations.

No fixed-X FIML, weights, expected/sandwich covariance, broad SEM support,
bootstrap, profiles, fit tests, MBCO or new convenience API is added. FIML means
observed-data likelihood, not imputation. Random-X is a modeling assumption;
MAR/ignorability and distributional assumptions are not certified by software.

## Responsibility split

| Owner | Responsibility | Boundary |
|---|---|---|
| medfit | Likelihood, fitting, covariance, retained-row/pattern provenance, solver evidence and capability guards | No MI pooling or MNAR sensitivity engine |
| missingmed | MI/IPW orchestration, pooling, method-specific diagnostics, delta sensitivity and analysis guidance | Delegate numerical fitting; no duplicate FIML optimizer |
| mice | Imputation, chain diagnostics and existing missingness exploration helpers | Reuse supported public tools rather than copy their algorithms |
| RMediation | Existing supported mediation inference integration | Do not infer new FIML support from complete-data or MI support |

## A. Bounded medfit release preparation (recommended first)

This is a proposed short readiness milestone. Fresh execution requires its own
implementation/release scope; expensive checks wait for authorized release to main.

Release-gate distinction: A3 and accurate documentation of shipped behavior are
required by existing repository rules. A1's additional fixture promotion and
A2's new minibook unit are recommended follow-ups, not newly imposed 0.16 gates.
They become scheduled prerequisites only by an explicit scope decision. Any
discovered correctness defect must be resolved or explicitly scoped out before
release regardless of where it was discovered. A failed new experiment blocks
that experiment's acceptance, not automatically the release when it has exposed
no production defect. Existing required numerical gates remain mandatory.

### A1. Reconcile evidence and close the production-test gap

Completed through [the regression-oracle milestone](PLAN-FIML-regression-oracles-2026-10-30.md)
and PR #367. The contract below remains the historical acceptance record.

The [static production-test inventory](AUDIT-FIML-regression-inventory-2026-10-30.md)
records existing no-complete-row, singleton and no-overlap coverage. Reuse those
checks; promote only missing numerical evidence. The inventory ran no fits.

Inventory production tests against archived prototype cases before adding tests.
`tests/sim/sem-fiml-gate.R:64` currently fits two missingness designs with free/zero
direct paths (four fits); its six checks yield 24 rows. The prototype's 42 fits
are historical, not a claim of 42 public-API regression cases.

Promote only uncovered, discriminating cases through public APIs:

1. Missingness depending on observed X, with X observed for those decisions.
2. No complete rows but connected, estimable partial-row patterns.
3. All seven nonempty patterns, singleton patterns, plus an all-empty row.
4. Joint location and scale transforms, checking intercepts and full covariance.
5. Near-singular but estimable geometry, paired with a deliberately unidentified
   no-overlap design that must refuse inferential output. For the latter, freeze
   a fixture with independently deficient observable-moment Jacobian rank and
   require `medfit_sem_fiml_error`, `stage = "numerical"`, reason
   `observed-pattern moment Jacobian is rank deficient`, plus retained genuine
   completed attempts. An unrelated input/solver error is not a passing control.
   This targets the guard in `R/sem-fiml.R:324`; if earlier solver acceptance
   prevents reaching it, record an unexercised guard rather than claim a pass.

Cover free/zero direct-path variants where their parameterizations differ;
both entry points need equivalence/provenance checks, not duplicate every slow fit.
Use stored or reproducibly generated inputs with fixed identities. Singleton
rows contribute likelihood but alone do not guarantee identification.

Acceptance: preserve independent row-wise Gaussian likelihood checks and lavaan
observed-information/full-covariance comparisons with matched random-X, means,
row inclusion, parameterization and likelihood constants. Compare at the same
parameters as well as at fitted optima, so optimizer agreement cannot mask an
objective error. Before any candidate runs, commit a fixture manifest containing
input identity, model/roles, expected row set/rank, oracle parameter mapping,
transformations, expected refusal and all comparison formulas/limits. Report
minimum/maximum eigenvalues of the diagonally normalized observed information
and observable-moment geometry in solver coordinates; the current production
minimum-eigenvalue gate is `.sem_singular_tol = 1e-4` (R/sem-optim.R:27), not a new
diagnostic cutoff. Derive reference conditioning independently of medfit output.
Use existing production limits: estimates 1e-5, standardized full-covariance error
1e-3, independent NLL error 1e-7. For affine checks transport estimates/covariance
back to base coordinates and account for the likelihood Jacobian, then use the
same limits. An ill-conditioned cell missing those limits remains unresolved;
changing limits requires a separately reviewed numerical justification, never
post-hoc acceptance. Report every cell, numerical failure and deliberate
refusal. Do not widen limits merely to pass. Preserve zero-origin inference
limits and no-RNG/refit guards. None of this proves MAR, global optimality, or
confidence-interval coverage. Any unexplained discrepancy blocks the milestone.

### A2. Website, help and one minibook unit

The focused minibook unit is merged into dev via PR #368 (`e2f028f9`) under
[its authorized plan](PLAN-FIML-minibook-unit-2026-10-30.md): Chapter 8, navigation
and preface link. The full nine-page HTML book rendered successfully; the user
visually accepted it. Independent likelihood review, executed examples and docs
checks passed. Final local gates passed: 1,783 tests, 9,785 passed assertions,
zero failures/errors, four warnings and two skips; lint clean and built-package
check `Status: OK`. The single corrective retry repaired book-test contracts,
not production code. All six exact-head fast checks passed before the authorized
merge. Branch/worktree cleanup and the 805-file evidence archive are verified;
duplicate post-merge coverage run `41155534928` completed cancelled at user
request under the local-first policy; reviewed PR coverage and Codecov passed. Website deployment and
release remain separately authorized actions.

A separate pre-existing currency issue was found while reviewing the new unit:
`vignettes/articles/native-guide.qmd` uses binary `mediation_demo$treatment` in its
FIML example while describing continuous Gaussian random-X support. The new unit
uses an independently checked continuous Gaussian fixture; the existing guide
example remains unchanged and needs a separately scoped documentation correction.
Do not treat the new unit as completion of the full website/help audit below.

Check both entry points, exact opt-in/defaults, random-X assumptions, row nobs,
means, observed SEs, supported extraction and unsupported inference in help,
README, website and examples. Explain that an all-empty model row contributes no
likelihood and that unused extra columns do not determine retention.

Add one focused worked minibook unit: a partial-row numerical likelihood example;
pattern/overlap reading; fit/extraction example; assumptions and refusal example;
one exercise with a checked answer. Link it from the current preface. Do not
rewrite all seven complete-data chapters or imply they prove FIML results.

Acceptance: execute examples against an isolated install of the candidate, require
successful full renders and inspect their actual HTML; retain source/package
identity and exit status. An HTML file from an exit-1 render is not a pass.
Check public links and the support matrix; deployment is separate authorization.
Use existing provenance for examples if sufficient; a new exported diagnostic
function is not a prerequisite for documenting current bounded FIML.

### A3. Actual release candidate, later authorization

Before release: reconcile NEWS/full dev scope and open issues, versions/dates and
dependent compatibility; run the repository-required local suite, numerical gates,
check, documentation and lint on the candidate. Investigate failures and skips;
do not substitute old counts or optimizer success for gates. Existing overall
and critical-path coverage requirements still apply; do not claim the historical
98.48% patch result establishes 100% critical-path coverage.

CI policy: PR #370 merged as `c42e306e`; hosted coverage runs only on main
PRs and main pushes, including metadata-only changes. Development coverage and
verification run locally with Rforge and independent numerical oracles; the
remaining fast hosted checks are retained. No dev post-merge coverage is expected.

Only during authorized release-to-main preparation run required OpenBLAS/full
platform checks. Verify exact release head/live CI before a main merge and main
CI before tagging. GitHub release and CRAN submission are distinct; current
submission holds remain. No extra feature is silently added to this checklist.

## B. missingmed consumer checkpoint (separate from medfit 0.16)

First compare the existing approved D4/D5/T5 clauses and evidence with a pinned
medfit candidate. Record clause-level pass/fail/not-tested dispositions and the
seed-45 simulated case's accepted origin/limits. Revalidate proper/improper null
branches, warnings, typed failures, branch/row/likelihood evidence and both ARIV
policies where required. Reconcile dependency floors only after this compatibility
check; a GitHub dependency requirement does not establish CRAN availability.

Acceptance and required execution scope remain owned by missingmed's existing
plan. Do not replace an unclosed gate with this new roadmap or restart accepted
work wholesale. This consumer checkpoint does not require FIML adoption and is
not automatically a medfit 0.16 blocker; demonstrated dependent breakage is.

## C. Missing-data diagnostic milestone (separately authorize)

Start with an additive report for supported existing missingmed inputs, not an
automatic method selector. Proposed names/schema need review before coding.

- Raw-data section: original sample, analysis variables/roles, per-variable
  missing counts, complete/partial/empty counts, patterns and pairwise counts.
  Model-only and auxiliary-variable summaries must be labeled separately.
  State each denominator; preserve variable order and align counts under row
  permutations. For mids inputs inspect original incomplete data, not completion 1.
- MI section: expose existing mice diagnostics/logged events and per-imputation
  fitting warnings/failures; expose existing path-level RIV/FMI without calling
  it indirect-effect FMI or a missingness percentage. Diagnostic unavailability
  is explicit; successful fitting is not imputation-chain convergence.
- IPW section: summarize observation probabilities, pre/post-trim weights,
  number trimmed and descriptive effective sample size `(sum(w))^2/sum(w^2)`.
  Label that ESS is not a universal inferential sample size or positivity proof.
  The current fit stores final weights but not all internal pre-trim quantities.
  A future fit-time capture design is required; old objects report unavailable
  fields instead of secretly refitting the observation model during diagnostics.
- Sensitivity section: surface the existing conditional delta scale, realized
  marginal shift, failed scenarios and grid-dependent tipping points. Do not
  present a delta scenario as an identified MNAR estimate.

Acceptance: direct count/weight calculations on small hand-checkable inputs;
agreement with installed supported mice helpers where semantics match; no hidden
refits, RNG changes, imputation changes or automatic variable exclusion. Missing
data percentages, pattern structure and MCAR tests never certify MAR/MNAR.
No universal missingness/overlap cutoff, automatic MCAR screening gate, FMI
threshold or automatic auxiliary selection is introduced. Cover all-observed,
all-empty, factor/auxiliary inputs, reordered rows, dropped analysis rows, and
explicitly unavailable diagnostics. Keep implementation cost bounded by staged
raw summaries first; MI/IPW/sensitivity views can follow independently.

## D. Computational efficiency baseline (measurement before optimization)

Proposed medfit baseline: eight cells, one untimed warm-up and three timed repeats
per cell, serially on the same machine. Three cells use N=250/1000/4000 with all
seven patterns; two use N=1000 with one/three patterns; the last three vary only
affine scale, conditioning, or missingness versus the N=1000 seven-pattern cell.
Freeze masks, values, seeds, repetition order, scale and conditioning values in
the execution manifest before timing. This is 32 fits per implementation; do not
expand into a full factorial sweep. Measure
preparation, solver calls, observed-Hessian/covariance work and repeated accessors
separately; report elapsed-time distributions, memory, objective/derivative
evaluations, failures, hardware/BLAS/package/source identities. Warm-up and repeat
conditions must be recorded. Nonconvergent cells remain in the report.

For medfit, pattern sufficient statistics already remove the row loop from each
objective evaluation: three variables permit at most seven nonempty patterns.
This does not make end-to-end runtime independent of N: preparation and provenance
validation may scale with N. Candidate profiling targets include repeated
preparation, numerical Hessians and accessor hashing, not assumed bottlenecks.
For missingmed, separate mice completion, per-imputation fits, pooling, D4 refits
and delta re-imputation sweeps. Do not skip required re-imputation at each delta.

Compare lavaan with the same raw rows, random-X model, mean structure, free/zero
direct path, Gaussian constants, observed information and result units. Require
likelihood/estimate/covariance agreement under the predeclared A1 metrics before
interpreting timings; disclose different optimizer/start protocols instead of
claiming equivalent work. Preserve current medfit starts, independent solvers, tolerances,
failure rules and covariance verification. No speedup ratio is promised. A baseline
is recommended before public performance claims, not a release blocker without
an identified regression. Parallel execution, caching and analytic derivatives
require measured justification and a separate design/authorization. This first
baseline establishes a reference, not evidence of a regression. A future change
needs a paired baseline/candidate comparison on identical cells/environment;
freeze its material-change criterion before results. No speed target or threshold
is invented here. A missingmed timing study is separately designed and bounded;
the eight-cell medfit design is not implicitly multiplied across MI/IPW/delta grids.

## E. Deferred adoption and broader methods

A later missingmed FIML route would be a thin medfit adapter. Do not overload the
MI `run -> pool -> infer` contract or disguise a single FIML fit as m=1 MI. Decide
the opt-in input/result/API contract first; delegate fitting and preserve refusal
rules. No FIML-MBCO, FIML FMI, automatic sensitivity transfer, general auxiliary
variables, fixed-X or broad SEM support follows from existing MI/IPW features.

## Grill: decisions and rejected shortcuts

| Question | Decision / what would change it |
|---|---|
| Is FIML done? | The bounded fitting milestone is merged; release preparation remains. Broader missing-data support is not promised. |
| Does every suggestion block 0.16? | No. A3 and truthful shipped-feature documentation are required; extra A1 fixtures/new A2 teaching unit await scheduling and do not silently block 0.16. B is a consumer checkpoint; C/E are new milestones; D supports performance claims, not release absent a demonstrated problem. |
| Why more tests after green CI? | A1 addresses specific public-API fixture gaps, not a demand to rerun every historical experiment. Inventory first; retain already adequate tests. |
| Why not one combined diagnostic API now? | Data coverage, numerical stationarity, MI convergence and MNAR sensitivity answer different questions; stabilize their meanings before a cross-package schema. |
| Why not auto-select MI/FIML/IPW? | Diagnostics do not identify the missingness mechanism or choose the estimand; model and scientific assumptions require analyst decisions. |
| Why not optimize before release? | No production bottleneck is measured. At p=3, bookkeeping or Hessians can dominate tiny matrix operations; profiling decides. |
| What evidence changes the order? | A correctness/consumer regression becomes a blocker; actual performance regression merits profiling; user demand plus a defined adopter can prioritize C/E. |

## Research provenance and review limits

NotebookLM queried existing missingmed and numerical-computing notebooks. Its
missing-data answer supplied source excerpts; the numerical answer returned no
verifiable citations and included incorrect/unjustified numerical advice. Do not
adopt its finite-difference prescriptions, universal cutoffs or page claims.
It also misread "bounded scope" as truncated Gaussian data; that is not this model.

Primary references checked for the planning recommendations:

- [Heymans & Twisk (2022)](https://doi.org/10.1016/j.jclinepi.2022.08.016),
  section 2: observed-data exploration does not establish MAR versus MNAR.
- [Rosseel (2021)](https://biblio.ugent.be/publication/8737599): likelihood
  implementation and pattern reuse in two-level SEM; supports a computational
  principle, not medfit-specific speed or single-level benchmark numbers.
- [mice missing-data tools](https://amices.org/mice/reference/), including
  [md.pattern](https://amices.org/mice/reference/md.pattern.html) and
  [flux](https://amices.org/mice/reference/flux.html): reuse public helpers with
  version/semantic checks; no new dependency on undocumented internals.

This planning pass inspected current source/tests/docs and prior receipts but ran
no numerical tests or benchmarks. No new correctness defect is claimed. Stage
only named planning/report files for any local commit; unrelated `.codex/` and
the untracked draft PR report remain untouched. Claude's original review and
the subsequent planning dispositions are recorded in
[the review receipt](REVIEW-FIML-readiness-plan-2026-10-30.md);
neither static review nor a favorable verdict authorizes implementation or release.
