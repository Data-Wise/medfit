# Native-guide bounded FIML fixture correction

Status: complete; PR #371 squash-merged into dev as `04b7ac8c` on 2026-10-30.
Documentation, local gates, user visual acceptance and all three fast hosted checks PASS.
Merged branch/worktree cleanup verified; status reconciliation remains local only.

## Scope and acceptance

- [x] T1 Docs: replace binary-X FIML data with reproducible continuous Gaussian
  random-X data and independent disturbances. Preserve RNG state, explicit opt-in,
  defaults, ignorable missingness and support boundaries. Keep unrelated examples
  unchanged. Add an executable article-code regression guard; verify both entry
  points and detection of a binary-X substitution.
- [x] T2 Render the changed article with this checkout in an isolated library;
  inspect actual HTML and record provenance. Run docs consistency and spelling
  checks. Inventory related help/site prose and correct only real gaps.
- [x] T3 Final local gates: focused checks, full suite, lint, risk classification
  and docs checks. Save exact counts. Reconcile status and commit locally.

## Pipeline and limits

Docs-only: medfit-docs -> medfit-gates (final). Reports:
`_agents_workspace/fiml-native-guide-fixture/{docs,gates}.md`.
Each ends with exactly one `Verdict: PASS` or `Verdict: FAIL`.
One corrective retry after a failed stage, then stop for authorization.
Track new files before rendering. No production R edits or support expansion.
No push, PR, deployment, release, dev-to-main merge, or expensive CI.
Coverage stays main PRs/main pushes only. Preserve unrelated changes.

## Docs-stage progress

Corrected article fixture and executed wrapper; numeric binary-X negative control
and two-entry-point agreement pass (2 tests, 11 assertions). Related docs checks:
92 tests, 677 assertions, zero failures/errors/warnings/skips. Package spelling
reports no errors; bounded Rforge audit has no warnings/errors (12 exports checked;
11 variadic exports unchecked); 20 detailed informational scannability suggestions
are outside this changed section. Isolated medfit source install and full changed
article render exit 0. At this checkpoint browser security blocked local-file
inspection, so user visual acceptance and final gates were pending; the later
receipts below close both without a browser-security workaround.

## Visual acceptance and local gate correction

User accepted the rendered continuous fixture, both API outputs and support table
at 20:30 MDT on 2026-10-30. HTML/assets were paired and individually hash-verified
in the ignored `rendered-article/` workspace before generated originals were removed.
Initial full suite: 1785 tests / 9802 expectations, 9793 passing, 3 failures,
0 errors, 4 warnings, 2 skips. All three failures were the semopy runtime probe;
separate preflight proved a normal uv-cache lock/create permission failure.
No source change was needed. At this checkpoint the one corrective normal-cache-access
full-suite retry was running, with successful semopy preflight; earlier evidence is retained.
Lint, focused gates, build and built-tarball check already pass.

## Final local receipt

Corrective full suite PASS:1785tests,9802total expectations,9796successful
assertions,0failures/errors,4warnings,2skips. Normal uv-cache access resolved
all3initial semopy failures without source changes; only one corrective retry.
Focused final gates9/64, fresh Rforge lint0, build and built-tarball check
Status:OK. See docs.md/gates.md and receipts in ignored workspace.
All T1-T3 complete; user visual acceptance recorded. At the local-gates checkpoint
publication was not authorized. The later publication/merge receipt supersedes that
local-only state. No production/workflow/release changes; coverage remains main-only.

## Publication, merge and cleanup receipt — 2026-10-30

PR #371 targeted dev at exact reviewed head `a1f03ddf0baf8107e022d8add8534acf9d2eb8f0`.
Live lint, pkgdown and risk-tier all passed. Authorized squash merge
`04b7ac8c01ce565e4d23b8052fd5e151d41c6c41` has the identical complete Git tree;
local dev was fast-forwarded and no post-merge dev workflows triggered.
Coverage is main PRs/main pushes only; no coverage run was expected on dev.
No expensive CI, deployment, release or dev-to-main merge occurred.

Before removing the merged local branch/worktree, exact local-tip/PR-head identity
and merge ancestry were verified. The remote feature branch was already absent;
reviewed head remains at `refs/archive/pr-371-head`. All 423 ignored evidence files,
including the paired rendered HTML/assets, were archived and individually SHA-256
and ZIP-CRC verified in `_agents_workspace/fiml-native-guide-fixture-merged-2026-10-30.zip`.
Archive SHA-256: `9ec2a18456a43577a02276e6f7d18459df20465f6978b0fc7cab13f5d668a878`.
The adjacent `.receipt.json` contains the complete per-file hash manifest.
Unrelated untracked files and other worktrees were preserved. Plan/status updates
are local reconciliation only; a separate metadata push needs authorization.
