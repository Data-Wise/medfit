# medfit 0.20.0 release checklist (written, not executed)

Status: **drafted 2026-11-21, not authorized.** Entry gate: the few-clusters T8 (U4 package) is merged into `dev`
(`PLAN-multilevel-remainder-2026-11-18.md`, "Release gate"). CRAN stays on hold (#83). Modeled on
`PLAN-0.19.0-release-checklist-2026-11-16.md`. Version: minor bump from 0.19.0.9000 to 0.20.0, done in release prep and
never in a feature PR.

## What 0.20.0 would contain (`dev` at `5ba88328`, 128 files, +11,483 / -197 past `main` `2c334734`)

- Native two-level fit (S4a, experimental): `fit_sem(cluster = )` and `fit_mediation(engine = "sem", model = , cluster = )`
  for observed variables with fixed slopes and `level:` blocks; per-size sufficient statistics, likelihood and analytic
  gradient, per-level admissibility, `extract_mediation(<SEMFit>)` to `TwoLevelMediationData` with provenance, `glance()`.
  #486, #489, #491, #492, #493; refusals for `mbco_sem()`/`compare_lr()` #495 (`mbco_sem()` later lifted by IG3 T-A).
- Cluster-robust SEs (IG2): `se_type = "sandwich"` gives CR0 SEs for the native two-level fit, matching lavaan
  `robust.huber.white`. #499.
- Two-level tests (IG3): `mbco_sem()` on native two-level fits (#501); `twolevel_equal_indirect()` (#502, #505, #507).
- Oracles and decisions: U1 tolerances ADR, U3 three-way oracle (O8, lavaan, OpenMx; #482, #483).
- Wording: sem-engine names in messages (#496) and in `fit_mediation(engine = "sem")` argument errors (#497).
- Few-clusters study records: T5 and T6 (#484, #485, #490) and the T8 decision table and U4 package (entry gate).
- Docs: ADR section 4b restored (#509); IG2/IG3 scope notes (#494).
- Not in it:
  - S4b (level-2 reliability cell, floor vs unconstrained; next cycle, decided 2026-11-21)
  - T7 cluster bootstrap (dropped for this release, M2 decided 2026-11-21)
  - two-level `compare_lr()` (IG3 D6, deferred)
  - serial two-level mediators (IG5s, decision only)
  - random slopes (IG4) and latent mediators (IG6), NO-GO
  - FIML statistical admission
  - CRAN

## Preconditions (stop if any is unmet)

| # | Precondition | Evidence to record |
|---|---|---|
| P0 | **Entry gate**: T8 merged into `dev` (decision table, U4 package, README and manifest; the gaps plan's U4 line updated); the T5 memo's "MC B = 1000" typo fixed | the T8 PR number and merge SHA |
| P1 | The user authorizes the release in words | the quoted authorization and date |
| P2 | Grill held: decisions R20-1 onward in `planning/DECISIONS-0.20.0-release-grill-<date>.md`, merged into `dev`. Questions to settle: the book waiver (R6), the dependent set (R5), the Known limits list, whether few-clusters guidance appears in user docs or only in planning, and whether the pinned `cluster` formal of `fit_sem()` stays frozen under an experimental label (E1) | the merged decisions file |
| P3 | `dev` has no open feature PR the release should include | `gh pr list --base dev`; on 2026-11-21 only #470 (`chore(rforge)`, `.rforge.yaml`; not part of the release) |
| P4 | Roadmap board reconciled: S4a, IG2, IG3 and T8 listed as merged-dev and the 0.20.0 release named in `planning/medfit-roadmap.md` | the board entry |
| P5 | **Risk tier is high this release** (unlike 0.19.0). `origin/main..origin/dev` touches risk files `R/fit-sem.R`, `R/sem-fit.R`, `R/sem-ml.R`, `R/sem-model.R`, `R/sem-optim.R`, `R/sem-parse.R`, `R/sem-sandwich-twolevel.R`, `R/sem-se.R`, plus `tests/sim/gates.csv` and `tests/sim/structures.csv` (checked 2026-11-21). Each PR carried its seven-item checklist; rerun the comparison at the candidate head and list the PRs whose checklist covers each file | the `comm -12` output and the PR-to-file map |
| P6 | No open Dependabot or workflow PR that would land mid-release | the Dependabot PR list |

## Steps and gates (each with evidence and its stop condition)

| Step | Action | Evidence | Stop if |
|---|---|---|---|
| R1 | Bump the version and `Date:` in `DESCRIPTION`. Collapse NEWS `# medfit 0.19.0.9000` into `# medfit 0.20.0` with a Release summary and the "Known limits" block (at least: native two-level is experimental; `compare_lr()` refuses two-level fits; weights, products, nonlinear constraints and `information = "expected"` refuse with cluster-robust SEs; `fixed_x = TRUE` errors at two levels; few-clusters behavior per T8; no cluster bootstrap evidence). Update `.STATUS`, the `CLAUDE.md` status lines, README, getting-started, guide-changes, refcard and cookbook. Grep for `0.19.0.9000` and stale "latest 0.19.0" claims | the grep output; docs tests (`test-docs-release.R`, `test-model-pages*.R`, `test-guide-*.R`, `test-twolevel-native-docs`) counts; spelling | a stale reference outside history, or a Known limit missing |
| R2 | Local candidate: full suite on an isolated install of the exact head (`NOT_CRAN=true`), spelling (`inst/WORDLIST`), URL check. Few-clusters `tests/sim/` files are covered by `^tests/sim/` in `.Rbuildignore`; any testthat file for the harness skips on CRAN | file, test, failure and skip counts; spelling and URL output; tarball listing under `tests/sim/` | a failure not reproduced on the `main` baseline (read the failing assertion first), or a harness file in the tarball |
| N1 | Numeric neutrality for released classes: install 0.19.0 and the candidate in separate libraries; run `tidy()`, `confint()` and `nie()` on `mediation_demo` for `MediationData`, `SerialMediationData`, `ParallelMediationData`, single-level native `SEMFit`, and lavaan two-level `TwoLevelMediationData` and `TwoLevelParallelMediationData`; compare. Plant a 1e-8 defect | the per-cell maximum absolute difference | any difference above 1e-10 not explained by a NEWS entry |
| N2 | Native two-level oracle recheck at the candidate: O8 likelihood, lavaan estimates and `robust.huber.white` SEs, within the U1 tolerances (`test-twolevel-native-*-qa.R` and the IG2 tests), on the installed package | the test counts and the largest deviation per quantity | a deviation beyond U1 |
| E1 | Experimental claims: NEWS, `?fit_sem` (`cluster =`), `?twolevel_equal_indirect`, `?"medfit-syntax"` and `model-twolevel.qmd` say "experimental". `twolevel_equal_indirect()` is not pinned in `test-api-freeze.R`. The `cluster` formal of `fit_sem()` **is** pinned (`pin_fit_sem_args`, since #486), so its name and position are frozen while its behavior is labeled experimental; the grill (P2) confirms this split or unpins it, and the Rd wording matches the decision | grep output; the freeze file; the grill decision | a missing label, an unplanned freeze pin, or Rd wording that contradicts the decision |
| R3 | Built-package `R CMD check`, strict flavors: `--as-cran --run-donttest`, `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, `_R_CHECK_CRAN_INCOMING_*` | the check log, every note and warning explained (the CRAN version-jump NOTE is expected while #83 holds) | any ERROR or WARNING, or an unexplained NOTE |
| R4 | Evaluated site build with a link check. Read the rendered two-level model page, the syntax help and the cookbook recipes 23 and 24; don't trust the exit code alone | the build log and the pages read | a broken link or an article that errors |
| R5 | Dependent suites against the candidate: probmed and RMediation (set per the grill) | per-file test counts on `v0.19.0` and the candidate | a new per-test failure in either dependent |
| R6 | Book: render `medfit-book` `draft` against the candidate, or record a waiver line here if the grill decides so (the native two-level chapter is not written) | render exit code, chapter count, or the waiver line | a chapter fails to render, or neither a render nor a waiver is recorded |
| R7 | Release PR from `dev` to `main`, titled `Release: v0.20.0`, opened as a **draft as soon as R1 is done**. Required on the exact head: the platform matrix, the no-Suggests jobs, hosted coverage, `gates (rest)` and `gates (reliability)` on the OpenBLAS runner, the fast checks, and **risk-tier with the seven-item checklist** (P5), each item pointing to the merged PRs that carried it | every check name and conclusion on the head SHA | any required check red or missing; no `--admin` unless a non-substantive check is stuck past 3 min with every substantive check green |
| R8 | Merge with a merge commit; verify `main` CI and that the tree matches the reviewed head | `main` check conclusions and the tree comparison | `main` CI not green before tagging |
| R9 | Tag `v0.20.0` and publish the GitHub release (`gh release create --target <main sha>`, notes with the Known limits block copied from NEWS) | the tag SHA equals `main`; the release URL | the tag SHA differs from `main` |
| R10 | Tagged-install smoke: a native `fit_sem(model, data, cluster = )` fit returns a `SEMFit`; `extract_mediation()` gives `TwoLevelMediationData`; `tidy()`, `nie(level = "both")`, `se_type = "sandwich"` and `twolevel_equal_indirect()` run. Check the site deployment; back-merge `main` into `dev` and bump `dev` to 0.20.0.9000 | the install transcript and the live site | the smoke check fails |
| R11 | Cleanup: remove release worktrees and merged branches only after exact-tip and merge-ancestry checks; hand the user any `-D` command. Mark S4a, IG2, IG3 and T8 released on the roadmap board | the checks | an unmerged branch |

## Notes

- Hosted coverage, the platform matrix and the gates shards run only on PRs to `main` and pushes to `main`; don't move
  them to `dev`. This release is the first hosted OpenBLAS run of the native two-level code, so a gates failure there is
  a real finding, not noise (memory: gates runner uses OpenBLAS).
- Every claim in the release notes names a merged PR or a test.
- At 128 files the release PR is reviewable by reading it, file group by file group (R/sem-*, tests, docs, planning).
