# Bounded FIML regression-oracle milestone

Status: T1 repair, T2 re-QA and pre-docs gates PASS; docs PASS; final gates pending. Date: 2026-10-30.
Branch: codex/fiml-regression-oracles. Base: origin/dev c4b76fb5, plus the
reviewed local planning commits. No push, PR, merge, release or expensive CI.

## Scope and authority

The user authorized the bounded regression milestone following the
[A1 inventory](AUDIT-FIML-regression-inventory-2026-10-30.md).
The detailed numerical acceptance contract is A1 of
[the readiness plan](PLAN-FIML-release-and-missing-data-followups-2026-10-30.md).
This milestone adds test evidence, not new FIML support or release requirements.
No production changes are planned. Report any discovered defect before expanding
scope; never weaken a tolerance or bypass an acceptance gate.

## T1: Manifest and discriminating regression cases

- [x] Commit a fixture manifest before candidate fits: deterministic input
  identity, roles/model, rows/pattern counts, independent expected rank and
  conditioning, parameter mappings, transformations, refusal reason and limits.
- [x] Preserve the pair-only no-complete-row oracle gate and existing singleton,
  route-equivalence, no-RNG, zero-origin and evidence-ledger checks.
- [x] Add only missing observed-X MAR, all-seven-patterns plus empty-row,
  joint-affine and genuinely near-singular estimable fixtures; cover free/zero
  direct paths where parameterization differs.
- [x] Strengthen the existing actual no-overlap refusal with independently
  deficient rank, exact numerical stage/reason, and genuine retained attempts.
- [x] Compare production and independent row-wise Gaussian likelihoods at
  declared common parameters and fitted optima. Match lavaan random-X means,
  observed information and full covariance; affine back-transport includes
  intercepts, covariance and likelihood Jacobian.
- [x] Preserve limits: absolute coefficient error 1e-5, standardized full
  covariance error 1e-3, absolute NLL error 1e-7. Report all cases and independent
  normalized information/observable-moment spectra; production gate remains
  1e-4. Do not relax limits after inspecting outcomes.

Ownership: implementer owns new/updated FIML tests, bounded simulation gate,
fixture manifest and implementation report. Use public fits for regression
cases; a test-only internal objective evaluation can check fixed parameters.
Tests do not prove MAR, confidence-interval coverage or global optimality.

## T2: Independent oracle QA

- [x] Independently verify likelihood algebra, parameter/covariance transport,
  rank/refusal and all-row results; compare numeric neutrality to origin/dev.
- [x] Plant discriminating defects and demonstrate detection. Keep independent
  oracle construction separate from production helpers being checked.
- [x] Record qa.md with exactly one final Verdict: PASS or Verdict: FAIL.

## T3: Local verification and records

- [ ] Run required risk/checklist, focused tests/simulation gates, lint and
  documentation-consistency checks, then one full suite on the final tree.
  Required numerical gates remain binding; no hosted or expensive CI.
- [ ] Update NEWS and technical testing notes to describe the added evidence
  without broadening support. Run docs stage if these changes are made, followed
  by final gates. Reconcile this plan and .STATUS with actual results.
- [ ] Commit scoped changes and stop locally for review; no external submission.

## Pipeline and failure handling

Follow medfit-orchestrator: implementer -> independent oracle QA -> pre-docs
local gates -> docs (testing notes/NEWS only) -> final local gates. Reports live
in _agents_workspace/fiml-regression-oracles/. Every required report must end
in exactly one final Verdict: PASS or Verdict: FAIL. Retry a failed stage once;
stop after its retry fails. Do not omit a failed required stage or silently
change the numerical fixture to avoid its stated purpose.

## Implementation checkpoint — 2026-10-30

Manifest committed before fitting as `1893403`. First run failed an independent
finite-difference Hessian diagnostic because relative steps around near-zero
intercepts caused cancellation. Calibration against independently transported
lavaan information supported zero-centered fixed steps, without input/limit
changes. Retry passed all 116 numerical assertions across ten cells, but its
final CSV write failed because testthat changed the working directory and the
evidence path was relative. This is a failed stage retry, not a PASS. A direct
numDeriv test dependency is also undeclared. Stop here; repair the evidence path
and replace derivatives with a base-R independent helper under renewed harness
repair authorization before another candidate run. Independent QA and gates have
not started. Detailed logs/report are in the ignored task workspace.

