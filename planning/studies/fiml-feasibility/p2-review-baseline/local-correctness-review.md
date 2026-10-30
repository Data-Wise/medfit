# Local FIML prototype review

Reviewed commit: c7430172db61e5d690debf46daa36694ca3eb338, branch codex/fiml-feasibility, 2026-10-29.
Read-only repository review. Separate from 0.16. No production edits, push, or hosted/expensive CI.

## Verdict

The bounded numerical kernel and optimizer repairs reproduce successfully. Resolve the two P2 evidence/fixture findings below before freezing completion and advancing to the next milestone. No likelihood, score, observed-Hessian covariance, N scaling, or affine-transport defect was found within the reviewed three-variable random-X Gaussian scope. This conclusion does not validate production integration, arbitrary models, global optima, repeated-sampling coverage, or cross-platform behavior.

## Findings

### P2: Preserve solver attempts when a post-solver gate rejects the fit

Anchor: [fiml-feasibility/prototype.R:229](/Users/davood/projects/r-packages/active/medfit/.worktrees/fiml-feasibility/planning/studies/fiml-feasibility/prototype.R:229); also lines220 and235.
The completed attempt table is included on missing-solver-coverage errors, but discarded by later likelihood-spread, geometry, and information diagnostics. The acceptance harness can only retain an error ledger when e$attempts exists (prototype-acceptance.R:268). This violates the frozen instruction to retain every attempt/status (prototype-protocol.md:56) and makes failed-fit diagnosis incomplete.

Verified with the prescribed no-overlap fixture: the call reached the post-solver geometry gate, raised the expected typed rank-deficiency diagnostic, and had attempts=NULL. Preserve the completed table in all subsequent diagnostics and test that the no-overlap failure carries all six solver/start records. This is an evidence-retention issue; the diagnostic correctly prevents finite-SE success.

### P2: Align the near-singular fixture with its frozen residual SD

Anchor: [prototype-acceptance.R:124](/Users/davood/projects/r-packages/active/medfit/.worktrees/fiml-feasibility/planning/studies/fiml-feasibility/prototype-acceptance.R:124).
study.R:generate creates Y noise with SD0.9. Lines123-124 extract this noise and multiply it by0.03, producing generating residual SD0.027 and variance0.000729. The frozen protocol specifies SD0.03 and variance0.0009. Both free/zero-direct-path cells therefore exercise a different fixture from the one reported. Preserve the historical evidence and explicitly reconcile the actual0.027 construction with the intended0.03 fixture, then rerun any corrected acceptance cells. The mismatch is a fixture/provenance issue, not a demonstrated numerical formula failure.

## Verification

- Fresh local acceptance, outputs redirected to an isolated temporary directory:42/42 fits,13/13 edges,126/126 derivative checks,126/126 likelihood identities,42/42 independent optimizer/information gates. Original reference harness also passed30/30 fits and10/10 edges. Exit0;37.86 seconds.
- An actual in-memory implementation mutation multiplied returned covariance by retained N while leaving repository code unchanged. The full harness rejected all42 fits and exited1. All13 edge checks alone still passed; the primary covariance/SE comparisons provide the decisive protection.
- All110 archived evidence hashes matched before and after review.
- Study branch working tree remained clean; production R/,src/,tests/,.github/,DESCRIPTION have no branch changes against edcf23d8.
- Read implementation, independent likelihood/reference mapping, frozen protocol, current acceptance report, technical record, and historical repair evidence. The full observed-curvature formula, total-likelihood scaling, local-rank/global-identification distinction, and study/production boundaries are accurately described apart from the fixture discrepancy.

## Evidence and next milestone

Fresh run: [/private/tmp/medfit-fiml-review-35c27ba6772b](/private/tmp/medfit-fiml-review-35c27ba6772b)
Mutation run: [/private/tmp/medfit-fiml-mutant-4ee929f5c6a1](/private/tmp/medfit-fiml-mutant-4ee929f5c6a1)
[Fresh execution log](/private/tmp/medfit-fiml-review-run.log)
[Mutation execution log](/private/tmp/medfit-fiml-review-mutant.log)
[Diagnostic reproducer](/private/tmp/medfit-fiml-review-diagnostics.R)

After the two bounded repairs, the appropriate next milestone is a separately authorized integration design with a concrete adopter/use case, explicit FIML/random-X opt-in, preserved existing defaults, and support/rejection rules for downstream APIs. Global optimization, fixed-X FIML, robust/expected SEs, and broad model support remain deferred. Nothing in this review makes FIML part of0.16 or authorizes production implementation.
