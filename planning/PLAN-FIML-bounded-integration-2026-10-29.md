# Bounded FIML integration: first adopter milestone

Status: ACTIVE. Authorized 2026-10-29: implement the reviewed bounded contract and
run independent QA and local verification. This explicitly authorizes the appended
fit_sem missing-method option under the API freeze, limited to this contract.
Worktree: .worktrees/fiml-feasibility; branch codex/fiml-feasibility.
Pre-implementation source: 3023d14c; dev baseline: edcf23d8705165cd2497deda0d4e8410b9754811.

## Scope and holds

Implement [the reviewed integration contract](studies/fiml-feasibility/integration-design.md)
and its [static review](studies/fiml-feasibility/integration-design-review.md).
That version remains the detailed acceptance source; this plan tracks execution.
FIML remains separate from 0.16. No release assignment, push, PR, deployment,
dev-to-main merge, expensive CI or plugin installation is authorized.
Preserve research evidence and unrelated .remember/ files. Existing prototype
scripts and frozen evidence are references, not package runtime dependencies.

## Task F1: bounded production integration and acceptance

- [ ] Implement test-first; commit; implementer.md PASS.
- [ ] Independent oracle QA and planted defects; qa.md PASS.
- [ ] Pre-docs local gates; gates-pre-docs.md PASS.
- [ ] Update affected help/site/technical docs; docs.md PASS.
- [ ] Final required local gates and full suite; gates.md PASS.
- [ ] Reconcile plan/status and commit; retain worktree for user review.

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

Pending. Record tested source revisions, exact counts, numerical tolerances,
planted defects, lint/check warnings/skips, applicability of unchanged numerical
gates and any deferred requirements. Implementation readiness is not release
readiness or permission to submit externally.
