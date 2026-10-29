# Issue #357: first milestone

Status: locally verified, awaiting separate external-submission authorization; authorized 2026-10-29. Integration: feature/issue-357-first-milestone -> dev, only after separate push/PR authorization. Source issue: https://github.com/Data-Wise/medfit/issues/357 (reduced milestone revision 2026-10-29T16:23:46Z). Base: 40f82c85fdad0979949bee389afe2c7301660315.

## Scope and holds

Implement supported nonzero-product sign-branch fitting, truthful fit-level coverage evidence, existing-reference-only residual diagnostics and independent tests. Defer global certification machinery, strict require API, general shared-factor charts and broad cross-API reporting. No release, deployment, dev-to-main merge, push or PR authorized. Preserve unrelated main-checkout .codex/ files and other worktrees.

## Task M1: implement the reduced contract test-first

- [x] M1 implementation and scoped commit (`adc6c70`; repair report PASS).
- [x] Independent oracle QA including planted defects (QA loop 2 PASS at f6a6e86).
- [x] Pre-docs numerical/focused gates (gates-pre-docs.md PASS).
- [x] Scoped user documentation (90855fa; docs.md PASS).
- [x] Final gates, full suite and local package check, report and commit (corrective gates.md PASS at 1572e80).

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


## Stage stop — 2026-10-29

Implementation stopped after the first failed native subset and its corrective retry. Retry: 914 tests, 5583 expectations, 2 failed expectations, 3 errors. Remaining failures: coefficient-scaling invariance and three synthetic Hessian-gate fixture errors; one brace lint also remains. See _agents_workspace/issue-357/implementer.md and retained logs/RDS. Source-versus-fixture hypotheses are not yet independently verified. Only the plan commit 00c560c exists; implementation changes remain uncommitted. Independent QA, pre-docs gates, docs and final gates have not run. Resume requires author direction under the orchestrator stop rule. No push/PR/release/deployment.

## Authorized repair/resume — 2026-10-29

Author authorized fixing coefficient-scaling and Hessian-gate fixture failures, then resuming independent QA and required gates. Reuse the existing worktree and preserve initial FAIL evidence. The no-push/no-PR hold is explicit. Run implementation repair first; downstream stages require a committed PASS report.

## Repair handoff — 2026-10-29

Implementation repair committed adc6c70. Native subset: 916 tests / 5610 expectations / 0 failures / 0 errors / 0 skips, one disclosed disagreement warning. Final single-accepted-attempt spread compatibility edge: 1 test / 5 expectations passed; loaded lint clean. Independent QA in progress; no gates/docs/full-suite claims yet.

## Independent QA loop 1 — 2026-10-29

QA FAIL: all 40 independent numerical cells passed their preset tolerances; eight adversarial evidence/classification probes failed. Findings include bounds attribution, fabricated local coverage, missing gate/optimum records, parent counts, candidate/objective attribution and exact coordinates, and multiple disjoint products incorrectly classified as supported. Three numerical mutants caught; focused regressions 14 tests / 102 expectations / 0 failures/errors/skips. Full findings preserved in _agents_workspace/issue-357/qa.md. Batched repair sent to implementer; re-QA must check changed claims, unchanged-path neutrality and planted defects. Gates/docs remain pending. No push/PR.

## QA repair handoff — 2026-10-29

Committed f6a6e86: all eight QA evidence/classification findings and alias fallback have red/green regressions. Focused plus affected compatibility checks: 95 tests / 651 expectations / 0 failures/errors/skips; one expected disagreement warning. Lint clean. Independent QA loop 2 running; gates/docs remain pending.

## Independent QA loop 2 PASS — 2026-10-29

48/48 original independent numerical/evidence cells pass. Old-validator/classifier mutants caught; five unchanged paths match origin/dev exactly. Focused nonzero/D4/outcomes/post-fit/MBCO: 68 tests / 926 expectations / 0 failures/errors/skips. Matching-reference SE agrees with independent lm ML covariance to 9.94e-14; optimizer/covariance stop guards verify no extra calls. Typed D4 failure retains accepted theta/f/evidence. See qa.md and qa-loop1.md. Pre-docs gates in progress; docs/final gates pending.

## Pre-docs gates PASS — 2026-10-29

Combined focused results: 1008 tests / 6277 expectations / 0 failures/errors/skips, one disclosed disagreement warning. Three initial semopy cache failures resolved by isolated 14-test/73-expectation approved-access retry; broader interrupted retry is not claimed complete. Profile 144/144, nonlinear parity 240-row rule and bootstrap, restoration 13/13 pass; three mutants rejected. Whole-package loaded lint clean; exact draft risk checklist has no missing items. Sandbox detectCores NA resolved by unchanged-script approved-access retry. Documentation running; final suite/package check/coverage pending.

## Documentation PASS — 2026-10-29

Committed 90855fa: scoped help/Rd, NEWS, README and five technical/site articles. Documentation checks 92 tests / 902 expectations / 0 failures/errors / one existing load_all help skip; spelling and lint clean. All five changed articles render successfully against current-source scratch installation; actual generated HTML inspected. Final gates running; no hosted/merge-readiness claim yet.

## Initial final gates — coverage shortfall

Final gates FAIL only on five uncovered critical lines in R/sem-nonzero.R: 56-57 indefinite-reference covariance rejection, 223/225/227 status-evidence validation variants. Overall measured coverage 96.02113%; new module 98.11%. Ordinary full suite passes 1737 tests / 9169 expectations (9165 passed), 0 failures/errors, 2 skips, 2 warnings. scripts/check-local.sh passes: quick tier FAIL 0/WARN 2/SKIP 37/PASS 8937, built-tarball R CMD check Status OK. Lint clean. Focused test-only coverage repair authorized within current task, followed by independent focused QA and the single corrective final-gate retry. No coverage waiver or push/PR.

## Critical coverage test repair — 2026-10-29

Committed 1572e80, one test-only file, no R behavior changes. Focused 21 tests / 128 expectations pass; loaded lint clean. Independent qa-coverage.md PASS: exact spectral/directional covariance oracle, genuine certified/single/disagreed event records, wrong status/spread/count rejection. New cases 2 tests / 16 expectations pass; diagonal-only covariance mutant and omitted-status mutant each produce three assertion failures. Single corrective final-gate retry running; coverage remains unclaimed until measured. Prior failed gate report retained.

## Final corrective gates PASS — 2026-10-29

Final tested source/test/docs commit 1572e80. Full ordinary suite: 1739 tests / 9185 expectations / 9181 passed expectations / 0 failures/errors / 2 skips / 2 warnings. Skips: unavailable-lavaan guard and load_all help; warnings: deliberate cluster-refit failure and sign-branch disagreement. Required check-local quick tier: PASS 8953 / FAIL 0 / WARN 2 / SKIP 37; built-tarball check Status OK, 0 errors/warnings/notes. Loaded package lint clean. Instrumented coverage 96.07505% overall and 100% new sem-nonzero.R executable line/expression coverage; previously uncovered lines 56/57 each hit once, 223/225/227 each twice. This is measured line/expression coverage, not a general mathematical/global-optimality certificate or exhaustive branch-combination claim. Exact final draft risk_check: high TRUE, missing integer(0).

All required current stage reports end PASS: implementer, qa, gates-pre-docs, docs, implementer-coverage, qa-coverage, gates. Initial FAIL reports/logs retained. Local implementation and verification complete; no push, PR, hosted run, release, deployment or merge performed. Expensive hosted OpenBLAS/full platform checks remain reserved for dev-to-main under current policy. Plan/status-only reconciliation follows tested commit; no source/test changes after final gates.
