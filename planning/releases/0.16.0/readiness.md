# medfit 0.16.0 GitHub release preparation

Status: materials prepared locally; NOT a cleared or version-stamped release candidate.
As of 2026-10-30 MDT. No push, PR, release, main merge, deployment or expensive CI.

## Pinned state

- Latest published GitHub release: v0.15.0, published 2026-10-27 UTC. Its commit and origin/main are e068d7506c6263dcda7f5485c09f892249165fbf.
- Live origin/dev: efbba6651c74a52f85cdb0276d59b0d038ebf819; 38 commits ahead of main.
- Completed unpublished docs audit: codex/fiml-docs-audit, c8027dbd, with tested docs d29421a5fee8dad2eea17bdadadb00488b7a020f. This preparation branch starts at that audit tip; it does not imply dev integration.
- DESCRIPTION remains Version 0.15.0 / Date 2026-10-25. No v0.16.0 remote tag exists; no 0.16 release PR is open. The only open PR at inspection is unrelated Dependabot #346.
- Main-to-preparation diff has 279 paths; most added lines are archived planning CSV evidence. .Rbuildignore excludes planning/book/workspace artifacts; retain source-tarball verification on the actual candidate. A large evidence diff is not a claim of 279 production changes.

## Completed preparation

- [x] Release notes draft reflects NEWS and current bounded support, covariance/sign-branch changes and obsolete-option removal.
- [x] Bounded FIML documentation audit complete locally: all 37 public articles inventoried; confirmed gaps repaired in README, six help topics and three articles.
- [x] Ten final HTML artifacts rendered and content/local-link inspected. No browser-visual or deployed-site claim.
- [x] Tested docs source: one full local suite 1,785 tests / 9,796 successful assertions, zero failures/errors, four expected warnings and two explained skips; lint zero; fresh build/built check Status: OK. This is pre-release evidence, not a pass for a later version-stamped candidate.
- [x] Hosted coverage policy verified unchanged: main PRs/main pushes only. Existing expensive workflow configurations inspected, not triggered.

## Remaining sequence, with owners and authorization boundaries

1. **Owner: user/reviewer.** Review and separately authorize publication/integration of the completed docs audit. No push/PR/merge is authorized by this packet. Avoid auditing the same content again without new evidence.
2. **Owner: maintainer.** Reconcile issue #369 with #249/#357/#360 and their merged evidence; classify remaining clauses rather than blindly closing entire issues. #320 records correctly flagged external lavaan comparison disagreements; assess the actual candidate against existing accepted comparison limits. Do not infer a new medfit numerical defect or automatic release blocker solely from an open issue.
3. **Owner: release preparer, after docs inclusion is settled.** Freeze the full dev scope/NEWS. Stamp DESCRIPTION 0.16.0 and actual release-preparation date, promote NEWS development heading, update current release-facing wording/version references and regenerate affected help. Preserve historical 0.15 documentation and study evidence. Sweep old version references and check all current references individually. No date guessed now.
4. **Owner: local verifier.** On that exact version-stamped candidate, run required local suite, numerical gates where applicable, lint, source/built checks, full affected docs/book builds, URL/spelling and dependent-compatibility checks required by the release contract. Investigate warnings/skips. Reuse valid immutable receipts where allowed; do not relabel this audit's counts as the candidate's fresh results. Fresh coverage must meet the required overall/critical-path policy; old patch percentages do not prove it.
5. **Owner: user, separately.** Authorize publishing the candidate and opening dev-to-main release PR. That is the boundary for the required expensive platform/R-CMD-check (including noSuggests), OpenBLAS simulation shards, and coverage/Codecov on the actual candidate. Do not dispatch them during current preparation. Review live head and all required checks; no bypass.
6. **Owner: user/maintainer, separately.** Authorize merge-commit dev into main after live readiness. Verify main CI and exact merged tree before authorizing tag v0.16.0 / GitHub release. GitHub notes are local draft, not a published draft release.
7. **Owner: maintainer.** Check tagged archive/install and expected automatic main-push pkgdown deployment; verify live site/version after deployment. No manual deployment now. Back-merge main to dev and reconcile release/status after success, preserving other worktrees.

## No silent scope expansion

Broader FIML topologies, fixed-X FIML, weights, expected/robust SEs, FIML bootstrap/profile/MBCO, new diagnostics APIs and missingmed adoption remain separate milestones. No new feature is added to 0.16 merely by this checklist. CRAN submission holds remain; cran-comments.md is historical, not a fresh current submission receipt. GitHub-only preparation does not authorize CRAN submission.

## Workflow/source anchors

- .github/workflows/R-CMD-check.yaml: main PR/push full matrix plus noSuggests.
- .github/workflows/gates.yaml: main PR/dispatch, reliability/rest shards on ubuntu-24.04.
- .github/workflows/test-coverage.yaml: unconditional main PR/main push coverage.
- .github/workflows/pkgdown.yaml: main-push deployment; PR builds do not deploy. Do not manually dispatch it as part of preparation.
- planning/SCOPE-0.16-FIML-2026-10-30.md and PLAN-FIML-release-and-missing-data-followups-2026-10-30.md own bounded scope and acceptance boundaries.

## Rollback / stop conditions

Any unexplained candidate likelihood/covariance regression, capability/default change, dependent failure or missing release gate stops publication. Before publication leave v0.15.0/main unchanged. After publication a newly discovered numerical defect requires a maintainer-reviewed corrective release or explicitly authorized revert; never move a published tag or force main. A release is not complete until main CI, tagged install and live docs are verified.
