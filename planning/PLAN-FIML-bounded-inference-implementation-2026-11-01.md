# Bounded existing-model FIML interval implementation

Date: 2026-11-01 MST. State: **active; local implementation and verification authorized**.
Execution base: dev `5e845007`, planning PR #378 merged. Branch: `feature/fiml-bounded-inference`.
The maintainer explicitly authorized status repair, implementation/QA owner assignment and bounded implementation.
This authorization does not extend the earlier planning-only push/PR/merge permission to implementation.
Statistical admission, simulations, timing pilots, model expansion, release and CRAN remain deferred.

## Owners and current authority

- Accountable coordinator and planning/status owner: Codex (root).
- Code and test implementation owner: `medfit-implementer` stage, task `bounded_implementer`.
- Independent numerical QA owner: `medfit-oracle-qa` stage, task `bounded_qa`.
- Gate owner: `medfit-gates` stage, task `bounded_gates`.
- User-facing documentation owner: `medfit-docs` stage, task `bounded_docs`.
- Maintainer: statistical admission, external integration and release decisions.

The [reviewed checklist](DECISION-FI-B0-existing-model-inference-2026-10-31.md) supplies the API,
retention/failure/accessor contracts, covariance factor, tolerances and verification limits.
The [paired plan](PLAN-FIML-inference-and-observed-models-2026-10-31.md) supplies independent
oracles and preserved Q10-Q13 admission gates. The roadmap current board owns priorities.
The active plan owns task state; no stage is complete merely because implementation runs.

## Task FI-B-IMPL: both bounded interval methods

- [ ] Implement test-first, preserving legacy positional/callback contracts, optional versioned metadata,
  source immutability, early guards and supported data/extraction behavior.
- [ ] FI-B1: explicit source-fit route for retained incomplete-row percentile intervals, identical-model
  accepted refits, complete requested replicate ledger, no survivor intervals through any accessor.
- [ ] FI-B2: joint canonical original-coordinate Gaussian parameter draws with the reviewed symmetric
  correlation-root convention, exact fixed zeros and zero extra refits; accurate method labels.
- [ ] Independent QA: six complete/MCAR/observed-X MAR source cells crossed with free/zero direct path,
  twelve paired resamples per cell (156 native/lavaan source-plus-resample invocations), rowwise
  likelihood/score/Hessian/covariance checks, manual effects/type-7 quantiles, mutants and invariance.
- [ ] Pre-docs gates: focused/API/docs-consistency tests, applicable native gates and lint.
- [ ] Docs: roxygen/Rd, NEWS, support matrix and existing FIML minibook example; verified supported scope,
  assumptions, calibration limits and strict failure output. Statistical admission is explicitly pending.
- [ ] Final gates: one full suite on the final tree, package check/documentation verification, evidence counts.
- [ ] Reconcile roadmap/status and scoped commits; prepare concrete integration packet. No push/PR/merge yet.

## Verification budget and fixture freeze

The pre-execution [implementation fixture freeze](fixtures/FI-B-implementation-freeze-2026-11-01.md)
records all six deterministic sources and the separately bounded implementation unit work.

Cumulative local verification ceiling: four elapsed hours, eight aggregate CPU hours, at most two workers.
The focused six-cell matrix is limited to 90 elapsed minutes and two aggregate CPU hours within that ceiling.
Count test/oracle/package/docs verification attempts cumulatively; stop at the first exhausted ceiling,
preserve partial results and request a scoped amendment. No tolerance weakening or silent budget resets.
Before execution, the implementer records deterministic fixture constants, seeds, retained/collected counts,
small failure/draw fixture work counts and planned commands here or in a linked tracked fixture manifest.
Independent QA preserves that freeze and logs every matrix row, including failed/invalid fits.
Record command wall/child-CPU usage in `_agents_workspace/fiml-bounded-inference/verification.jsonl`.
Existing package tests are included in the overall cap. No timing pilot or statistical study is permitted.
A failed oracle returns to the implementer with all findings, at most two QA correction loops.

## Acceptance and delivery boundary

Every required stage writes a nonempty report with exactly one last-line `Verdict: PASS` or `Verdict: FAIL`.
Numerical tests establish fixture-level implementation correctness; they do not establish interval coverage.
Delivery states remain separate: local implementation, QA, merged-dev, merged-main, released.
All eleven future model variants and the separate efficiency baseline remain unchanged.
