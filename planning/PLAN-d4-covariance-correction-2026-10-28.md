# D4 covariance correction

## Follow-up: covariance edge coverage (2026-10-28)

Add covr-executed regression tests for the all-parameters-pinned zero covariance and projected-singular-information
warning/NA branches in `R/sem-se.R`. Assert full parameter names and multiplicity, exact structural zeros, warning
semantics, and absence of a typed covariance failure for singular information. Use independent mathematical controls
and planted defects; do not change production behavior or weaken existing assertions.

- [x] Edge regression tests and scoped commit.
- [x] Independent QA and planted-defect checks.
- [x] Required local gates.
- [x] Push the test update to PR #358, rerun hosted coverage, and verify both lines are covered.

PR #358 squash-merged into dev as `b9af937a` on 2026-10-28, after the author authorized the merge and all live
checks passed at head `dc575a11`. Earlier OpenBLAS evidence remains attributed to `cf7cfb4`; it was not rerun
on the later test-only head. No release or submission is authorized.

Final follow-up local gates on `f4306e6`: 1717 tests, 9043 recorded expectations, 9040 passed, 0 failures/errors,
2 skips and the known planted cluster warning; loaded lint 0. The same run includes D4 5 tests/170 expectations,
docs consistency 92/902 (1 skip), and gate coverage/ADR 7/52. Mandatory local built-tarball gate: 8812 passed,
0 failures, 1 warning, 37 skips; R CMD check Status: OK (tests 136s, check 25s). Independent QA and local
instrumented coverage verify four hits each on sem-se.R lines 52 and 69. Hosted coverage on `dc575a11` passes:
96.38% overall (8597/8919 lines), 97.82% patch; both target lines are covered, with `R/sem-se.R` at 94.62% (88/93).
Coverage run: 40820743419. Local hit counts are not hosted hit counts.
Ignored evidence (300 files) was byte-verified and archived before worktree cleanup at
`_agents_workspace/d4-covariance-correction-merged-2026-10-28.zip`, with a companion SHA-256 receipt.

Status: complete and merged into dev, 2026-10-28. Merge: b9af937a. Owner: medfit.

CI policy: expensive OpenBLAS simulation gates and the full platform matrix remain on dev-to-main release PRs.
Dev PRs retain fast Ubuntu coverage, lint, risk-tier and pkgdown checks. Existing monthly/manual QC stays available;
no expensive rerun is needed for this metadata-only closeout.

## Task: constrained covariance and typed diagnostics

Correct observed-information covariance for active nonlinear constraints using the projected Lagrangian Hessian, with correct scaling and centered-coordinate mapping. Preserve expected-information semantics and calculate sandwich covariance with the corresponding bread and casewise score meat. Document that active-inequality covariance is a local tangent approximation, not a general boundary sampling distribution.

Implement D4(b): only explicitly raised, validated `medfit_sem_covariance_diagnostic` conditions are retained as likelihood-ratio evidence; propagate other covariance errors unchanged across fits, branches and MBCO. Preserve singular-information warning plus NA covariance. Validate ledger payloads and preserve D-11 precedence.

Test first: independent reparameterized Gaussian likelihood oracles for nonlinear equality, including weighted mean structure, observed, expected and sandwich; inactive inequality and active boundary controls; negative-branch regression; preserve structural zeros. Include failure injection, planted defects and metamorphic tests. Use existing draft `_agents_workspace/d4b/draft-test-sem-covariance-diagnostic.R` as untested input, not authority. Earlier probes: `/private/tmp/medfit-d4-oracle.R`, `/private/tmp/medfit-d4-extended.R`, `/private/tmp/medfit-d4-probe.R`.

Acceptance: independent QA of all changed numerical contracts; targeted tests, native SEM constraint/Jacobian/Hessian, all-row acceptance, zero-product branch and restart gates; relevant simulation gates and planted mutants; full suite, lint, documentation consistency, package check, and risk-tier checklist. Record actual results and limitations. Docs: NEWS, public help, guides/site, `.STATUS`. OpenBLAS platform verification must not be claimed unless run. No push, PR, merge or release without separate authorization.

- [x] Implementation and oracle tests.
- [x] Independent oracle QA and defect checks.
- [x] Required local gates and documentation.

Implementation follow-up complete: effective solver bounds reach covariance; active floors are covered across information
and SE types and branch refits; the nonlinear SE gate uses a reparameterized likelihood Hessian. Independent QA and the
mutation-hook audit pass. Pre-docs gates pass (763 tests, 4801 expectations; 84/84 simulation checks; all 26 engine
mutants and 68 driver mutations caught). Documentation checks and five source-pinned article renders pass. Final
full suite on 65f90b33: 1716 tests, 9011 recorded expectations, 9008 passed, 0 failures/errors, 2 skips and 1 planted
cluster-warning result reproduced on dev; loaded lint 0. Documentation consistency: 92 tests, 902 expectations,
0 failures/errors, 1 skip. The mandatory local built-tarball gate passes: quick tier 8780 pass, 0 failures, 1 warning,
37 skips; R CMD check Status: OK. Status/plan-only completion updates are excluded from package builds.

Finite-difference limits remain: the extreme-floor independent observed/model and observed/sandwich normalized
covariance errors are about 1.48e-5 and 1.39e-4; the local tangent approximation is not an unconditional boundary
sampling law. At the initial local completion stage, coverage and hosted verification had not run. The subsequently authorized
PR #358 is merged into dev as `b9af937a`. Hosted OpenBLAS QC at `cf7cfb4` passed 24 gates/155 checks; updated
coverage at `dc575a11` is 96.38% overall and 97.82% patch, with both edge branches covered. Full critical-path
coverage is not asserted. The feature worktree's ignored reports and raw evidence are preserved in the verified
archive named above. No release or submission was performed.