## Authorized harness repair and renewed implementation — 2026-10-30

The earlier FAIL checkpoint remains archived in the task workspace. Under renewed
user authorization, all direct numDeriv usage was replaced with test-only base-R
central differences and four Richardson levels. Fixed zero-centered steps .01
and .005 were calibrated before renewed candidate fits against independently
transported lavaan observed information: 12 probes across MAR/patterns/near,
free/zero, maximum relative discrepancy 5.43706e-6. Inputs, manifest identities
and numerical limits remain unchanged. Affine references share MAR base data.

The renewed first candidate run passed: 10 tests, 116 successful expectations,
0 failed, 0 errors, 0 skips, 2 expected lavaan empty-row warnings. An absolute
CSV destination now records all ten cells; relative destinations are explicitly
rejected. Exact errors and normalized spectral extrema are retained in
`fixtures/fiml-regression-results-2026-10-30.csv`; calibration receipts are in
`fixtures/fiml-regression-derivative-calibration-2026-10-30.csv`.
Fast harness: 3 tests/10 expectations PASS, including four planted-corruption
checks. Existing pair-only, singleton, route, RNG and provenance tests and the
bounded simulation gate were preserved unchanged; their reruns remain part of
local gates. Independent QA, numerical-neutrality review and local gates have
not started. No production change, push, PR, merge or hosted CI.

## T2 independent QA stopped — 2026-10-30

Ten fresh common-parameter likelihood/rank/input-identity probes passed. Three
fresh accepted public fits (MAR/free, affine/zero, near/free) agreed with lavaan;
the unidentified/zero control gave its exact numerical refusal and retained
attempts. Production constant and intercept-transport mutants were detected;
covariance transport corruption failed at the adapter, and rank-guard bypass
returned a fit that violates the existing exact-refusal assertion.

The QA driver failed twice on its own assumptions: unnamed affine coefficient
order, then expecting the rank-bypass mutant to give another error rather than
accept a fit. Execution stopped after that retry. The regression comparison also
omits the required expected parameter-set/multiplicity assertions before
reference subsetting. No numerical acceptance limit or production source changed.
See `_agents_workspace/fiml-regression-oracles/qa.md` and preserved initial/retry
logs. T2 is FAIL; repair/re-QA requires the bounded parent handoff before gates.

## Authorized T1 QA-finding repairs — 2026-10-30

Added an independent free-nine/zero-eight public parameter contract. Candidate
and raw lavaan coefficients and covariance rows/columns must each have exact
sets, counts and no duplicates before reference indexing or affine transport.
Fast regressions reject dropped/duplicated/extra coefficients and malformed
covariance dimensions/names. Evidence schema rejects missing, duplicate or
extra columns. The exact ten-cell CSV now includes normalized model-covariance
minimum/maximum eigenvalues: at the reference optimum for accepted cells, and
explicitly labeled generating parameters for unidentified controls.

First repair run passed: 10 tests/132 successful assertions, 0 failed, 0 errors,
0 skips, 2 expected empty-row warnings. Fast harness: 5 tests/31 assertions,
0 failed/errors/warnings/skips; scoped lint clean. Every prior numerical CSV
field is unchanged. Fixtures, manifest identities, limits and derivative code
are unchanged, so the earlier twelve-probe calibration was reused. Prior reports
and receipts remain archived. The QA-owned probe is untouched; independent
re-QA and local gates remain pending. No production edits or external action.

## T2 re-QA and pre-docs reconciliation — 2026-10-30

Independent re-QA at `f23b69d5` passed, superseding the stopped T2 verdict
above while preserving it and its logs. Fresh parameter/schema defects and all
ten model-covariance spectra passed; completed earlier numerical probes were
explicitly reused. Four real production mutations and two validator mutations
were detected in memory. No production source changed.

Pre-docs gates passed 117 tests/1245 assertions, zero failures/errors/warnings,
one documented help-availability skip, 24/24 FIML simulation rows and zero lints.
Exact-source ten-cell implementation evidence was reused (10 tests/132 passed
assertions, two expected warnings). NEWS and the manifest post-run section now
record the test-only evidence. Docs checks passed: 85 tests/849 assertions, one
help-availability skip, no failures/errors/warnings; spelling passed after expanding
two existing NEWS abbreviations on the one retry. No Quarto article changed, so
rendering is inapplicable. The final full suite and final T3 completion remain
pending. No push, PR, merge or hosted CI.
