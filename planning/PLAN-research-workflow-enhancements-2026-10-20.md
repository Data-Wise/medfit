# Plan: Source identity and provider evidence for downstream work

Filed 2026-10-20 after explicit user authorization to file the
research-workflow plans.
Status: proposed follow-up; filing only, not implementation or acceptance
evidence.

**Owner:** medfit maintainer; missingmed/RMediation own downstream acceptance.
**Observed local identity:** `feature/factor-gate-registration` at
`dd42073d18bc`. This is a dated
checkout observation, not a release/installed-package assertion; recheck
before execution.

## Scope and holds

Preserve active factor-gate work and current release/CRAN holds.
Preserve unrelated work, current scientific rules, active plans and
per-instance external-action gates.
No simulation, installation, manuscript revision, submission, release or
deployment ran for this filing.
This dated plan supplements existing plans; it does not replace their queue or
certify completion.

## Ordered tasks

### 1. Record separate software identities

- [ ] Plan a restore record of root/worktree, branch/SHA, dirty state, status
      date, source DESCRIPTION, installed library/version if checked, and
      timestamped release evidence.
- **Acceptance:** An older checkout and newer release can coexist; neither
  establishes what is loaded. Unknown identities stay unknown.
- **Verification:** Verify actual owning files and library path during the
  later audit; no installation or release verification is claimed now.
- **Dependency:** None; reconcile existing evidence first.
- **Scope:** one evidence record or bounded correction; split implementation
  if it exceeds five files.

### 2. Provide pinned provider evidence

- [ ] Read the current native SEM/factor-gate plan and select only the
      exported extraction/likelihood behavior needed by missingmed and
      RMediation.
- **Acceptance:** Support limits, covariance/mean settings, union-null
  branches, convergence and numerical oracles are explicit; no
  optimizer-success-only acceptance.
- **Verification:** Reuse current constraint/Jacobian/Hessian and all-row
  gates if native SEM code later changes; do not duplicate their
  implementation.
- **Dependency:** Task 1; retain the existing project approval gates.
- **Scope:** one evidence record or bounded correction; split implementation
  if it exceeds five files.

### 3. Close downstream and documentation claims

- [ ] Prepare an evidence handoff with exact ref, public API, focused oracle
      result and documentation location for each consumer.
- **Acceptance:** Current GitHub/CRAN/r-universe/installed states are
  distinguished; release or CRAN holds are not inferred complete from local
  checks.
- **Verification:** Later code changes require project document/test/check and
  dependent checks; inspect pkgdown guidance after functionality changes.
- **Dependency:** Task 2; retain the existing project approval gates.
- **Scope:** one evidence record or bounded correction; split implementation
  if it exceeds five files.

## Checkpoint and first action

- [ ] After tasks 1–2, reconcile evidence and unresolved decisions before
      beginning task 3.
- [ ] Record actual verification and remaining owner decisions; do not tick
      future execution from this filing.

**First action:** the named maintainer reads the existing evidence in task 1
and reconciles its
residual scope with the current owning plan. Stop if evidence conflicts or a
scientific/author
decision is unresolved; name that decision rather than silently changing the
plan.

## Coordination

- [Shared Savant enhancement plan][ref1] owns reusable command/skill work.
- [missingmed companion plan][ref2] owns its repository changes.
- [RMediation companion plan][ref3] owns its repository changes.
- Future execution must follow this repository's instructions, tests, artifact
  checks and branch model.

[ref1]: </private/tmp/savant-simulation-completeness/tasks/plan-research-workflow-2026-10-20.md>
[ref2]: </Users/davood/projects/r-packages/active/missingmed/docs/PLAN-research-workflow-enhancements-2026-10-20.md>
[ref3]: </Users/davood/projects/r-packages/active/RMediation/tasks/PLAN-research-workflow-enhancements-2026-10-20.md>
