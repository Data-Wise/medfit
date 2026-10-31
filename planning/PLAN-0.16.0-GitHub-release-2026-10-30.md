# medfit 0.16.0 GitHub release

Status: active. User authorized “do next and release to github” on 2026-10-30 MDT. This authorizes necessary reviewed feature-to-dev and dev-to-main integration and GitHub publication after required gates, not CRAN submission. Earlier release/expensive-CI deferrals are lifted for this release candidate only; hosted coverage remains main PRs/main pushes only.

- [x] R1 Check exact-head fast CI and squash-merge reviewed docs PR #372 into dev; preserve unrelated work.
- [x] R2 Prepare version/date/NEWS/current public references, preserve historical evidence; local source build, full suite, lint, affected docs/book render/content inspection, spelling/URLs and pinned dependent compatibility against v0.15.0. Stop for an unresolved failed stage after one corrective retry.
- [ ] R3 Review/publish candidate feature PR to dev, integrate after exact-head checks; open dev-to-main release PR, require full platform/noSuggests, coverage/Codecov, both OpenBLAS gates and required fast checks. No bypass.
- [ ] R4 Merge release PR with merge commit after live readiness; verify main CI/tree, then tag v0.16.0 and GitHub release using reviewed notes. Verify tagged install and automatic website deployment, reconcile/back-merge/clean only authorized release branches with verified archives/tips/ancestry.

Evidence lives in _agents_workspace/release-0.16/. All claims name exact source/ref and run; current audit counts are pre-candidate only. A green optimizer or numerical fixture is not a global/inferential guarantee. Known #320 external-engine discrepancies must stay flagged and meet existing accepted gate limits. No new FIML models/inference or missingmed adoption; no CRAN work.

## R1 integrated; R2 local candidate checks — 2026-10-30 MDT

PR #372 squash-merged as d5785171215fcf2d04e5219286de9d05e6c5b6bf after exact c8027dbd head passed lint, pkgdown and risk-tier. Reviewed-head and merged-tree identity match; local dev fast-forwarded preserving unrelated untracked files. Candidate runtime expressions are unchanged by version/docs stamping.

Candidate suite: 1,785 tests / 9,796 successful assertions, zero failures/errors, four explained warnings and two explained skips. Lint zero, spelling clean, full site/book exit0, 47 URL checks clean. Actual rendered inspection found a README source-path link; corrected to the live native-guide HTML URL (HTTP200), rebuilt homepage and passed 33 focused docs tests / 285 assertions. One rebuild command rejected an unsupported pkgdown argument before rendering; the corrected API call succeeded, with logs preserved. Final 20 HTML files pass content/local-link inspection; no browser-visual or live-version claim. Fresh rebuilt source check Status: OK. Pinned baseline/candidate dependent comparisons are finishing; R2 is not complete until their results are inspected. See issue-disposition.md for bounded follow-ups, without automatic issue closure.

### R2 complete

Five pinned actual dependent-package suites (RMediation, probmed, missingmed, mediationverse, medsim) pass against published0.15.0 and candidate0.16.0: 1,782 tests / 7,216 passing assertions per arm, zero failures/errors and no new per-test failures; baseline warning/skip vectors match. medrobust's pinned DESCRIPTION and all R/test source contain no medfit reference, so its mistakenly started independent sensitivity-grid suite was stopped, not counted as compatibility evidence. No dependent source/tests changed. Final rebuilt archive check Status: OK, required nonlinear gate byte-identical, planning/book/workspace excluded. Exact heads/results and scope receipt retained. R3 hosted gates pending.
