# Coverage scope maintenance — 2026-10-30

Status: implementation and local review complete; PR/merge pending.
The user authorized publication of this branch on 2026-10-30.
Branch: `codex/coverage-metadata-scope`. Implementation: `23080bcb`.
This note records CI maintenance, not a new numerical implementation plan.

## Behavior and safeguards

- On dev pushes and PRs, skip R coverage only when every changed path is
  `.STATUS`, `CLAUDE.md`, `AGENTS.md`, or Markdown under `planning/`.
- Code, tests, dependencies, workflows, executable docs, planning scripts/data
  and unknown paths retain coverage. Entire push/PR ranges count, including
  deletions and code renamed into a metadata location.
- Main pushes always run coverage. Missing/invalid history, empty diffs and
  scope-job errors run coverage conservatively; cancellation remains respected.
- Metadata-only runs retain workflow/job reporting but upload no Codecov report.
- Release R-CMD-check and OpenBLAS workflows are unchanged. Expensive CI stays
  deferred until release to main. No release or dev-to-main merge is authorized.

## Verification and review

Five Python regression tests and 31 testthat workflow assertions pass locally;
actionlint, R lint and documentation lint pass. Four temporary mutants were
caught: ignoring all planning files, skipping main metadata, losing renamed code,
and including unrelated PR-base changes. No tracked mutations remain.
Local review found no correctness blockers at `23080bcb`.

## Remaining

After the authorized branch publication, obtain authorization for a PR to dev
and check fast hosted CI. Verify the published branch matches the final local
commit before reporting the push complete. Hosted scope behavior is not yet
verified. Do not merge without separate authorization. Existing FIML and 0.16
release holds remain in force.
