# Issue #360: active residual-variance boundary regression

Status: COMPLETE LOCALLY, verified 2026-10-29; retained for review, not submitted. Base: origin/dev 06a69005abca601fbbb98f7e95387fa11cc1f3c9.
Source: https://github.com/Data-Wise/medfit/issues/360.
Worktree: .worktrees/issue-360-boundary-regression; branch feature/issue-360-boundary-regression.

## Scope and holds

Add a small deterministic regression for a fixed-measurement latent mediation model with an active lower(0) outcome residual-variance bound. Compare fit_sem() with a separately parameterized reduced Gaussian likelihood. No optimizer or public API changes are planned. Finite numerical reference searches support these fixtures only and must not be described as global-convergence proofs. Expensive hosted OpenBLAS/full-platform CI is deferred until release into main. No push, PR, merge, deployment, release or dev-to-main integration authorized.

## Task B1: regression and independent numerical validation

- [x] Implement deterministic regression and commit; implementer.md PASS.
- [x] Independent oracle QA, planted defects and boundary controls; qa.md PASS.
- [x] Required final local gates, full suite, lint and package check; gates.md PASS.
- [x] Reconcile local plan/status and commit; retain clean feature worktree for review.

### Acceptance criteria

1. One identifiable fixed-measurement latent model (two or three indicators, known loadings and known indicator error covariance), n=400 or a justified smaller fixture; a handful of fixed seeds. Include at least one genuinely active-boundary case and an inactive/interior control. Explicit fixed_x=FALSE and meanstructure=FALSE preserve the issue's likelihood.
2. Independently compute the reduced likelihood from observed sample covariance and fixed measurement constants. Do not use medfit model-implied covariance, fit objective, derivative, or optimizer helpers to construct the oracle. Compare all named free coordinates without silent dropping, and compare medfit and oracle candidates on a common independently computed Gaussian/Stein loss. Check objective agreement within 1e-7 and parameter agreement within 1e-3 (or scientifically justified tighter tolerances); no widening to hide an unexplained mismatch. Use an adequate independent start/profile strategy and disclose finite-search limitations.
3. Exercise n_starts=1 and the public default, assert acceptance and actual outcome residual variance at zero when the unrestricted oracle optimum is negative. Use a deterministic boundary-aware control: an unbounded negative-variance candidate must fail the same admissibility/agreement criterion; objective agreement alone cannot reject it because a larger domain can improve loss. Include an interior case so tests do not merely hard-code zero.
4. Demonstrate sensitivity with independently planted ignored-bound/wrong-candidate or wrong-likelihood defects. Tests are expected to pass existing correct behavior; no production bug is alleged. Record a red mutant/positive-control run rather than changing R/ solely to manufacture a production red test.
5. Keep execution small and reproducible. No dependence on the unpublished simulation script, research checkout, generated files or new packages. If runtime justifies skip_on_cran(), report measured timing and keep local NOT_CRAN=true verification mandatory. Prefer self-contained test helpers; retain all fixtures/helpers needed in a built source archive.
6. Test-only changes should not change fitted numbers or public behavior. R/ changes are outside this initial task: stop and return evidence if a production defect is found, instead of broadening scope. Review relevant existing help/NEWS/articles for claims; no manuscript or broad documentation rewrite. No docs stage is needed if only tests and internal metadata change; a changed user-visible claim requires docs and final gates.

### Ownership and likely files

Implementer owns tests/testthat/test-sem-boundary-oracle.R (or one narrowly justified equivalent) and test helpers; may add a short NEWS test-coverage entry if appropriate, but must not edit R/. QA owns independent ignored harnesses and necessary narrowly scoped test additions. Gates owns lint/check scripts only if required and must not change numerical behavior. Parent owns this plan, CLAUDE.md active pointer and .STATUS. All work is in the specified worktree; preserve other sessions and unrelated files.

### Pipeline and verification

Follow medfit-orchestrator sequentially: implementer -> independent oracle QA -> gates(final) when docs unchanged; use pre-docs -> docs -> final gates only if a user-visible docs change is needed. Read each role contract in full and include it in the stage prompt. Reports in _agents_workspace/issue-360/{implementer,qa,gates}.md must end exactly Verdict: PASS or Verdict: FAIL. At most one corrective retry per failed stage; preserve first failure evidence. Send QA findings as one batch. Do not weaken assertions or silently waive failures.

Focused test execution and loaded lint are required at implementation. QA uses a mathematically independent oracle, full parameter names/counts, active/inactive boundary controls and planted defects. Final gates run relevant focused/registration/docs-consistency tests, one ordinary full suite on the final tree, loaded package lint and scripts/check-local.sh/built package check. Risk tier comes from the actual diff; test-only changes do not invent a new high-risk numerical implementation. Existing constraint/Jacobian/Hessian, all-row acceptance, zero-product/restart and tests/sim evidence must be assessed for relevance: do not rerun expensive unchanged grids without a changed path or new concern. Verify source-archive inclusion of new helpers/fixtures. Record exact test counts, timing, warnings/skips and independent oracle limits in gate/QA reports. No hosted CI dispatch.

## Local completion evidence

Tested source: 17663eaf (implementation c5cd56bb; QA comment clarification 17663eaf). Implementation, independent oracle QA and final gates reports all PASS in _agents_workspace/issue-360/. Six native fits agree with independently optimized full observed-data likelihood: maximum coordinate error 3.51e-7, loss error 2.66e-13; three reorder checks pass. Candidate and wrong-likelihood mutations produce 22 and 25 failures. New regression: 69 passing expectations, under one second; installed-archive regression also 69/69.

Final ordinary suite: 1743 tests, 9276 expectations, 9272 passed, zero failures/errors, two existing warnings and two skips. Loaded lint: zero findings. Focused/registration/docs checks: 33 tests, 481 expectations, zero failures/errors/warnings, one expected skip. scripts/check-local.sh: 9044 passes, zero failures, two warnings, 37 skips; built package check Status: OK. Self-contained test is byte-identical in built source archive. No production R/ changes or new supported structure; no docs stage or unchanged expensive simulation-grid rerun needed.

Initial full suite had three semopy failures caused by denied uv cache-lock writes; reproduced on exact base dev. Initial report and logs retained. Single corrective retry used writable task-local UV_CACHE_DIR and unchanged source/assertions; focused semopy and full suite passed. No waiver or tolerance relaxation.

This reconciliation changes metadata only after tested source. Feature worktree retained for review. No push, PR, merge, release or deployment performed; expensive hosted CI remains deferred until release into main.
