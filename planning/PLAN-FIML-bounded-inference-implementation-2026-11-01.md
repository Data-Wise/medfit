> **Current checkpoint (2026-11-01):** Local FI-B1/FI-B2 implementation, independent QA, docs and final gates PASS. Renewed suite: 1802 tests, 8983 passing expectations, zero failures/errors; coverage 96.31213% overall and 158/158 changed critical expressions; source supplement 497 tests, one skip; lint clean and package check OK. Statistical admission remains deferred. Implementation is local; integration requires separate authorization. Earlier failure, worker-limit and preregistration deviations are historical and retained below.
> Earlier status statements below are historical where inconsistent with this checkpoint.

# Bounded existing-model FIML interval implementation

Date: 2026-11-01 MST. State: **local implementation committed; final verification blocked; correction allowance exhausted**.
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

- [x] Implement test-first, preserving legacy positional/callback contracts, optional versioned metadata,
  source immutability, early guards and supported data/extraction behavior.
- [x] FI-B1: explicit source-fit route for retained incomplete-row percentile intervals, identical-model
  accepted refits, complete requested replicate ledger, no survivor intervals through any accessor.
- [x] FI-B2: joint canonical original-coordinate Gaussian parameter draws with the reviewed symmetric
  correlation-root convention, exact fixed zeros and zero extra refits; accurate method labels.
- [x] Independent QA: six complete/MCAR/observed-X MAR source cells crossed with free/zero direct path,
  twelve paired resamples per cell (156 native/lavaan source-plus-resample invocations), rowwise
  likelihood/score/Hessian/covariance checks, manual effects/type-7 quantiles, mutants and invariance.
- [x] Pre-docs gates: focused/API/docs-consistency tests, applicable native gates and lint.
- [x] Docs: roxygen/Rd, NEWS, support matrix and existing FIML minibook example; verified supported scope,
  assumptions, calibration limits and strict failure output. Statistical admission is explicitly pending.
- [x] Final gates: one full suite on the final tree, package check/documentation verification, evidence counts.
- [x] Reconcile roadmap/status and scoped commits; prepare concrete integration packet. No push/PR/merge yet.

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

Implementation checkpoint: `e82d1a3`, interruption correction `123994c`, message-only correction `cb3de1c`.
Independent QA (`13f8c17`) passes all 78 paired native/lavaan comparisons (156 public fit calls),
independent likelihood/score/Hessian/covariance checks, joint draws, mutants and interruption/accessor contracts.
Pre-docs gates pass 251 tests/1210 expectations, lint zero and 24/24 existing FIML gate rows.
Docs (`4ac4585`) pass 88 tests/667 expectations, spelling/lint and seven executed HTML renders/content inspections.
Final gates failed; the implementation is not merge-ready. Statistical admission remains deferred.

Verification deviation: two initial bootstrap-article render attempts executed an existing four-worker example,
exceeding the two-worker limit. Their complete commands consumed 1.760/8.525 wall and 2.633/11.990 CPU seconds;
the four-worker subchunk duration is unavailable. No compliant-full-run claim is made. All 82 rendered chunks were
then audited, both parallel examples set explicitly to two workers, numerical threads pinned to one, and the seven
renders passed. The failed attempts remain in the cumulative ledger; no budget reset or statistical study occurred.

## Current blocker and bounded continuation proposal

The first instrumented installed suite ran 1793 tests: 8930 passed expectations, two failed,
zero errors, four warnings and 129 skips (mostly unavailable source artifacts or explicit coverage guards).
Both failures compare source-object serialization. Every source property is unchanged; the changed bytes are
in the instrumented S7 constructor descriptor. Overall coverage recovered from the retained trace is 96.15308%.
No numerical assertion failed. Source-only checks, final lint and tarball check remain pending.

The second correction added automatic failure-path tests and a stronger semantic source snapshot. Its last
focused instrumented run passes 135/137 expectations and covers 134/134 expressions in `R/bootstrap-fiml.R`
plus both changed summary-print expressions. Two snapshot assertions still serialize private closure flags
nested in validator body/source-reference metadata. Twenty mutation controls and four saved-source invariance
assertions pass, but that does not turn the instrumented failure into PASS. The prescribed agent retry failed;
the correction allowance is exhausted at 12/12 actual native fixture calls, zero lavaan or matrix reruns.
The three test/helper drafts and their new work declaration remain uncommitted; no production behavior changed.
See `_agents_workspace/fiml-bounded-inference/{implementer,gates}.md` for exact commands and failure paths.

One final-gate diagnostic source fit was message-declared before execution but committed in its receipt only
afterward; this preregistration deviation is recorded in `fixtures/FI-B-final-gates-diagnostic-2026-11-01.md`.
The correction work declaration was written before its attempts and remains outside the index with the draft.
No claim of complete preregistration or worker-limit compliance is made.

Maintainer decision required before more implementation/verification: permit one narrow helper correction
that compares validator code/source references structurally rather than serializing runtime closure flags,
retaining all property, attribute, constructor-identity and planted-mutation checks; allow at most four extra
existing-fixture native calls for one focused instrumented proof, then independent saved-artifact QA and a
renewed final suite/package gates if that proof passes. Keep the original cumulative time caps, two workers,
frozen matrix and all numerical tolerances. No statistical admission, study or external integration is proposed.
