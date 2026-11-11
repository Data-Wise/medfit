# medfit 0.17.0 release checklist (written, not executed)

Status: DRAFT checklist, 2026-11-11. **Nothing here is authorized.** Release, tag, `main` merge, GitHub release and CRAN stay
out of scope until the user says so in words. Modeled on `PLAN-0.16.0-GitHub-release-2026-10-30.md` (published at `c37c7ee8`).
Task 7 of `PLAN-twolevel-contrast-and-release-readiness-2026-11-10.md`. Version choice: minor bump 0.16.0 to 0.17.0
(spec Q5), done in release prep, never in a feature PR.

## What 0.17.0 would contain (on `dev`, 42 commits past `main` at 2026-11-11)

- The lavaan two-level adapter: `TwoLevelMediationData`, `extract_mediation()` on two-level fits, effects with `level =`,
  `twolevel_statistic()`, the O8 likelihood oracle, the contrast rule (unless both a and b are equated) and numeric equality
  detection, hardening (#412, #415); lavaan floor 0.7-3.
- Docs: the two-level model page, cookbook recipe 23, methods section, the workflow and architecture guides, `CONTRIBUTING.md`,
  the condition-docs guard (#416, #417).
- CI: lint, pkgdown and risk-tier pinned to `ubuntu-24.04`; lint timeout 35 minutes (#411, #414).
- Not in it: native two-level fitting (S4) and latent mediators (S5), both NO-GO; FIML admission; CRAN.

## Preconditions (stop if any is unmet)

| # | Precondition | Evidence to record |
|---|---|---|
| P1 | The user authorizes a release in words | the message, quoted |
| P2 | Book chapter 9 follows the contrast and equality rules, reviewed by the book owner (plan Task 5); blocked until the owner's branch is pushed | the book PR, merged, with its render-check run |
| P3 | Triage of #369, #320, #394, #381 recorded (plan Task 6) | a disposition per item with a merged-PR or test link; nothing closed without one |
| P4 | `dev` has no open feature PR the release should include | `gh pr list` output |
| P5 | Stale plan statuses and ADR D-4 decided (the #416 audit's open items) | the user's decisions |

## Steps and gates (each with evidence and its stop condition)

| Step | Action | Evidence | Stop if |
|---|---|---|---|
| R1 | Version, date, NEWS, DESCRIPTION, CITATION (if present), `.STATUS`, `CLAUDE.md` status lines, README; grep the whole repo for the old version string | the grep output, the diff | any stale 0.16.0 reference remains outside history |
| R2 | Local candidate: full suite on an isolated install of the exact head with `NOT_CRAN=true`, lint, spelling (`inst/WORDLIST`), URL check | files/tests/failed/skipped counts, lint count, spelling and URL output | any failure not reproduced on the `dev` baseline (judge against the base, read the failing assertion) |
| R3 | Built-package `R CMD check`, strict flavors (`--run-donttest`; `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, `_R_CHECK_CRAN_INCOMING_*`) | check log, notes and warnings explained | any ERROR or WARNING, or an unexplained NOTE |
| R4 | Evaluated site build with an inspected link check; inspect the rendered pages, not the exit code | the build log, a list of pages and links read | a broken link or an article that errors |
| R5 | Pinned dependent suites against the candidate: probmed, RMediation, missingmed, mediationverse, medsim (as in 0.16.0) | per-arm test and assertion counts, candidate vs the published 0.16.0 | a new per-test failure in any dependent |
| R6 | Book render against the exact candidate (`scripts/render-check.sh` in `medfit-book`, with the candidate installed) | the render log | a chapter that fails to render, or numbers that disagree with the package |
| R7 | Release PR `dev` to `main` (title `Release: v0.17.0`): require the platform matrix, no-Suggests jobs, hosted coverage (main PRs only), both simulation shards `gates (rest)` and `gates (reliability)`, and the fast checks, all on the exact head | all check names and conclusions on the head SHA | any required check red or missing; no bypass; a non-substantive check stuck over 3 minutes with every substantive check green may be merged with `--admin` only if you say so |
| R8 | Merge with a merge commit; verify `main` CI and tree | `main` check conclusions, tree identity with the reviewed head | `main` CI not green before tagging |
| R9 | Tag `v0.17.0` and publish the GitHub release (`gh release create --target <main sha>`, reviewed notes) | tag SHA equals `main`; release URL | tag not equal to `main` |
| R10 | Verify the tagged install (a smoke check of the two-level route) and the automatic website deployment; back-merge `main` into `dev` (strict protection) | install transcript, live site check | smoke check fails |
| R11 | Cleanup: remove release worktrees and merged branches only after exact-tip and merge-ancestry checks; hand the user any `-D` command | the checks | an unmerged branch |

## Notes

- Hosted coverage and the platform matrix run on PRs to `main` and pushes to `main` only; do not move them to `dev`.
- A green numerical fixture is not a global guarantee; carry the known `#320` external-engine discrepancy into the release notes
  unless it is resolved.
- CRAN stays on hold (`#83`); this is a GitHub-only release.
- Every claim in the release notes names a merged PR or a test.
