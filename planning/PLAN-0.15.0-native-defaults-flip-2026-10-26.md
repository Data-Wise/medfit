# PLAN: medfit 0.15.0, native defaults flip

**Date:** 2026-10-26 | **Status:** draft, awaiting approval
**Spec:** `planning/specs/SPEC-0-15-release-2026-10-26.md` | **Brainstorm:** `planning/BRAINSTORM-0-15-release-2026-10-26.md`
**ADR:** `planning/specs/ADR-native-defaults-2026-10-24.md` (E-1 to E-15) | **Announcement:** [BREAKING] #329
**Prior plan:** `planning/PLAN-0.14.0-native-defaults-2026-10-24.md` (0.14.0, released)
**Release:** readiness-gated, not before 2026-12-24. Hold the flip if any gate fails (F-13).
**Branch:** `feature/native-defaults-flip` from `origin/dev`; worktree `~/.git-worktrees/medfit/native-defaults-flip`.

Task state lives in this file. Tick a task only when its harness reports all say `Verdict: PASS`.

## Architecture decisions

- The flip is one default change plus a resolver change; reverting the commit restores the old defaults (no data
  migration). Users can always pass the old values.
- Evidence before code: T1 (#320 re-measure) and T2 (E-5 verify) can change scope, so they run first.
- All flip work lands in one PR to `dev` (small diff, many test/doc edits); release PR `dev -> main` is separate and
  is the author's release process, outside this pipeline.

## Dependency graph

```
T1 (#320 re-measure) ----+
T2 (E-5 verify) ---------+--> T3 (flip + resolver) --> T4 (tests) --> T5 (docs) --> T6 (final gates, E-12, oracle)
                                                                                   \
T7 (dependents: missingmed#102, scratch-lib) -> T7b (harden arm.R) ----------------> T8 (release readiness)
```

## Harness (how each task runs)

Run through the `medfit-orchestrator` skill; stages are subagents in sequence:
`medfit-implementer` -> `medfit-oracle-qa` (at most 2 loops) -> `medfit-gates` (`pre-docs`) -> `medfit-docs` -> `medfit-gates` (`final`).

| Item | Rule |
|---|---|
| Worktree | `git fetch -q origin && git worktree add ~/.git-worktrees/medfit/native-defaults-flip -b feature/native-defaults-flip origin/dev` |
| Reports | `<worktree>/_agents_workspace/<task>/{implementer,qa,gates,docs}.md`, git-ignored |
| Verdict | last line exactly `Verdict: PASS` or `Verdict: FAIL`; anything else is a failed stage |
| Commits | each editing stage ends with a scoped commit on the feature branch |
| Push / PR | orchestrator asks the user first, every time; PR to `dev` via `gh pr create --base dev --body-file` |
| Risk tier | T3 and T4 are high-risk: PR body carries the seven-item checklist (`n/a: <reason>` format); `risk_check()` run on the exact body text |
| Evidence | exact command plus counts (tests, expectations, failed, errors, skipped); baseline judged against `dev` |

## Tasks

### Phase 1: Evidence first

- [x] **T1 (S): Re-measure #320** (done 2026-10-26: documented limit, not a blocker; result below) | agents: gates (dispatch + read), oracle-qa (interpret) | risk: n/a (measurement)
  - Baselines (pinned, per engine; both are the T4b/T4c runs of 2026-10-24, `tests/sim/results/compare-lr-gate-2026-10-24.csv`,
    macOS, lavaan 0.7.3, OpenMx 2.22.11, n = 200, a = b = 0.4, 15 seeds x 4 cells, PRs #319/#321): **lavaan 18 of 60**
    runs above the reference (#320 body); **OpenMx 13 of 60** (#320 comment; `gates.csv` row `compare-lr`). The two
    counts are different engines, not a conflict. Record the commit SHA of `dev` for the new run.
  - Acceptance: one `compare-lr` gate run on current `dev` (reference-BLAS and the OpenBLAS runner both noted) with the
    same design and seeds; above-reference counts stated per engine against the pinned baselines. Decision rule fixed
    now: **blocker** if either count exceeds its baseline (lavaan > 18, OpenMx > 13) or any row is mislabeled
    (warning without evidence, silence on an observed violation); otherwise **documented limit** with the `?compare_lr`
    note from #320 item 4. A count at or below baseline with a different seed set is not comparable: rerun on the pinned seeds.
  - Planted defect: none (measurement); control = same run on the 0.14.0 tag must reproduce 18 and 13, or the
    comparison is void (environment changed).
  - Verify: `gh workflow run gates.yaml --ref dev`, then read the `compare-lr` shard result.
  - Files: none changed; result appended to #320 and to this plan.
  - **Result (2026-10-26, local macOS run; the runner run was dropped by the user, OpenBLAS check deferred to the
    release gates, F-7).** `dev` at `74016e6`; R 4.6.1; BLAS Homebrew OpenBLAS 0.3.34 (the 2026-10-24 baseline's BLAS
    is not recorded, so a BLAS difference is possible); lavaan 0.7.3; OpenMx 2.22.11; pinned design and seeds
    (`c(1:12, 15, 37, 41)` x 4 cells). Gate: 150 of 150 rows pass, 0 mislabeled.

    | Run | lavaan above (of 60) | OpenMx above (of 60) |
    |---|---|---|
    | Baseline 2026-10-24 (CSV) | 18 | 13 |
    | Control: `v0.14.0` tree (`b7d7566`) + current gate script | 18 | 13 |
    | `dev` `74016e6` | 18 | 13 |

    The control reproduces both baselines, so the comparison is valid. Neither count grew and no row is mislabeled:
    **documented limit**, with the `?compare_lr` note from #320 item 4. Not yet posted to #320 (ask first).
- [x] **T2 (S): Verify lavaan `fixed.x = TRUE` product-column handling (E-5)** | agents: oracle-qa | risk: n/a
  - Why estimates are not enough: structural estimates and SEs do not move when `fixed_x` changes (the 557-row
    matrix), so an estimate comparison cannot tell a fixed product column from a free one. The discriminating
    quantities are set membership, `npar`, and the conditional logLik.
  - Acceptance (all on a model with an `x:m` column, vs an independent lavaan `fixed.x = TRUE` fit):
    1. medfit's resolved `fixed_x` set contains `.sem_product_name(x, m)` (the canonical `m:x` name) and every exogenous
       covariate; asserted directly, not inferred.
    2. The product column's variance and covariance rows with the other exogenous variables are in the fixed-moment
       parameter set (absent from the free `coef()` names); lavaan's fixed rows match.
    3. `npar` equals lavaan's free-parameter count minus medfit's documented AIC/BIC difference (F-9), stated as an
       exact integer comparison.
    4. Conditional logLik agrees with lavaan to 1e-6.
    5. Structural estimates and SEs agree to 1e-6 (necessary, not sufficient).
    A mismatch is written up as a T3 requirement.
  - Planted defect: remove the product name from the resolved fixed set (product column left free). Checks 1-4 must
    fail on it (check 5 is expected to still pass; the report states which checks tripped). If checks 1-4 do not
    fail, the oracle is non-discriminating and T2 is FAIL.
  - Verify: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-sem-product-extract.R")'` plus
    the oracle script; the report lists, per check, pass/fail on the real fit and on the planted defect.
  - Files: `tests/testthat/test-sem-product-*.R` (read), oracle report only.
  - **Result (2026-10-26): PASS.** Checks 1-4 pass on the real fit and trip on the planted defect; check 5 passes on both
    (max gap 3.1e-12). Check 5 needs lavaan `information = "observed"` (default expected differs from medfit's observed;
    pin it in T3/T4 product-model comparisons). Existing `test-sem-product-extract.R`: 10 tests, 38 expectations.

### Checkpoint A: after T1-T2
- [x] #320 decision recorded; E-5 verified or turned into a T3 requirement; human review before T3.

### Phase 2: The flip

- [x] **T3 (M): Flip the formals and the resolver** | agents: implementer -> oracle-qa -> gates | risk: **high**
  - Status (2026-10-26): implemented on `feature/native-defaults-flip`, PR #347 to `dev` (not merged); tick on merge.
  - Acceptance: F-1 to F-4. Unset `fixed_x`/`meanstructure` resolve to the new values unconditionally (E-14);
    `options(medfit.native_defaults)` ignored with an obsolete note; `medfit_warning_default_change` no longer fires;
    an explicit `FALSE`/`NULL` is preserved; explicit `fixed_x = TRUE` still errors on `~~`/`~1` on exogenous variables.
  - Planted defects: (a) resolver overwriting an explicit `FALSE`; (b) default left as old value in `fit_mediation()` only.
    Both must be caught by tests.
  - Verify: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-native-defaults.R")'`,
    `test-api-freeze.R`.
  - Files: `R/fit-sem.R`, `R/native-defaults.R`, `tests/testthat/test-api-freeze.R`, `test-native-defaults*.R`,
    `tests/sim/risk-files.txt` (if `R/fit-sem.R` absent).
- [x] **T4 (M): Rewrite the failing tests from the Checkpoint B list; drop T5a setup chunks** | agents: implementer -> oracle-qa -> gates | risk: **high**
  - Status (2026-10-26): 17 failing tests rewritten plus the `compare_lr()` test (`e88e534`, `e47243f`, `2005d90`), in PR #347
    (`lint`, `risk-tier` green; `pkgdown` pending; not merged). The T5a setup-chunk muffles are still open (T5a).
  - Acceptance: F-5. Tests state their settings explicitly where they depend on them; frozen fixtures pinned at 1e-6;
    full suite green with counts reported against the `dev` baseline.
  - Planted defect: a rewritten test must fail when the old default is restored.
  - Verify: `Rscript -e 'devtools::test()'`.
  - Files: the test files named in the 0.14.0 plan Checkpoint B (21 were listed; 17 failed under the flip) (split into two tasks if more than 5 files per commit).

### Checkpoint B: after T3-T4
- [x] Full suite green; `pre-docs` gates PASS; oracle-qa PASS with both planted defects caught; human review.

### Phase 3: Docs and conventions

- [x] **T5 (L, split T5a/T5b/T5c): Docs and website update** | agents: docs -> gates (`final`) | risk: n/a (docs-consistency tests apply)
  - Acceptance: F-9, F-11. Every doc surface states the new defaults and what moves (logLik conditional, npar, AIC/BIC,
    `coef()` names, retry seed) and what does not (structural estimates, SEs); no page still shows an opt-in
    `fixed_x = TRUE` / `meanstructure = TRUE` as required, or the 0.14.0 warning.
  - **T5a, reference and prose:** `NEWS.md` (behavior-change entry; AIC/BIC convention with the lavaan difference;
    missing-data note: listwise, no FIML); `man/` (`fit_sem`, `fit_mediation`, `compare_lr`, with the #320 limit note);
    `R/sem-syntax-help.R` (`?"medfit-syntax"`); `vignettes/articles/native-defaults-0-15.qmd` (rewrite from
    "upcoming" to "shipped"); `guide-changes.qmd`, `guide-troubleshooting.qmd`, `guide-glossary.qmd`.
  - **T5b, articles and tutorials:** `cookbook.qmd` (recipes 18/19 and any recipe fitting native defaults);
    `native-tutorial.qmd` (step 9), `native-quickstart.qmd`, `native-guide.qmd`; `model-native*.qmd` (5 pages);
    `lavaan-comparison.qmd` (reverse the affected rows); `syntax-crosswalk.qmd`; `refcard.qmd`; `methods.qmd`
    (conditional logLik, parameter count); `whats-new-0-11.qmd` untouched (historical).
  - **T5c, book, QC and website:** `book/chapters/01..07` plus `book/index.qmd` (defaults, logLik/AIC/BIC chapters);
    `quality-control.qmd` and a QC record for 0.15.0 (the flip gates, oracle matrix, the #320 documented limit, the
    OpenBLAS run); `_pkgdown.yml` (reference index, articles menu entries for any new page). Local site check:
    `pkgdown::build_site()` against a scratch library holding the branch build (medfit installed from the worktree, not
    the older release); **no deploy**: the pkgdown dispatch and any Netlify action need an explicit request.
  - Planted defect: a doc claim contradicting the new default must fail `test-cookbook-consistency.R`, the model-page
    tests or `test-native-book.R`.
  - Verify: `Rscript -e 'devtools::document(); devtools::test(filter = "refcard|cookbook|model-pages|guide|native-book|lavaan-comparison")'`,
    `lintr`, `urlchecker::url_check()`, `spelling::spell_check_package()`, then the local `pkgdown::build_site()` with
    zero errors and no broken article links.
  - Files: over the 5-file limit by design; one commit per sub-task (T5a, T5b, T5c).
  - Progress (2026-10-26, PR #347): T5a `84e343c`, T5b `795a6a7`, T5c `78c4ea9` committed and pushed; local book render
    and `pkgdown::build_site()` clean (agent-reported). `final` gates PASS on `4115673` (1697 tests, 0 failed; lint at
    the 169 baseline; risk checklist complete, item 7 deferred to the release PR). `guide-changes.qmd` "documents 0.14.1" is left for T8.
- [x] **T6 (M): E-12 reliability gate + oracle matrix on the final tree** | agents: gates, oracle-qa | risk: **high** (evidence)
  - Acceptance: F-6, F-7. Oracle matrix re-run: 0 block rows. `gates (rest)` and `gates (reliability)` green on the
    OpenBLAS runner; reliability acceptance rate non-inferior to the last green run.
  - Planted defect: `MUTANT=` switches in the gate scripts still trip (positive control).
  - Verify: `Rscript tests/sim/native-defaults-oracle.R`, `gh workflow run gates.yaml --ref feature/native-defaults-flip`.
  - Files: `tests/sim/` pins only if a gate needs updating.
  - Progress (local, final tree `498e647`): oracle matrix 557 rows, 503 pass, 54 limit, 0 block; `MUTANT=fixedx_logical` and `MUTANT=product_free` both exit 1. The OpenBLAS `gates (rest)`/`gates (reliability)` runs are deferred to the release PR (user decision), so those F-6 clauses stay open until then.

### Checkpoint C: PR to `dev`
- [x] All reports `Verdict: PASS`; `git status` clean; `git diff --name-only origin/dev...HEAD` covers every cited file.
- [x] Ask the user before pushing and before opening the PR; PR body has counts, planted defects, the seven-item checklist.
  - Done: PR #347 (T3-T6) squash-merged to `dev` as `2bb9a9b` on 2026-10-26, head `d1b82cc` (lint, pkgdown, risk-tier green). OpenBLAS gates deferred to the release PR.

### Phase 4: Release readiness (author's release process, outside the pipeline)

- [x] **T7 (M): Dependents** | agents: oracle-qa (scratch-lib runs), manual for missingmed | risk: n/a
  - Acceptance: F-12. `arm.R` scratch-library suites pass for probmed, RMediation, medrobust, medsim, missingmed,
    mediationverse; missingmed#102 merged (`9f77220`).
  - Verify: `Rscript planning/specs/evidence/native-defaults-2026-10-24/arm.R /private/tmp/<dir> <arm>`.
  - Done 2026-10-26: base (v0.14.1) and new (dev `54435df`) scratch libraries; all six dependents have identical per-test
    results, 0 failed, 0 errors (counts: `planning/specs/evidence/native-defaults-2026-10-24/t7-dependents-2026-10-26.csv`).
    missingmed ran from a worktree at the #102 head `4a84e66`; #102 squash-merged to missingmed `dev` as `9f77220`.
    medfit's own suite under the new build: 42 failed, 5 errors in 13 files, all files rewritten in T3-T5 (v0.14.1
    tests asserting the old defaults); `MISSINGMED_DIR=<worktree>` in `arm.R` keeps the run off the main checkout.
- [ ] **T7b (S): Harden the dependents harness** | agents: implementer | risk: n/a | from the 2026-10-26 Codex review
  - Why: `arm.R` `run()` ignores the `system2()` status and never removes an old RDS, so a crashed arm could leave a
    stale pass that the summary reads as current. The T7 evidence itself is fresh (every RDS mtime 14:00-14:21 on
    2026-10-26, one run per arm), so the recorded result stands; the harness is the gap.
  - Acceptance: `run()` deletes its target RDS first, requires status 0, requires a readable RDS with the seven
    expected columns, and `stop()`s (nonzero exit) on any failure; the script records the medfit and dependent head SHAs.
    Planted defect: a dependent path that fails to load makes the script exit nonzero, and an old RDS planted at the
    target path is not accepted. Files: `arm.R`.
  - Verify: run the planted-defect cases, then rerun all arms; per-test results still identical to base.
- [ ] **T8 (S): Release readiness check** | agents: none (author) | risk: n/a
  - Acceptance: date >= 2026-12-24; T7b done; F-6, F-7, F-12 evidence attached to the release PR; `dev -> main` PR runs the
    required gate shards (OpenBLAS, both green on the exact release head; attach run URLs and SHA); T7 rerun on the
    release head if `R/` changed after `54435df`; [BREAKING] #329 closed on release. If anything fails: hold the flip,
    fix first (F-13).

## Not in this plan

- FIML / `missing =`: 0.16.0 candidate; spike against lavaan `missing = "fiml"` first (tracking issue only).
- Removal of the `options(medfit.native_defaults)` shim: 0.16.0.
- CRAN submission: deferred (#83).

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| #320 grew since 0.14.0 (lavaan > 18/60 or OpenMx > 13/60 on the pinned seeds) | High | T1 first; blocks T3 if so |
| lavaan treats the product column differently under `fixed.x`, or the oracle cannot see it | High | T2 before T3; checks 1-4 discriminate, planted defect must trip them |
| Retry-seed change alters which start wins (R-11) | Med | T6 reliability gate; NEWS note |
| OpenBLAS vs reference BLAS divergence | Med | gates on the runner; fixtures at 1e-6 |
| missingmed#102 not merged by release time | Med | T7 blocks T8 |
| Dependents evidence stale or from an older head | Med | T7b fail-closed harness; rerun on the release head if `R/` changed |
| OpenBLAS gates first run only at the release PR (flip changes retry seeds) | Med | accepted, F-7 on the exact head; a red gate holds the flip (F-13), so budget a fix cycle before the 2026-12-24 floor |
| 21-test rewrite exceeds 5 files per commit | Low | split T4 into two commits/tasks |

## Open questions

1. #320: documented limit or blocker (answered by T1).
2. FIML: tracking issue vs separate 0.16.0 plan (default: tracking issue).
3. CLAUDE.md "Active plan" pointer: update after approval (default: yes, as part of T5).
