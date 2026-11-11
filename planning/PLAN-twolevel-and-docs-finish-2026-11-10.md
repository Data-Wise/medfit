# Implementation plan: finish the two-level adapter and the documentation (2026-11-10)

Format: `agent-skills:planning-and-task-breakdown` (acceptance criteria, verification, dependencies, size, checkpoints).
Placed in `planning/` because `tasks/plan.md` and `tasks/todo.md` are the closed `fixed_x` plan (CLAUDE.md); nothing there
is overwritten. Task state lives in this file's checkboxes; GitHub PRs are only linked. Sources: the S2 spec and plan on
branch `claude/plan-multilevel-394-f40512`, `PLAN-docs-completion-2026-11-10.md`, `GOALS-2026-11-10.md` (authorizations,
out of scope, stop conditions: they apply to every task here).

## Progress (updated 2026-11-10, afternoon)

| Task | State | Evidence |
|---|---|---|
| 1 PR3 bootstrap helper | done | #404 merged `76120d96`; full suite on its install 208 files / 2313 tests / 0 failed; decision recorded: inadmissible refits kept, oracle on percentile half-width (maintainer, 2026-11-10) |
| 2 PR4 docs | done | #403 merged `cac3e38f`; full suite on its install 210 files / 2327 tests / 19663 expectations / 0 failed; version bump deliberately not in this PR (dev keeps the released version under "(development version)"; bump belongs to release-prep) |
| 3 lavaan floor | done | #405 merged `b5490aa7`; floor `lavaan (>= 0.7-3)` = oldest version in CI; 0.7-2 passed locally, 0.6-19 and 0.6-12 fail (no multilevel cluster bootstrap); 0.7-0 and 0.7-1 unverified |
| 4 D2 book audit | done | merged into dev (book contract paragraphs) |
| 5 D2b chapter 9 | done | #407 merged |
| 6 D2b chapter 10 | done | #409 merged (`a2ac942e`) |
| 7 D7 book CI render | dropped | maintainer decision 2026-11-10: the book is not published online; #408 closed unmerged, no book workflow |
| 7b book move | done | book moved to private `Data-Wise/medfit-book` (Quarto, tome scaffold, 34 commits of history kept, HTML 10 chapters and 278-page PDF verified); removal PR #410 merged `55c9a8b2` on green exact head `d06aeaea`, ancestry verified |
| 8 D6 final gate | done (partial) | check_pkgdown clean, urlchecker 48/48, hosted pkgdown green on #410; spelling 4 old false positives (covariate's, overidentified, reparameterization, rowwise) not added to WORDLIST; no separate local full evaluated-site build or link crawl beyond hosted pkgdown |
| Checkpoint A | done | dev at `55c9a8b2`: full suite 210 files / 2321 tests / 19611 expectations / 0 failed / 7 skipped; lint 0 on isolated install; risk-tier low |
| Checkpoint B | done with D7 replaced | D7 dropped by maintainer (book not published); everything else merged |

Also merged this session outside the task list: #402 (helper-name clash fix, `ce898ac7`), docs D1 #398, D3 #399, D5 #401.

## Overview

Land the last two slices of the lavaan two-level adapter (issue #394: PR3 bootstrap helper, PR4 docs and 0.17.0), then
finish the docs (book chapters 9 and 10, book CI render, final gate). Done so far on `dev`: #396, #397, #402, #400 (two-level
class, extraction, O8 oracle, effects) and #398, #399, #401 (docs D1, D3, D5).

## Architecture and sequencing decisions

- PR3 merges before PR4 (PR4 documents the `twolevel_statistic()` export); PR4 is rebased by merging `dev` in, never
  by rebasing.
- Docs units that share files (`_pkgdown.yml`, refcard, `NEWS.md`, `guide-changes`) merge one at a time.
- Every numeric claim in docs reuses an existing oracle transcript or is checked against lavaan or `lm`; no new fixed.x SE gap
  size is stated (measured about 1% and 0%).
- Risk tier normal for all tasks (no `sem-*.R`, no `gates.csv`); no optimizer-class change, so no seven-item checklist.

## Phase 1: finish the two-level adapter

### Task 1: PR3 bootstrap helper reviewed and merged
**Description:** `twolevel_statistic(fit, what)` and the public-call bootstrap tests (branch `feature/twolevel-pr3-bootstrap`).
**Acceptance criteria:**
- [x] The exact public parametric and cluster-nonparametric calls run end to end and the PR body quotes both transcripts.
- [x] Independent hand cluster bootstrap (O4) agrees on the same resamples; parametric SE agrees with the PR2 delta SE within
      Monte Carlo error.
