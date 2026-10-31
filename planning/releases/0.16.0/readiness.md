# medfit 0.16.0 GitHub release readiness

Status: authorized release preparation; not cleared for publication. Snapshot: 2026-10-30 MDT.

The user authorized “do next and release to github.” The active plan is planning/PLAN-0.16.0-GitHub-release-2026-10-30.md. This supersedes the packet's earlier preparation-only authorization boundary. CRAN remains out of scope. Coverage remains main PRs/main pushes only; full release CI is required on the main-targeting candidate.

## Source and scope

- Published baseline: v0.15.0 / main e068d7506c6263dcda7f5485c09f892249165fbf.
- Preparation starts at docs-audit head c8027dbd0f630a848a4a8f814b46fd659ffa7e16; PR #372 targets dev. It merged as d5785171215fcf2d04e5219286de9d05e6c5b6bf after all three exact-head fast checks passed; merged/reviewed trees match.
- Candidate DESCRIPTION is stamped 0.16.0 / 2026-10-30. NEWS and current help, articles and minibook references are promoted; historical version references stay historical.
- Bounded FIML, D4 covariance correction, sign-branch fitting and regression evidence are included. Broader FIML models, fixed-X, weights, expected/robust SEs, FIML bootstrap/profile/MBCO, new diagnostics APIs and missingmed adoption remain separate milestones.
- Open #320 concerns flagged external-engine discrepancies; the actual candidate must satisfy existing accepted gate limits. An open issue alone neither establishes a new defect nor waives a failing gate. Classify residual #369/#249/#357/#360 clauses against their merged evidence before final publication.

## Evidence and remaining gates

The pre-candidate docs audit passed 1,785 tests / 9,796 assertions, lint and built-package check. Its ten HTML artifacts were content/link inspected; this is not a visual or live-site review, nor a fresh candidate pass. Candidate receipts are saved separately under _agents_workspace/release-0.16/.

1. Integrate PR #372 after live exact-head fast checks.
2. Verify this version-stamped source: full local suite, lint, build/built check, affected site and book render/content inspection, spelling/URLs, and pinned dependent-package comparison against v0.15.0. Record actual counts and explain warnings/skips. New unexplained failures stop release.
3. Review and publish candidate PR to dev; squash after fast checks. Open dev-to-main release PR and require full platform/noSuggests, both simulation shards, coverage/Codecov and all applicable fast checks on its exact head. No bypass.
4. Merge dev into main with a merge commit only after readiness; verify main CI and tree before tag v0.16.0 / GitHub publication using reviewed notes.
5. Verify tagged archive/install and automatic website deployment; then reconcile/back-merge and clean only verified release branches, preserving unrelated changes and worktrees.

## Stop and rollback

An unexplained numeric/default/capability/dependent regression or missing gate stops publication. After a failed stage and one corrective retry, stop for direction. Before publication preserve the existing tag/main release. Never move a published tag or force main; a later defect needs a reviewed correction or explicitly authorized revert. Completion requires main CI, tagged install and live documentation verification.

## Local candidate gate receipt

1,785 tests / 9,796 assertions, zero failures/errors, four explained warnings and two skips; lint zero, spelling/47 URLs clean; full site/book exit0; 20 HTML content/link inspections (not browser-visual). Corrected homepage guide link; finaldocs33tests/285assertions PASS. Rebuilt source Status:OK. Five actual dependent suites pass both pinned versions (1,782tests/7,216assertions each, no new failures); medrobust has no medfit dependency at its pinned source and its extra unrelated suite was stopped, not counted. Detailed hashes/warnings/scope receipt saved in ignored workspace. Hosted release clearance pending.
