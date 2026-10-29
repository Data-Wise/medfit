# D4 covariance correction

Status: active, 2026-10-28. Base: dev 10b93d00. Owner: medfit.

## Task: constrained covariance and typed diagnostics

Correct observed-information covariance for active nonlinear constraints using the projected Lagrangian Hessian, with correct scaling and centered-coordinate mapping. Preserve expected-information semantics and calculate sandwich covariance with the corresponding bread and casewise score meat. Document that active-inequality covariance is a local tangent approximation, not a general boundary sampling distribution.

Implement D4(b): only explicitly raised, validated `medfit_sem_covariance_diagnostic` conditions are retained as likelihood-ratio evidence; propagate other covariance errors unchanged across fits, branches and MBCO. Preserve singular-information warning plus NA covariance. Validate ledger payloads and preserve D-11 precedence.

Test first: independent reparameterized Gaussian likelihood oracles for nonlinear equality, including weighted mean structure, observed, expected and sandwich; inactive inequality and active boundary controls; negative-branch regression; preserve structural zeros. Include failure injection, planted defects and metamorphic tests. Use existing draft `_agents_workspace/d4b/draft-test-sem-covariance-diagnostic.R` as untested input, not authority. Earlier probes: `/private/tmp/medfit-d4-oracle.R`, `/private/tmp/medfit-d4-extended.R`, `/private/tmp/medfit-d4-probe.R`.

Acceptance: independent QA of all changed numerical contracts; targeted tests, native SEM constraint/Jacobian/Hessian, all-row acceptance, zero-product branch and restart gates; relevant simulation gates and planted mutants; full suite, lint, documentation consistency, package check, and risk-tier checklist. Record actual results and limitations. Docs: NEWS, public help, guides/site, `.STATUS`. OpenBLAS platform verification must not be claimed unless run. No push, PR, merge or release without separate authorization.

- [x] Implementation and oracle tests.
- [x] Independent oracle QA and defect checks.
- [ ] Required gates and documentation.

Implementation follow-up complete: effective solver bounds reach covariance; active floors are covered across information
and SE types and branch refits; the nonlinear SE gate uses a reparameterized likelihood Hessian. Independent QA and the
mutation-hook audit pass. Pre-docs gates pass (763 tests, 4801 expectations; 84/84 simulation checks; all 26 engine
mutants and 68 driver mutations caught). Documentation checks and five source-pinned article renders pass; final
gates, including the full suite and package check, remain pending. Hosted OpenBLAS verification has not run;
no push, PR, merge or release is authorized.