- [x] Planted defects (no duplicate-cluster relabeling, resampling rows, swapped levels) each fail a test.
- [x] Failed or between-unidentified replicates are counted and reported, not dropped silently.
**Verification:**
- [x] Touched tests pass in the PR's tree; full suite on the PR head: 0 failures except the two known order-dependent
      `tidy()` deprecation tests (judge against the `dev` baseline).
- [x] Lint 0 findings on an isolated install; `Rscript tests/sim/risk-tier.R` low or normal.
- [x] Hosted checks (lint, pkgdown, risk-tier) green on the exact head; leak scan clean; mergeable.
**Dependencies:** none (#396, #397, #400, #402 merged). **Files:** `R/` bootstrap helper, `NAMESPACE`, `man/`, one refcard row,
one `_pkgdown.yml` entry, `test-twolevel-bootstrap.R`, `test-refcard-coverage.R`, dependents-contract table, `NEWS.md`.
**Size:** M. **Action:** review, merge with `--match-head-commit`, verify ancestry on `origin/dev`, remove its worktree.

### Task 2: PR4 documentation PR brought up to date and merged
**Description:** `model-twolevel.qmd`, cookbook recipe 23, refcard/glossary/methods/troubleshooting/guide-changes rows, NEWS,
`CLAUDE.md` lines, version 0.17.0 (branch `feature/twolevel-pr4-docs`).
**Acceptance criteria:**
- [x] `dev` merged in (PR3 included); conflicts in `NEWS.md`, `_pkgdown.yml`, refcard resolved; `twolevel_statistic()` documented as shipped.
- [x] The page states: fixed-slope estimand (differs from `ab + sigma_ab`), latent versus manifest means, contrast is descriptive,
      the 50-cluster warning is a judgment; no SE-gap number.
- [x] Every quoted message has a `test-guide-*` check; the worked example's transcript is in the PR body and can fail.
- [x] Version string consistent everywhere (`grep` the repo for the old string).
**Verification:**
- [x] Doc-tier tests (`guide-|model-pages|refcard|cookbook|methods|twolevel|dependents`) 0 failures; spelling; `pkgdown::check_pkgdown()`.
- [x] Rendered page and changed articles checked for broken internal links (quarto, if available; otherwise state not run).
- [x] Hosted checks green on the exact head; leak scan clean; mergeable.
**Dependencies:** Task 1. **Size:** L (docs, many small edits; split into two PRs if the diff exceeds about 15 files).

### Task 3: lavaan floor (spec Q6)
**Description:** set the minimum lavaan version for the two-level adapter in `DESCRIPTION`.
**Acceptance criteria:**
- [x] Two-level tests were run on the oldest lavaan in the CI matrix, and the floor equals that version or the PR states it as unverified.
**Verification:** [ ] the run's version and test counts quoted; [ ] hosted checks green. **Dependencies:** Task 2. **Size:** XS.
If the oldest lavaan cannot be installed locally, record "floor unverified" in `NEWS.md` and stop on this task only.

### Checkpoint A: two-level done
- [ ] #394 slices PR3 and PR4 merged; on `dev`: full suite 0 failures (except the two known), lint clean on an isolated install,
      `risk-tier` low or normal, `pkgdown` green.
- [ ] `.STATUS`, `planning/medfit-roadmap.md`, `CLAUDE.md` (class table, status paragraph) show the final state.
- [ ] Carried-forward questions listed: equated-`a`-or-`b` contrast rule, algebraic cross-level equalities. Do not decide them.

## Phase 2: finish the documentation

### Task 4: D2, book contract paragraphs
**Description:** rerun `AUDIT-minibook-coverage-2026-10-20.md`'s method over `R/sem-*.R` and `NEWS.md` changes since 2026-10-20; add reader-facing paragraphs for each missing or partial contract.
**Acceptance criteria:** [ ] each gap in the audit table has a paragraph or an explicit "not needed" reason; [ ] every number in new text is checked against an independent computation.
**Verification:** [ ] `test-native-book.R` and doc tests pass; [ ] book renders; [ ] checks green. **Dependencies:** Checkpoint A. **Size:** M.

### Task 5: D2b, book chapter 9 (lavaan adapter and `TwoLevelMediationData`)
**Acceptance criteria:** [ ] parameter-table keying, joint-covariance sub-block, contrast SE, the O8 hand likelihood as the worked oracle; [ ] book retitled, preface and `_quarto.yml` updated; [ ] `test-native-book.R` extended (chapter listed, setup chunk runs).
**Verification:** [ ] chapter code runs after its setup chunk alone; [ ] book renders; [ ] checks green. **Dependencies:** Task 4 (shared book files). **Size:** M.

### Task 6: D2b, book chapter 10 (2-1-1 cluster mediation)
**Acceptance criteria:** [ ] `ClusterMediationData`, NIE = a x b_between, own and spillover with the large-cluster caveat, Kenward-Roger, cluster bootstrap; [ ] numbers match `test-cluster-211.R` oracles.
**Verification:** as Task 5. **Dependencies:** Task 5. **Size:** M.

### Task 7: D7, book CI render (DROPPED 2026-11-10: the book moved to a private repository and is not published; #408 closed)
**Acceptance criteria:** [ ] `.github/workflows/book.yaml` renders HTML and PDF, uploads artifacts; [ ] triggers only on PRs touching `book/**` and on release; [ ] no new cost on unrelated PRs.
**Verification:** [ ] workflow runs green on a PR that touches `book/`; [ ] a PR that does not touch it does not trigger it. If the PDF job fails twice, ship the HTML job and stop on the PDF job with the log.
**Dependencies:** Task 6. **Size:** S.

### Task 8: D6, final gate pass
**Acceptance criteria:** [ ] `inst/WORDLIST` spelling, `urlchecker::url_check()`, `pkgdown::check_pkgdown()`, full evaluated site build with internal-link check, book render: all counts reported; [ ] real defects fixed in follow-up `docs:` PRs.
**Verification:** [ ] quoted commands and counts; [ ] what was not run is stated. **Dependencies:** Tasks 4-7. **Size:** M.

### Checkpoint B: docs done
- [ ] All Phase 2 PRs merged on green exact heads; plan statuses ticked; `.STATUS`, roadmap, `PLAN-docs-completion` updated.
- [ ] Final report: merged PR links, branches and worktrees left for the maintainer to delete, what was not verified.

## What is next (written 2026-11-10 evening, after Checkpoint B)

State of `dev` at `55c9a8b2`: two-level adapter and docs complete; 0.17.0 not bumped or released. Open: issue #394 (S4 native two-level fitter and S5 latent mediators are not started), older issues #369, #357, #360, #320, #249, and PRs #376 (NEWS wording), #381 and #346 (dependabot).

Candidates, in recommended order:

1. **Hardening PR from the two-level code review** (correctness first; not yet fixed): the proportion-mediated threshold `.Machine$double.eps` is too lax (`R/generics-effects.R`), `lavaan_version` records the installed rather than the fitting version, `.twolevel_admissible` swallows errors, the refit environment is `rlang::caller_env()`, unclassed `stop()` in `twolevel_statistic()`, validator gaps, an unguarded `sqrt(diag(vcov))`, and redundant `source_package`/`data` slots.
2. **Implement the two decided contrast/equality rules** (decided 2026-11-10, see the ledger): QUEUED behind the hardening PR (both edit `R/classes-twolevel.R`; one at a time). Start a test-first session after the hardening PR merges, then update book chapter 9 in `medfit-book`.
3. **Housekeeping:** triage #369, #357, #360, #320, #249 (close or restate), decide #376, merge or close the two dependabot PRs, close or retitle #394 to the remaining slices.
4. **0.17.0 release prep** (separate release goal, not authorized yet): version bump, NEWS, tag, `main`, GitHub release.
5. **Deferred and unauthorized:** FIML admission studies, the Hopper stage-0 run, medsim P0, native two-level fitter (S4), latent mediators (S5).
6. **Book** (private repo `Data-Wise/medfit-book`): follow-up session running (render check, outline).

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| PR3 and PR4 conflict in `NEWS.md`, `_pkgdown.yml`, refcard | Med | merge PR3 first, merge `dev` into PR4, keep PR3's edits to one line each |
| A worker's reported counts are not what the PR tree shows | High | each review reruns tests in the PR's tree; counts in the final report come from those reruns |
| PDF toolchain fails on the hosted runner | Low | HTML job ships alone after two attempts |
| Old lavaan unavailable locally | Low | record floor as unverified; do not guess |
| Statistical claim creeps into docs | High | docs reuse existing oracle transcripts; the stop condition fires on any claim without one |

## Open questions (not decided here; do not decide unattended)

- DECIDED 2026-11-10 (grill, `GRILL-multilevel-mediation-2026-11-10.md` section "Contrast and equality grill"): the contrast is `NA` only when both `a` and `b` are equated across levels; algebraic equalities are detected by the estimated path difference and its variance being effectively zero (revised after the Codex review; not the correlation). Not yet implemented.
- Whether a 0.17.0 release (tag, GitHub release, `main`) follows; a separate release goal, not part of this plan. The version bump to 0.17.0 was not made in PR4 (see Progress).
- FIML admission, Hopper, medsim P0: unauthorized, out of scope.
