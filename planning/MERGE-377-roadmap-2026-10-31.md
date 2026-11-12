# PR #377: roadmap planning merge and cleanup

Date: 2026-10-31 MDT. [PR #377](https://github.com/Data-Wise/medfit/pull/377)
was squash-merged into dev at 2026-10-31T17:14:09Z.

- Reviewed head: `f548dff94cca5ceffaf34e329ad44e82679aab9f`.
- Merge: `da0d9edc395f5d25aaf4d4d443f8b1d4a8694b4a`.
- Reviewed and merged tree: `3b5b4d5c70aa13e178459092a4644e127d1de73f`.
- All three exact-head fast checks passed before merge: lint
  [41222625578](https://github.com/Data-Wise/medfit/actions/runs/41222625578),
  pkgdown [41222625577](https://github.com/Data-Wise/medfit/actions/runs/41222625577),
  risk-tier [41222625584](https://github.com/Data-Wise/medfit/actions/runs/41222625584).
- Prior local fast-tier suite: 9,591 assertions passed, no failures, four
  disclosed warnings and 37 skips; matched-install lint clean. No rerun of
  calculations, simulations or model experiments for merge/cleanup.

Local dev fast-forwarded to the merge. All 16 portable planning-packet checksums
remain valid. The original paired plan remains inactive: existing-model row-
bootstrap/parameter-draw inference comes first, then each of the 11 approved
variants. Q12/Q13 and all FI-B0 prerequisite decisions remain unchanged.
The roadmap and historical evidence receipt remain immutable merged snapshots;
this receipt and .STATUS record their delivery-state change.

The local feature tip matched the PR head exactly, and merge ancestry on dev
was verified before cleanup. The feature branch and worktree were removed;
the remote feature branch was already absent at inspection. Unrelated NEWS
branch, other worktrees, .codex/ and the untracked feasibility report were
preserved. The original inference-design worktree remains untouched.

Seven ignored worktree files and seven local verification files were archived
in `_agents_workspace/roadmap-reconciliation-merged-2026-10-31.zip`; each entry
and the archive SHA-256 were verified. The adjacent `.receipt.json` retains
all hashes. These are local ignored cleanup receipts, not public runtime proof.

Post-merge dev workflow query returned no runs for this merge, consistent with
the configured policy. Coverage is main PRs/main pushes only; expensive CI is
release-only. No manual job, release, deployment or dev-to-main merge occurred.
Metadata reconciliation is committed locally only; another push needs its own
explicit authorization. This merge approves planning publication, not FI-B0
activation or implementation.
