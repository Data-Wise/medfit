# Bounded FIML integration: first adopter milestone

> Release-scope update (2026-10-30): bounded FIML is complete and merged into dev
> through PR #364. It is now included in planned, unreleased 0.16; this supersedes
> earlier 0.16 exclusions in the dated record below. Model/support limits are
> unchanged. No release or expensive CI is authorized. See the
> [current scope decision](SCOPE-0.16-FIML-2026-10-30.md).

Status: MERGED INTO DEV via PR #364, squash a894e45e, 2026-10-30.
Post-merge fast coverage and Codecov PASS. Corrective FINAL local gates passed
on 32a7b98. Authorized 2026-10-29: implement the reviewed bounded contract and
run independent QA and local verification. This explicitly authorizes the appended
fit_sem missing-method option under the API freeze, limited to this contract.
Former worktree: .worktrees/fiml-feasibility; branch codex/fiml-feasibility.
Both were removed after verified merged-branch cleanup on 2026-10-30.
Pre-implementation source: 3023d14c; dev baseline: edcf23d8705165cd2497deda0d4e8410b9754811.

## Scope and holds

Implement [the reviewed integration contract](studies/fiml-feasibility/integration-design.md)
and its [static review](studies/fiml-feasibility/integration-design-review.md).
That version remains the detailed acceptance source; this plan tracks execution.
FIML remains separate from 0.16. Initial local-only authority was subsequently
extended to draft PR #364, its reviewed dev merge, and post-merge reconciliation
and cleanup. No release assignment, deployment, dev-to-main merge, expensive CI
or plugin installation is authorized. A future 0.16 release must explicitly
exclude FIML: an unfiltered dev-to-main release would include the merged feature.
Preserve research evidence and unrelated .remember/ files. Existing prototype
scripts and frozen evidence are references, not package runtime dependencies.

## Task F1: bounded production integration and acceptance

- [x] Implement test-first; commit c3247be3; implementer.md PASS.
- [x] Independent oracle QA and planted defects; qa.md PASS on 625e7280.
- [x] Pre-docs local gates; gates-pre-docs.md corrective retry PASS on 0f40b73f.
- [x] Update affected help/site/technical docs; docs.md PASS.
- [x] Final required local gates and full suite; gates.md PASS.
- [x] Reconcile plan/status and commit; retain worktree for user review.

### Acceptance

1. Append exact missing = c("listwise", "fiml") selection to fit_sem and native
   engine_args. Preserve all existing positional/default/listwise calls and old
   objects. Explicit FIML requires explicit fixed_x=FALSE, meanstructure=TRUE,
   observed/model SEs, no weights, empty control and three starts per solver.
2. Validate completed RAM topology: three numeric observed variables with arbitrary
   names, X->M->Y and free/exact-zero X->Y; independent positive disturbances and
   free intercepts, no unsupported constraints/structure. Reject unsupported
   inputs before optimization. Retain any-observed rows; drop only all-empty rows;
   preserve exact positional ledger, patterns, counts and failure attempts.
3. Port the validated pattern likelihood, derivatives, full observed Hessian,
   standardization/affine transport and dual-solver acceptance without weakened
   limits. SLSQP/nlminb three starts each, nlminb refinement, raw statuses and
   structured failures; no global-convergence or coverage guarantees.
4. Dedicated discriminated FIML ledger/validation binds actual NLL, settings, rows,
   model and selected attempt. f/model-test df unavailable, k=8/9 separate.
   Existing complete-data ledgers/statuses/counts remain unchanged.
5. Support SEMFit coefficients/covariance/nobs, raw logLik/AIC/BIC, print/summary,
   parameter tidy/normal CI and bounded glance. Extract a durable FIML MediationData
   subclass with validated context; support paths/nie/nde/te, coef paths/effects/all,
   vcov, print/summary, tidy all variants and normal paths/effects CI. Use central
   effect gradients; independently verify g'Vg and all cross terms. Distinguish
   fixed cp=0 from unavailable NIE-origin inference. Preserve provenance on copy
   and serialization. No misleading bootstrap advice.
6. Guard deferred package-owned object-aware APIs before RNG/refits/workers,
   including quick, pm, extracted glance, bootstrap/boot CI, constrained refits,
   fit tests and comparison. Complete-data FIML and mixed-method objects stay
   guarded. med remains a formula fitter, not a getter or extra FIML route.
   Opaque raw-data callbacks/external consumers remain outside this guarantee.
