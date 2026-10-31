# medfit 0.16.0 GitHub release

Status: active. User authorized “do next and release to github” on 2026-10-30 MDT. This authorizes necessary reviewed feature-to-dev and dev-to-main integration and GitHub publication after required gates, not CRAN submission. Earlier release/expensive-CI deferrals are lifted for this release candidate only; hosted coverage remains main PRs/main pushes only.

- [ ] R1 Check exact-head fast CI and squash-merge reviewed docs PR #372 into dev; preserve unrelated work.
- [ ] R2 Prepare version/date/NEWS/current public references, preserve historical evidence; local source build, full suite, lint, affected docs/book render/content inspection, spelling/URLs and pinned dependent compatibility against v0.15.0. Stop for an unresolved failed stage after one corrective retry.
- [ ] R3 Review/publish candidate feature PR to dev, integrate after exact-head checks; open dev-to-main release PR, require full platform/noSuggests, coverage/Codecov, both OpenBLAS gates and required fast checks. No bypass.
- [ ] R4 Merge release PR with merge commit after live readiness; verify main CI/tree, then tag v0.16.0 and GitHub release using reviewed notes. Verify tagged install and automatic website deployment, reconcile/back-merge/clean only authorized release branches with verified archives/tips/ancestry.

Evidence lives in _agents_workspace/release-0.16/. All claims name exact source/ref and run; current audit counts are pre-candidate only. A green optimizer or numerical fixture is not a global/inferential guarantee. Known #320 external-engine discrepancies must stay flagged and meet existing accepted gate limits. No new FIML models/inference or missingmed adoption; no CRAN work.
