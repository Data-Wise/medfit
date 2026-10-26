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
T7 (dependents: missingmed#102, scratch-lib) -------------------------------------> T8 (release readiness)
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

- [ ] **T1 (S): Re-measure #320** | agents: gates (dispatch + read), oracle-qa (interpret) | risk: n/a (measurement)
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
- [ ] **T2 (S): Verify lavaan `fixed.x = TRUE` product-column handling (E-5)** | agents: oracle-qa | risk: n/a
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

### Checkpoint A: after T1-T2
- [ ] #320 decision recorded; E-5 verified or turned into a T3 requirement; human review before T3.

### Phase 2: The flip

- [ ] **T3 (M): Flip the formals and the resolver** | agents: implementer -> oracle-qa -> gates | risk: **high**
  - Acceptance: F-1 to F-4. Unset `fixed_x`/`meanstructure` resolve to the new values unconditionally (E-14);
    `options(medfit.native_defaults)` ignored with an obsolete note; `medfit_warning_default_change` no longer fires;
    an explicit `FALSE`/`NULL` is preserved; explicit `fixed_x = TRUE` still errors on `~~`/`~1` on exogenous variables.
  - Planted defects: (a) resolver overwriting an explicit `FALSE`; (b) default left as old value in `fit_mediation()` only.
    Both must be caught by tests.
  - Verify: `Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-native-defaults.R")'`,
    `test-api-freeze.R`.
  - Files: `R/fit-sem.R`, `R/native-defaults.R`, `tests/testthat/test-api-freeze.R`, `test-native-defaults*.R`,
    `tests/sim/risk-files.txt` (if `R/fit-sem.R` absent).
- [ ] **T4 (M): Rewrite the 21 tests from the Checkpoint B list; drop T5a setup chunks** | agents: implementer -> oracle-qa -> gates | risk: **high**
  - Acceptance: F-5. Tests state their settings explicitly where they depend on them; frozen fixtures pinned at 1e-6;
    full suite green with counts reported against the `dev` baseline.
  - Planted defect: a rewritten test must fail when the old default is restored.
  - Verify: `Rscript -e 'devtools::test()'`.
  - Files: up to the 21 test files named in the 0.14.0 plan Checkpoint B (split into two tasks if more than 5 files per commit).

### Checkpoint B: after T3-T4
- [ ] Full suite green; `pre-docs` gates PASS; oracle-qa PASS with both planted defects caught; human review.

### Phase 3: Docs and conventions

- [ ] **T5 (M): Docs rewrite** | agents: docs -> gates (`final`) | risk: n/a (docs-consistency tests apply)
  - Acceptance: F-9, F-11. NEWS behavior-change entry (what moves / what does not); AIC/BIC convention documented
    with the lavaan difference; missing-data note (listwise, no FIML); lavaan-comparison rows reversed; crosswalk;
    cookbook 18/19; tutorial step 9; mini-book; guide-changes; `?"medfit-syntax"`.
  - Planted defect: a doc claim contradicting the new default must fail `test-cookbook-consistency.R` or the model-page tests.
  - Verify: `Rscript -e 'devtools::document(); devtools::test(filter = "refcard|cookbook|model-pages|guide")'`, `lintr`.
  - Files: `NEWS.md`, `man/`, `vignettes/articles/*.qmd`, `R/sem-syntax-help.R` (split in two if over 5 files).
- [ ] **T6 (M): E-12 reliability gate + oracle matrix on the final tree** | agents: gates, oracle-qa | risk: **high** (evidence)
  - Acceptance: F-6, F-7. Oracle matrix re-run: 0 block rows. `gates (rest)` and `gates (reliability)` green on the
    OpenBLAS runner; reliability acceptance rate non-inferior to the last green run.
  - Planted defect: `MUTANT=` switches in the gate scripts still trip (positive control).
  - Verify: `Rscript tests/sim/native-defaults-oracle.R`, `gh workflow run gates.yaml --ref feature/native-defaults-flip`.
  - Files: `tests/sim/` pins only if a gate needs updating.

### Checkpoint C: PR to `dev`
- [ ] All reports `Verdict: PASS`; `git status` clean; `git diff --name-only origin/dev...HEAD` covers every cited file.
- [ ] Ask the user before pushing and before opening the PR; PR body has counts, planted defects, the seven-item checklist.

### Phase 4: Release readiness (author's release process, outside the pipeline)

- [ ] **T7 (M): Dependents** | agents: oracle-qa (scratch-lib runs), manual for missingmed | risk: n/a
  - Acceptance: F-12. `arm.R` scratch-library suites pass for probmed, RMediation, medrobust, medsim, missingmed,
    mediationverse; missingmed#102 merged (currently OPEN).
  - Verify: `Rscript planning/specs/evidence/native-defaults-2026-10-24/arm.R /private/tmp/<dir> <arm>`.
- [ ] **T8 (S): Release readiness check** | agents: none (author) | risk: n/a
  - Acceptance: date >= 2026-12-24; F-6, F-7, F-12 evidence attached to the release PR; `dev -> main` PR runs the
    required gate shards; [BREAKING] #329 closed on release. If anything fails: hold the flip, fix first (F-13).

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
| 21-test rewrite exceeds 5 files per commit | Low | split T4 into two commits/tasks |

## Open questions

1. #320: documented limit or blocker (answered by T1).
2. FIML: tracking issue vs separate 0.16.0 plan (default: tracking issue).
3. CLAUDE.md "Active plan" pointer: update after approval (default: yes, as part of T5).
