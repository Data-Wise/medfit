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
- **Bounded FIML expansion** (kernel, one and two covariates, two parallel and two serial mediators; #382 to #392 and the
  serial forms). Found missing in the first draft of this checklist: it is most of the diff. `origin/main..origin/dev` is
  234 files, +26,472 / -6,695 lines, 96 of them FIML files. Statistical admission is **unresolved**; the simple-model
  source-fit intervals are withheld behind a fail-closed guard (`medfit_error_fiml_inference_unavailable`, #382).
- Not in it: native two-level fitting (S4) and latent mediators (S5), both NO-GO; FIML statistical admission; CRAN.

## Preconditions (stop if any is unmet)

| # | Precondition | Evidence to record |
|---|---|---|
| P1 | The user authorizes a release in words | the message, quoted |
| P2 | Book chapter 9 follows the contrast and equality rules, reviewed by the book owner (plan Task 5); blocked until the owner's branch is pushed | the book PR, merged, with its render-check run |
| P3 | Triage of #369, #320, #394, #381 recorded (plan Task 6) | a disposition per item with a merged-PR or test link; nothing closed without one |
| P4 | `dev` has no open feature PR the release should include | `gh pr list` output |
| P5 | Stale plan statuses and ADR D-4 decided (the #416 audit's open items) | the user's decisions |
| P6 | **FIML ship decision: ANSWERED (maintainer, 2026-11-11 grill, recorded in `planning/DECISIONS-0.17.0-release-grill-2026-11-11.md`, PR #419).** 0.17.0 ships the covariate, parallel and serial FIML models labeled "numerically verified against lavaan, not statistically admitted"; the source-fit guard stays on | confirm #419 is merged before R1 |
| P7 | **Roadmap board reconciled**: `planning/medfit-roadmap.md` "Current board" and "Ordered delivery roadmap" stop at FIML and do not list the two-level adapter or 0.17.0; reconcile them with `.STATUS`, `CLAUDE.md` and the support claims, using the FI-TRACK states (locally verified, merged-dev, merged-main, released) | a merged planning PR |
| P8 | Dependabot #381 (setup-uv 6 to 7) merged or closed, so no workflow change lands mid-release | PR state |

## Steps and gates (each with evidence and its stop condition)

| Step | Action | Evidence | Stop if |
|---|---|---|---|
| R1 | Version and `Date:` in `DESCRIPTION`, NEWS (collapse the long development section into a release section), `inst/CITATION`, `.STATUS`, `CLAUDE.md` status lines, README; grep the whole repo for the old version string | the grep output, the diff | any stale 0.16.0 reference remains outside history |
| R2 | Local candidate: full suite on an isolated install of the exact head with `NOT_CRAN=true`, lint, spelling (`inst/WORDLIST`), URL check | files/tests/failed/skipped counts, lint count, spelling and URL output | any failure not reproduced on the `dev` baseline (judge against the base, read the failing assertion) |
| F1 | FIML guard and claims: every non-`NULL` `source_fit` still stops with `medfit_error_fiml_inference_unavailable` before any draw, refit or worker; no doc, help page, NEWS line or support matrix claims admitted inference or coverage for any FIML variant; `model-fiml` and the native guide match the shipped scope | the guard test run, a grep of docs for "admitted", "coverage" and "calibrated", read in the rendered pages | any claim of admission or coverage, or a bypass of the guard |
| R3 | Built-package `R CMD check`, strict flavors (`--run-donttest`; `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, `_R_CHECK_CRAN_INCOMING_*`) | check log, notes and warnings explained | any ERROR or WARNING, or an unexplained NOTE |
| R4 | Evaluated site build with an inspected link check; inspect the rendered pages, not the exit code | the build log, a list of pages and links read | a broken link or an article that errors |
| R5 | Pinned dependent suites against the candidate: probmed, RMediation, missingmed, mediationverse, medsim (as in 0.16.0) | per-arm test and assertion counts, candidate vs the published 0.16.0 | a new per-test failure in any dependent |
| R6 | Book render against the exact candidate (`scripts/render-check.sh` in `medfit-book`, with the candidate installed) | the render log | a chapter that fails to render, or numbers that disagree with the package |
| R7 | Release PR `dev` to `main` (title `Release: v0.17.0`): require the platform matrix, no-Suggests jobs, hosted coverage (main PRs only), both simulation shards `gates (rest)` and `gates (reliability)`, and the fast checks, all on the exact head; **the release PR body carries the seven-item admission checklist, because the diff touches `tests/sim/risk-files.txt` entries (`R/fit-sem.R`, `R/sem-fiml.R`, `R/sem-fiml-interface.R`) and `gates.csv`**, each item ticked or `n/a: <reason>` | all check names and conclusions on the head SHA | any required check red or missing; **both `gates` shards (`gates (rest)`, `gates (reliability)`) green on the exact head, no `--admin` (maintainer decision 4, 2026-11-11)** |
| R8 | Merge with a merge commit; verify `main` CI and tree | `main` check conclusions, tree identity with the reviewed head | `main` CI not green before tagging |
| R9 | Tag `v0.17.0` and publish the GitHub release (`gh release create --target <main sha>`, reviewed notes) | tag SHA equals `main`; release URL | tag not equal to `main` |
| R10 | Verify the tagged install (a smoke check of the two-level route) and the automatic website deployment; back-merge `main` into `dev` (strict protection) | install transcript, live site check | smoke check fails |
| R11 | Cleanup: remove release worktrees and merged branches only after exact-tip and merge-ancestry checks; hand the user any `-D` command | the checks | an unmerged branch |

## Maintainer decisions recorded 2026-11-11 (PR #419)

1. Bounded FIML covariate, parallel and serial models ship labeled "numerically verified, not statistically admitted" (P6).
2. The two-level API is **experimental**: it is not pinned in `test-api-freeze.R`, and the release notes and the model page say so (add to gate F1's doc grep: the two-level page and NEWS use "experimental").
3. v0.15.0 was tagged before the 2026-12-24 floor as a deliberate waiver; no reason was recorded.
4. The release PR needs both gates shards green on the exact head; no `--admin`.

## Notes

- Hosted coverage and the platform matrix run on PRs to `main` and pushes to `main` only; do not move them to `dev`.
- A green numerical fixture is not a global guarantee; carry the known `#320` external-engine discrepancy into the release notes
  unless it is resolved.
- CRAN stays on hold (`#83`); this is a GitHub-only release.
- Every claim in the release notes names a merged PR or a test.
- **Lesson from 0.16.0:** the release PR found three Windows test failures and a missing `numDeriv` in Suggests only after it was opened
  (#374). Open the `dev` to `main` PR as a draft as soon as the candidate is feature-complete, to learn the platform results
  before the last gate, and expect one corrective round.
- Size: a 234-file release PR is hard to review. Reviewing it by theme (two-level, FIML, CI, docs) with the per-PR evidence
  already recorded is more reliable than reading the diff.
