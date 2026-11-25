# medfit 0.21.0 release checklist

Status: **authorized 2026-11-25; R1 done on `feature/release-0.21.0`, nothing tagged or pushed.** This file is the
single source of release state. CRAN stays on hold (#83); GitHub-only release. Modeled on
`PLAN-0.20.0-release-checklist-2026-11-21.md`. Version: minor bump from 0.20.0.9000 to 0.21.0, done in release prep only.

## What 0.21.0 contains (`dev` at `aabd071d`, 59 files, +2036 / -116 past `main` `4739e8e7`)

- MLR estimator (P1a, #542): `estimator = c("ML", "MLR")`, Yuan-Bentler scaled chi-square (`chisq_scaled`,
  `scaling_factor`, `p_value_scaled`), ML estimates with sandwich SEs, refusals `medfit_error_estimator` and
  `medfit_error_mlr_*`; the `mlr` gate in `tests/sim` (registered; OpenBLAS run pending for the release PR).
- Classed product refusals (P2(c), #540): `medfit_error_product_*`, `medfit_warning_product_modeltest`; messages and
  numbers unchanged.
- Dev tooling and CI (not user-facing): `scripts/cleanup-merged.sh` (#538), `scripts/dev-preflight.sh` (#539),
  R-CMD-check pinned to Ubuntu 24.04 and concurrency (#536, #541). Plans and records: #534, #535, #537.
- Not in it: fit indices, modification indices, T1/T3/T4 (postponed), P2(b), P3 two-level refusal lifts, FIML
  admission, CRAN, serial two-level mediators.

## Preconditions

| # | Precondition | Evidence |
|---|---|---|
| P0 | P1a and P2(c) merged into `dev` | #540 at `536fcc79`; #542 at `aabd071d` (dev tip) |
| P1 | The maintainer authorizes the release in words | Goal quote, 2026-11-25: "finish all the new release tasks; you have all the git permissions; I approved; do not stop and ask". Answer to "Cut the 0.21.0 release now (prep PR, then tag)?", 2026-11-25 13:00 MST: "Cut 0.21.0 release" |
| P2 | Grill held, decisions in `dev` | `planning/DECISIONS-0.21.0-release-2026-11-25.md` (R21-1 to R21-5; in this prep branch, merges with the prep PR) |
| P3 | No open feature PR the release should include | `gh pr list --base dev --state open` on 2026-11-25: none |
| P4 | Roadmap board names the release | not done; do in R11 (mark P1a and P2(c) released) |
| P5 | Risk tier high: `origin/main..origin/dev` touches risk files | `comm -12` of `tests/sim/risk-files.txt` and the diff, 2026-11-25: `R/fit-sem.R`, `R/sem-fit.R`, `R/sem-mlr.R`, `R/sem-model.R`, `R/sem-parse.R`, `tests/sim/gates.csv`. Map to PRs: #542 (MLR files, gates.csv; its seven-item checklist) and #540 (`R/sem-parse.R`, `R/sem-model.R` condition classes). Rerun at the candidate head |
| P6 | No Dependabot or workflow PR landing mid-release | `gh pr list --search "author:app/dependabot"` on 2026-11-25: none |

## Steps and gates

| Step | Action | Evidence | Stop if |
|---|---|---|---|
| R1 | **Done (2026-11-25).** DESCRIPTION Version 0.21.0, Date 2026-11-25; NEWS `# medfit 0.21.0` with Release summary and Known limits; README What's new; getting-started, guide-changes (0.21.0 row), refcard; CLAUDE.md and `.STATUS`. Grep `0.20.0.9000` left only in history (.STATUS older entries, roadmap, 0.20.0 checklist, CLAUDE.md history) | docs tests counts in the prep report; spelling; lint | a stale reference outside history |
| R2 | Local candidate: full suite on an isolated install of the exact head (`NOT_CRAN=true`), spelling, URL check | file, test, failure and skip counts | a failure not reproduced on the `main` baseline |
| N1 | Numeric neutrality: install 0.20.0 and the candidate in separate libraries; run `tidy()`, `confint()`, `nie()` on `mediation_demo` for every released class and a default-`ML` single-level `SEMFit` (`glance()` columns before `p_value` equal); plant a 1e-8 defect | per-cell maximum absolute difference | any difference above 1e-10 not explained by NEWS (the `glance()` MLR columns appear only under MLR) |
| R3 | Built-package `R CMD check`, strict flavors (`--as-cran --run-donttest`, `_R_CHECK_DEPENDS_ONLY_`, `_R_CHECK_SUGGESTS_ONLY_`, `_R_CHECK_CRAN_INCOMING_*`) | check log, every note explained | any ERROR or WARNING |
| R4 | Evaluated site build with a link check; read the rendered `guide-changes`, `refcard`, `model-sem`, troubleshooting and lavaan-comparison pages | build log, pages read | a broken link or erroring article |
| R5 | Dependent suites against the candidate and against `v0.20.0`: probmed, RMediation, missingmed (R21-2) | per-file test counts | a new per-test failure |
| R6 | Book: waiver line (R21-3): **book gate waived for 0.21.0: no chapter for MLR; the render and number checks are not run, as in the 0.20.0 grill's waiver; the 0.17.0 R6 item stays not met.** | this line | the waiver line missing |
| R7 | Release PR `dev` to `main`, `Release: v0.21.0`, as a draft once R1 is done and the cheap local gates (N1, R4, R5) ran on a frozen head. Required on the exact head: platform matrix, no-Suggests jobs, hosted coverage, `gates (rest)` and `gates (reliability)` on the OpenBLAS runner (first hosted run of the `mlr` gate), fast checks, risk-tier with the seven-item checklist (P5) | check names and conclusions on the head SHA | any required check red or missing; no `--admin` unless a non-substantive check is stuck past 3 min with every substantive check green |
| R8 | Merge with a merge commit; verify `main` CI and tree equals the reviewed head | `main` conclusions, tree comparison | `main` CI not green before tagging |
| R9 | Tag `v0.21.0`, GitHub release (`gh release create --target <main sha>`, Known limits copied from NEWS) | tag SHA equals `main`; release URL | tag SHA differs from `main` |
| R10 | Tagged-install smoke: `fit_sem(model, data, estimator = "MLR")` returns a `SEMFit`, `glance()` has `chisq_scaled`; a refused combination gives `medfit_error_mlr_*`; a product refusal carries `medfit_error_product`. Check the site; back-merge `main` into `dev`, bump `dev` to 0.21.0.9000 | install transcript, live site | smoke fails |
| R11 | Cleanup: remove release worktrees and merged branches after exact-tip and ancestry checks (`scripts/cleanup-merged.sh`); mark P1a and P2(c) released on the roadmap board | the checks | an unmerged branch |

## Notes

- Hosted coverage, the platform matrix and the gates shards run only on PRs to `main` and pushes to `main`.
- Every claim in the release notes names a merged PR or a test.
