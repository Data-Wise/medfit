# Issue #357: first milestone

Status: active, authorized 2026-10-29. Integration: feature/issue-357-first-milestone -> dev, only after separate push/PR authorization. Source issue: https://github.com/Data-Wise/medfit/issues/357 (reduced milestone revision 2026-10-29T16:23:46Z). Base: 40f82c85fdad0979949bee389afe2c7301660315.

## Scope and holds

Implement supported nonzero-product sign-branch fitting, truthful fit-level coverage evidence, existing-reference-only residual diagnostics and independent tests. Defer global certification machinery, strict require API, general shared-factor charts and broad cross-API reporting. No release, deployment, dev-to-main merge, push or PR authorized. Preserve unrelated main-checkout .codex/ files and other worktrees.

## Task M1: implement the reduced contract test-first

- [ ] M1 implementation and scoped commit.
- [ ] Independent oracle QA including planted defects.
- [ ] Pre-docs numerical/focused gates.
- [ ] Scoped user documentation.
- [ ] Final gates, full suite and local package check, report and commit.

Owner boundaries: implementer owns R/ and regression tests plus necessary numerical-gate fixtures/registration; QA owns independent oracle harness and any independently justified regression additions; gates owns risk checklist, gate execution and PR draft; docs owns NEWS/help/articles and documentation consistency. All work stays in this worktree. Stage reports: _agents_workspace/issue-357/{implementer,qa,gates-pre-docs,docs,gates}.md. Every report ends in exactly one Verdict: PASS or Verdict: FAIL line.

### Acceptance criteria

1. Recognize one equality c*a*b==q with finite nonzero constants, two distinct free scalar labels after aliases, no other user rows involving either factor. For unsupported shapes retain existing local search with a reason. For supported shapes independently search a>0 and a<0 with correct b=q/(c*a), within-branch starts, original-coordinate acceptance gates, effective bounds/floors and common sample/domain/objective. Do not use a finite cutoff to claim complete domain or globality.
2. Both required sign branches must be accepted or proved empty with checkable domain/bounds evidence before returning a minimum. Failed branches remain unknown and fail closed under existing direct-fit/MBCO semantics; all empty follows existing infeasible/failure behavior. Zero-product algorithm unchanged. Original D4 typed covariance-stage likelihood retention remains intact.
3. Optional separately versioned search_evidence lives in native result/SEMFit internals and relevant failures, not in version-1 ledger children. Record constraint/context, coverage local/charted/unresolved, reason, ordered branch restriction/state/candidate/objective/gate/attempt evidence. Validate attribution, completeness, false emptiness and canonical result agreement. Old objects without evidence remain usable, with unavailable coverage. Charted is branch coverage only, never a global certificate. No globality payload framework.
4. Preserve optimizer status vocabulary/types/meaning/warnings and unchanged-path values. New-driver counts are truthful per branch and parent; enumeration counts and synthetic reference insertions are distinct. Retain disagreement warnings. Include only a concise fit-report note; no broad reporting/API extension.
5. Raw residual c*a_hat*b_hat-q; optional SE uses gradient and covariance at an already available matching reference fit without tested restriction, same coordinates, sample, weights and settings. Missing/unusable reference produces NA and reason, never automatic refits/covariance recomputation/new primary warnings. Printing/extraction reads stored evidence. Do not use projected constrained covariance. Diagnostics do not affect acceptance, selection or inference.
6. Independent analytic/bounded toy oracles for both signs and better-branch example; multimodal within-branch fixture prevents coverage/globality conflation. OpenMx supports, never establishes, truth. Plant omitted branch, sign swap, false emptiness, fabricated completeness and wrong-reference/projected-SE defects as appropriate.
7. Test active bounds/floors, unsupported shapes, aliases, negative c/q, required-branch failure/all empty, near-zero/large constants, weights, means, units, truthful counts/statuses, malformed evidence and missing-reference zero-extra-calls. Check dependent consumers only as needed for existing failure/D4 inference contracts.

### Likely files

R/sem-fit.R, R/sem-optim.R, R/sem-constraints.R, R/fit-sem.R, R/methods-sem.R; a focused internal branch/evidence module if justified; tests/testthat/test-sem-nonzero-branches.R and existing directly dependent tests. Keep R/sem-outcomes.R ledger schema/validator unchanged. Stage plan adjustments only if supported by concrete findings, not expanded scope.

### Verification / admission

Read and follow medfit-oracle-check and medfit-risk-tier. Risk high. Independent QA must check actual changed numbers against independent likelihood parameterizations, metamorphic invariance and planted defects, plus numeric neutrality on unchanged paths against origin/dev. Relevant native constraint/Jacobian/Hessian, all-row gate, zero-product/restart gates and covered tests/sim structures required. Register changed critical numerical paths with oracle/mutant evidence. Pre-docs gates focused only; final gates run full suite once on final tree, lint, docs consistency, scripts/check-local.sh, built package/R CMD check with exact counts and warnings/skips. Coverage >90% overall and critical-path evidence per repo contract; do not claim hosted coverage without execution. Expensive hosted OpenBLAS/full-platform gates deferred to dev->main release PR under current CI policy, record n/a reason in admission checklist.

Docs must cover changed algorithm, coverage limitations, supported/fallback shapes, failure semantics and unavailable reference diagnostics; search relevant help/README/guides/articles. Render applicable artifacts and inspect actual output when changed. No manuscript/book teaching rewrite unless necessary and separately approved.

### Pipeline / stop rules

Use medfit-orchestrator sequential implementer -> independent QA -> gates(pre-docs) -> docs -> gates(final). Copy each role's full contract into its spawn prompt. At most one retry after a failed stage; preserve errors/reports and stop after failed retry. QA findings go back in one batch; at most the allowed two implementer/QA loops. No assertion weakening, invented oracle, skipped stage or unsupported PASS. Every editing stage ends with scoped conventional commit. Do not tick final acceptance without actual evidence. Implementation difficulties are not permission to broaden the milestone.

