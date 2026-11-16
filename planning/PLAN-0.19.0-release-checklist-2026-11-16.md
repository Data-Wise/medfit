# medfit 0.19.0 release checklist (written, not executed)

Status: DRAFT checklist, 2026-11-16. **Nothing here is authorized.** The release, the tag, the `main` merge and the GitHub
release are out of scope until the user says so in words. CRAN stays on hold (#83). Modeled on
`PLAN-0.17.0-release-checklist-2026-11-11.md`. Scope and rationale: `planning/specs/BRAINSTORM-release-0.19.0-2026-11-16.md`.
Version: minor bump from 0.18.0.9000 to 0.19.0, done in release prep and never in a feature PR.

## What 0.19.0 would contain (`dev` at `7445af62`, 61 files, +3,680 / -148 past `main`)

- IG5, parallel mediators in a two-level lavaan model (experimental), #458 to #465:
  - `TwoLevelParallelMediationData`
  - `extract_mediation()` for two-level fits with several mediators
  - per-mediator and total effects with `level =`, and delta-method SEs
  - `twolevel_statistic()` for parallel mediators
  - the model page, the cookbook recipe and NEWS
- Planning: the few-clusters design-study plan (#464).
- Not in it:
  - the few-clusters study and its results
  - solver work D-14 and D-6
  - IG6 and IG7
  - native two-level fitting (S4) and latent mediators (S5), both NO-GO
  - serial two-level mediators
  - FIML statistical admission
  - CRAN

## Preconditions (stop if any is unmet)

| # | Precondition | Evidence to record |
|---|---|---|
| P1 | The user authorizes the release in words | the message, quoted |
| P2 | **DONE 2026-11-16**: #465 (IG5 T5 docs) merged into `dev` | `7445af62` on `origin/dev` |
| P3 | Release grill held on the brainstorm's six open decisions; the answers recorded in `planning/DECISIONS-0.19.0-release-grill-<date>.md` | the merged decisions file |
| P4 | `dev` has no open feature PR the release should include. A few-clusters harness PR may be open; it is internal, and the grill decides whether to wait for it | `gh pr list` output |
| P5 | Roadmap board reconciled: IG5 is listed as merged-dev and the 0.19.0 release appears in `planning/medfit-roadmap.md` | a merged planning PR |
| P6 | Risk tier confirmed low: `git diff origin/main..origin/dev` touches no `tests/sim/risk-files.txt` entry and no `gates.csv` or `structures.csv` (checked 2026-11-16: none); rerun at the candidate head | the diff output |
| P7 | No open Dependabot or workflow PR that would land mid-release | PR state |

## Steps and gates (each with evidence and its stop condition)

| Step | Action | Evidence | Stop if |
|---|---|---|---|
| R1 | Bump the version and `Date:` in `DESCRIPTION`. Collapse NEWS `# medfit 0.18.0.9000` into `# medfit 0.19.0`. Update `inst/CITATION`, `.STATUS`, the `CLAUDE.md` status lines and README. Then grep the repo for `0.18.0.9000` and for stale "latest 0.18.0" claims | the grep output and the diff | any stale reference remains outside history |
| R2 | Local candidate: full suite on an isolated install of the exact head (`NOT_CRAN=true`), lint, spelling (`inst/WORDLIST`), URL check | counts of files, tests, failures and skips; the lint count; the spelling and URL output | a failure not reproduced on the `main` baseline (read the failing assertion first) |
| E1 | Experimental claims: NEWS, the Rd page of `TwoLevelParallelMediationData` and the two-level model page say "experimental". The class is not pinned in `test-api-freeze.R`. A single-mediator two-level fit still returns `TwoLevelMediationData` | a docs grep and a test or transcript for each | a missing label, a freeze pin, or a changed return class |
| R3 | Built-package `R CMD check`, strict flavors: `--run-donttest`, `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, `_R_CHECK_CRAN_INCOMING_*` | the check log, with every note and warning explained | any ERROR or WARNING, or an unexplained NOTE |
| R4 | Evaluated site build with a link check. Inspect the rendered pages, the two-level model page above all; don't trust the exit code alone | the build log and the pages read | a broken link or an article that errors |
| R5 | Pinned dependent suites against the candidate: probmed, RMediation, missingmed, mediationverse, medsim | per-arm test and assertion counts, candidate vs published 0.18.0 | a new per-test failure in any dependent |
| R6 | Book: whatever the grill decided (decision 3): a render of `medfit-book` `draft` against the candidate, or a recorded waiver. Never left silently unmet | the render log or the waiver line | a chapter fails to render, or no decision is recorded |
| R7 | Release PR from `dev` to `main`, titled `Release: v0.19.0`, opened as a **draft as soon as R1 is done** (lesson from 0.16.0). Required on the exact head: the platform matrix, the no-Suggests jobs, hosted coverage, both `gates (rest)` and `gates (reliability)`, and the fast checks. No seven-item checklist unless P6 changes | every check name and conclusion on the head SHA | any required check red or missing; no `--admin` |
| R8 | Merge with a merge commit; verify `main` CI and that the tree matches the reviewed head | `main` check conclusions and the tree comparison | `main` CI not green before tagging |
| R9 | Tag `v0.19.0` and publish the GitHub release (`gh release create --target <main sha>`, reviewed notes) | the tag SHA equals `main`; the release URL | the tag SHA differs from `main` |
| R10 | Tagged-install smoke: a two-level lavaan fit with two mediators returns `TwoLevelParallelMediationData`, and `tidy()` and `nie(level = "both")` run. Then check the site deployment and back-merge `main` into `dev` | the install transcript and the live site | the smoke check fails |
| R11 | Cleanup: remove release worktrees and merged branches only after exact-tip and merge-ancestry checks. Hand the user any `-D` command. Mark IG5 released on the roadmap board | the checks | an unmerged branch |

## Notes

- Hosted coverage and the platform matrix run only on PRs to `main` and pushes to `main`; don't move them to `dev`.
- Every claim in the release notes names a merged PR or a test.
- Restate the two-level limits in the release notes: experimental API, a descriptive contrast, the within-only object when
  ICC < 0.01, no serial mediators, no native fitting.
- At 61 files, the release PR can be reviewed by reading it, unlike 0.17.0's 234-file PR.