7. Reproduce unchanged prototype 42 fits, 13 edges, 126 derivative/likelihood
   points, independent optimizer gates and 61 P2 assertions locally. Exercise both
   public routes, arbitrary names, no complete rows, missing X, affine/free/zero-cp,
   rank failures and every support/refusal boundary. Independent likelihood/lavaan
   and full covariance references must not reuse production objectives/helpers.
   Plant wrong-N covariance, complete-case retention, dropped covariance terms,
   lost provenance and missing-guard defects; prove each fails its test.
8. Verify listwise neutrality against the pre-feature source, including positional
   calls, fixed-X defaults, warnings, statuses/counts and historical objects.
   Run relevant constraint/Jacobian/Hessian/all-row/zero-product/restart regressions,
   applicable local numerical scripts, loaded and installed-current-package lint,
   registration/docs tests and final ordinary full suite/package check. No expensive
   hosted/platform CI dispatch; unchanged expensive grids require a concrete reason
   to rerun. Do not waive unexplained failures or widen tolerances.

### Ownership and execution

Parent owns this plan, active pointer and final status. Sequential roles:
implementer owns production R and regression tests; QA owns independent harnesses
and narrowly necessary tests, not R; gates owns verification/lint-only fixes;
docs owns roxygen/Rd/NEWS/README/site/technical documentation and docs tests, not
runtime behavior. All operate only in this worktree and preserve others' changes.
Reports: _agents_workspace/fiml-integration/{implementer,qa,gates-pre-docs,docs,gates}.md.
Every report ends with exactly one final Verdict: PASS or Verdict: FAIL line.

Run implementer -> QA -> gates(pre-docs) -> docs -> gates(final). Read and embed
full role contracts. One corrective retry per failed stage, retaining failure
logs; a second failure stops the pipeline for user review. QA findings return as
one batch. A failed/missing report never authorizes the next stage. Each editing
stage ends with a scoped conventional commit, never push. Final gates run the
full suite once on the completed tree, not once per stage. No PR is created.

## Evidence and decisions

Initial implementation c3247be3: focused 12 tests/217 expectations, registry 5/42,
prototype 42 fits/13 edges/126 points and P2 4 tests/61 expectations pass.
Independent QA: eight public numerical cells plus score/Hessian/affine transport
pass; first QA FAIL on two boundary P2s: mixed-class IC comparison and lost
completed evidence after a solver-return evaluation exception. Initial report
preserved as qa-initial-fail.md. Corrective implementation 625e7280 passes
14 tests/246 expectations; independent focused re-QA PASS. Original and later
post-solver faults retain exact calls/statuses/parent evidence; valid IC controls,
24 registered gate checks and pre-feature baselines pass. No numerical limits changed.

Intermediate-stage evidence follows. Record tested source revisions, exact counts, numerical tolerances,
planted defects, lint/check warnings/skips, applicability of unchanged numerical
gates and any deferred requirements. Implementation readiness is not release
readiness or permission to submit externally.

## Implementation contract interpretations

- Topology determines extracted roles even when original labels collide with
  a/b/c_prime aliases. SEMFit keeps original named theta/full covariance. Extracted
  canonical aliases take their role meanings; validated fit_context retains the
  original source theta/covariance and explicit role mapping. A single extracted
  name cannot denote two coordinates. Central effect gradients remain authoritative.
- Generic malformed-argument type validation precedes the FIML adapter and may
  produce ordinary checkmate/base errors. Structured FIML stage/reason/parent and
  completed-evidence guarantees cover adapter/topology/numerical failures.
- Package-owned AIC/BIC dispatch checks the entire comparison list for FIML
  compatibility before external likelihood calls. Calls dispatched first through
  another model class remain outside this guard; no global interception is claimed.

## Critical rejection coverage correction

Initial pre-docs gates found regression-coverage gaps, not formula mismatches.
The report is retained as gates-pre-docs-initial-fail.md. Lint-only helper fix
af0fef2 and test-only correction 0f40b73f preserve production numerical source 625e7280.
Independent QA passes 20 tests/312 expectations and all eight identified critical
rejection groups; three acceptance/agreement/curvature guard mutants fail their
intended assertions. Combined fault controls retain honest calls/attempts and
agree with full named lavaan coefficients/covariance.

The one corrective pre-docs retry passes 113 tests/985 expectations, installed
instrumented 20/312, unloaded installed-source lint and risk_check. Focused new
file records: 205/212 (kernel), 127/128 (adapter), with all identified critical
anchors executed. Defensive remainder is explicitly disclosed, not excluded;
these numbers do not establish 100% whole-file or overall package coverage.
Final gates must measure overall coverage after docs and run the full local suite
and package check. No expensive hosted/platform CI was dispatched.

Requested argument brainstorming is recorded in
[the API analysis](studies/fiml-feasibility/argument-design-analysis.md), committed 86fb36f.
It explains statistical choices versus initial validated-protocol restrictions;
it does not authorize extra engines, model structures or optimizer controls.

