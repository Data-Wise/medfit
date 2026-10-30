# Bounded FIML regression-oracle milestone

Status: T1 implementation PASS; independent QA and local gates pending. Date: 2026-10-30.
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

- [ ] Independently verify likelihood algebra, parameter/covariance transport,
  rank/refusal and all-row results; compare numeric neutrality to origin/dev.
- [ ] Plant discriminating defects and demonstrate detection. Keep independent
  oracle construction separate from production helpers being checked.
- [ ] Record qa.md with exactly one final Verdict: PASS or Verdict: FAIL.

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
