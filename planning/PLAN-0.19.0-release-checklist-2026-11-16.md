# medfit 0.19.0 release checklist (written, not executed)

Status: **authorized 2026-11-17** (P1); R1 executed on `feature/release-0.19.0` (from `dev` `16776113`). Drafted 2026-11-16. CRAN stays on hold (#83). Modeled on
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
| P1 | **DONE 2026-11-17**: the user authorizes the release in words | "finish the release" (2026-11-17) |
| P2 | **DONE 2026-11-16**: #465 (IG5 T5 docs) merged into `dev` | `7445af62` on `origin/dev` |
| P3 | **Grill held 2026-11-16**: decisions R19-1 to R19-5 in `planning/DECISIONS-0.19.0-release-grill-2026-11-16.md`; the file must be merged into `dev` | the merged decisions file |
| P4 | `dev` has no open feature PR the release should include. A few-clusters harness PR may be open; the release does not wait for it (R19-2) | **DONE 2026-11-17**: `gh pr list --base dev` shows only #470 (`chore(rforge)`, `.rforge.yaml` only; not part of the release). Few-clusters harness #467-#469 already merged |
| P5 | Roadmap board reconciled: IG5 is listed as merged-dev and the 0.19.0 release appears in `planning/medfit-roadmap.md` | **DONE in the release-prep PR**: roadmap header checkpoint and a "Reconciliation 2026-11-17" board entry |
| P6 | Risk tier confirmed low: `git diff origin/main..origin/dev` touches no `tests/sim/risk-files.txt` entry and no `gates.csv` or `structures.csv` (checked 2026-11-16: none); rerun at the candidate head | **DONE 2026-11-17** at `16776113` (`origin/main..origin/dev`: 69 files, +5,616/-148): `comm -12` with `risk-files.txt` empty; no `gates.csv`/`structures.csv`; `tests/sim/twolevel-few-clusters*.R` changed, not risk files |
| P7 | No open Dependabot or workflow PR that would land mid-release | **DONE 2026-11-17**: Dependabot PR list `[]`; #470 touches no workflow |

## Steps and gates (each with evidence and its stop condition)

| Step | Action | Evidence | Stop if |
|---|---|---|---|
| R1 | Bump the version and `Date:` in `DESCRIPTION`. Collapse NEWS `# medfit 0.18.0.9000` into `# medfit 0.19.0` and add the "Known limits" block (R19-5). Update `inst/CITATION`, `.STATUS`, the `CLAUDE.md` status lines and README. Then grep the repo for `0.18.0.9000` and for stale "latest 0.18.0" claims | **DONE 2026-11-17**: DESCRIPTION 0.19.0/2026-11-17; NEWS `# medfit 0.19.0` with Release summary and six linked Known limits; README, getting-started, guide-changes, refcard, cookbook, `.STATUS`, `CLAUDE.md`; CITATION reads `meta$Version` (no edit). `0.18.0.9000` left only in history; stale dev/latest claims 0 hits. Docs tests 139 tests/1,126 expectations, 0 failed; spelling clean; four articles render (grep output in `_agents_workspace/release/`) | any stale reference remains outside history, or a limit from R19-5 is missing |
| R2 | Local candidate: full suite on an isolated install of the exact head (`NOT_CRAN=true`), lint, spelling (`inst/WORDLIST`), URL check. If few-clusters harness work is on `dev` at the candidate, its `tests/sim/` files are in `.Rbuildignore` and its testthat test is skipped on CRAN (R19-2) | counts of files, tests, failures and skips; the lint count; the spelling and URL output; `R CMD build` tarball listing for the harness files; R19-2 prep done in R1: `skip_on_cran()` added to `test-twolevel-few-clusters-harness.R` (0 tests run with `NOT_CRAN` unset), `tests/sim/` harness files covered by `^tests/sim/` in `.Rbuildignore` | a failure not reproduced on the `main` baseline (read the failing assertion first), or a harness file in the tarball |
| N1 | Numeric neutrality (R19-4): install 0.18.0 and the candidate in separate libraries; run `tidy()`, `confint()` and `nie()` on `mediation_demo` for `MediationData`, `SerialMediationData`, `ParallelMediationData` and single-mediator `TwoLevelMediationData`; compare | **DONE 2026-11-17**: max absolute difference 0 in all 13 cells (four classes; `tidy`, `confint`, `nie`); a planted 1e-8 defect was caught | any difference above 1e-10 |
| E1 | Experimental claims: NEWS, the Rd page of `TwoLevelParallelMediationData` and the two-level model page say "experimental". The class is not pinned in `test-api-freeze.R`. A single-mediator two-level fit still returns `TwoLevelMediationData` | **DONE 2026-11-17**: "experimental" in NEWS, the Rd page and `model-twolevel.qmd`; no pin in `test-api-freeze.R`; one mediator returns `TwoLevelMediationData`, two return `TwoLevelParallelMediationData` | a missing label, a freeze pin, or a changed return class |
| R3 | Built-package `R CMD check`, strict flavors: `--run-donttest`, `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, `_R_CHECK_CRAN_INCOMING_*` | the check log, with every note and warning explained | any ERROR or WARNING, or an unexplained NOTE |
| R4 | Evaluated site build with a link check. Inspect the rendered pages, the two-level model page above all; don't trust the exit code alone | the build log and the pages read | a broken link or an article that errors |
| R5 | Dependent suites against the candidate: **probmed and RMediation only** (R19-3; missingmed, mediationverse and medsim are not run this release, a departure from 0.17.0 and 0.18.0; N1 partly covers them) | **DONE 2026-11-17** (candidate `16776113` vs `v0.18.0`, `NOT_CRAN=true`): probmed (origin/dev `505e331`) 252 tests, 909 assertions, 0 failed, 0 skipped on both sides; RMediation (`55fb68b`) 587 tests, 3,058 assertions, 0 failed, 1 skip, 4 warnings on both sides; per-file counts identical | a new per-test failure in either dependent |
| R6 | Book (R19-1): render `medfit-book` `draft` against the candidate, and write the waiver line here: "Waiver: the parallel-mediator section follows the release in `medfit-book`." | **DONE 2026-11-17**: `medfit-book` `draft` `a8226ff` rendered against the candidate (lock overridden for the render only): exit 0, 14 chapters, index and appendices, 410-page PDF, no error lines. Waiver: the parallel-mediator section follows the release in `medfit-book`. | a chapter fails to render, or the waiver line is missing |
| R7 | Release PR from `dev` to `main`, titled `Release: v0.19.0`, opened as a **draft as soon as R1 is done** (lesson from 0.16.0). Required on the exact head: the platform matrix, the no-Suggests jobs, hosted coverage, both `gates (rest)` and `gates (reliability)`, and the fast checks. No seven-item checklist unless P6 changes | every check name and conclusion on the head SHA | any required check red or missing; no `--admin` |
| R8 | Merge with a merge commit; verify `main` CI and that the tree matches the reviewed head | `main` check conclusions and the tree comparison | `main` CI not green before tagging |
| R9 | Tag `v0.19.0` and publish the GitHub release (`gh release create --target <main sha>`, reviewed notes) | the tag SHA equals `main`; the release URL | the tag SHA differs from `main` |
| R10 | Tagged-install smoke: a two-level lavaan fit with two mediators returns `TwoLevelParallelMediationData`, and `tidy()` and `nie(level = "both")` run. Then check the site deployment and back-merge `main` into `dev` | the install transcript and the live site | the smoke check fails |
| R11 | Cleanup: remove release worktrees and merged branches only after exact-tip and merge-ancestry checks. Hand the user any `-D` command. Mark IG5 released on the roadmap board | the checks | an unmerged branch |

## Notes

- Hosted coverage and the platform matrix run only on PRs to `main` and pushes to `main`; don't move them to `dev`.
- Every claim in the release notes names a merged PR or a test.
- The release notes carry the "Known limits" block of R19-5, copied from NEWS in R9.
- At 61 files, the release PR can be reviewed by reading it, unlike 0.17.0's 234-file PR.