## Documentation stop — 2026-10-30

Scoped docs commit b37f878 updates help, site sources and study technical records
without runtime changes. Docs consistency passes 86 tests/620 expectations; spelling,
roxygen-file lint, markup and whitespace checks pass. All six corrective HTML outputs
were visually inspected. The native-tutorial corrective process nevertheless exited
1 without an explained error, so docs.md ends Verdict: FAIL. The initial cache-access
failure and corrective logs are retained. No third render or final gate was run.

Final inventory also identifies general-listwise claims in native-guide.qmd line201
and models.qmd line80 that still need bounded-scope qualification. Resume requires
explicit authorization under the orchestrator failed-stage/retry rule; then repair
those claims, explain/resolve the render exit, verify docs and run FINAL gates.
Full suite, package check and overall coverage are pending, not waived. Keep the
active plan and worktree for review. No external submission or expensive CI.

## Authorized resume — 2026-10-30

The user approved resuming the stopped documentation stage and subsequent required
local final checks. Retain the prior FAIL report/logs, resolve the render exit and
two remaining scope statements, then require docs PASS before FINAL gates. All
existing scope and submission/CI holds remain. No new model or inference support.

## Final local completion — 2026-10-30

Documentation resume 931791a clears the render blocker with fresh explicit exits0
and inspected HTML; no root cause is invented for the historical exit1. Initial
FINAL failed five assertions in three maintenance groups, preserved in
gates-final-initial-fail.md. Corrective b2f94833 replaces a missing-formal capability
shortcut with behavioral retention/likelihood/covariance/refusal probes and
registers fiml in C2; 32a7b98 explicitly pins meanstructure in the numerical fixture.
No production numerical behavior, defaults, tolerance or coverage exclusions changed.

The one corrective FINAL retry passes on tested source 32a7b98:

- Ordinary suite: 171 files, 1,765 tests, 9,604 expectations; 9,600 passed,
  zero failures/errors, two skips and two documented warnings; 212.183 seconds.
- Local CRAN tier: 9,372 passes, zero failures, 37 skips, two warnings; 147 seconds.
  Actual built-tarball check: Status OK, zero errors/warnings/notes; 45 seconds.
- Full installed covr: 96.20767% overall; 8,655 passes, zero failures,
  126 skips, two warnings; 288.437 seconds. All identified critical FIML
  validation, extraction, acceptance and early-bootstrap-guard groups execute.
  Defensive/legacy records and a display-only provenance line remain disclosed;
  no blanket 100% whole-file/branch claim.
- Fresh installed unloaded-source lint: zero findings. Exact high-risk draft
  checklist has no missing items. Registered FIML gate: 24 rows/six driver checks
  pass, output byte-identical to the prior baseline. Independent QA remains
  applicable to unchanged numerical source 625e7280.

Closing edits reconcile status, the active pointer and study overlays/manifest only;
32a7b98 remains the tested runtime/test tree. Retain the branch and worktree for
user review. Local completion is not release or external-submission readiness:
FIML stays separate from 0.16, with no push, PR, merge, release or expensive CI.

## Dev integration and post-merge verification — 2026-10-30

The author authorized review and merge of PR #364. The unchanged reviewed head
7cd8c07e4e0772f690311f58cfcb8b877e2f1094 passed all five fast checks, including
the refreshed risk-tier check, before squash merge
a894e45e078e73aaee639c8ba51738c87b3c41b3.
The merge and reviewed head have the identical Git tree
5869620937fb710d08077e8f3edb7627bf550d8c.

[Post-merge coverage run 41093099169](https://github.com/Data-Wise/medfit/actions/runs/41093099169)
passed: 8,626 passes, zero failures, three known warnings and 138 skips. Warnings
are the intentional cluster-refit failure, existing sign-branch disagreement and
unavailable sv_SE.UTF-8 locale. Codecov processing completed successfully on the
merge commit: 96.62% hosted overall line coverage and 98.48% patch coverage. These
are distinct from the retained local covr expression coverage of 96.20767%.
No repair or additional numerical rerun was needed. No expensive CI ran.

Local untracked and ignored evidence is preserved in
_agents_workspace/fiml-merged-2026-10-30.zip with an adjacent SHA-256 receipt;
every archive entry is checked against its source before worktree removal. The
uncommitted draft report is also retained in the main checkout study directory.
FIML stays excluded from 0.16; no release or dev-to-main merge occurred.

Cleanup verified: the local feature tip equaled the PR head, the squash merge was
an ancestor of local dev, and all 23,086 archived entries still matched their
sources immediately before removal. The merged worktree and local/remote feature
branch were removed; unrelated worktrees and local .codex/ files were preserved.
