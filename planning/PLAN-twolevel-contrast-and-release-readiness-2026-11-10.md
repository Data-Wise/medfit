# Plan: two-level contrast rule, equality detection and release readiness (2026-11-10)

Format: `agent-skills:planning-and-task-breakdown`. Placed in `planning/`; `tasks/` is the closed `fixed_x` plan. Follows
`PLAN-twolevel-and-docs-finish-2026-11-10.md` (Checkpoint B met, `dev` at `55c9a8b2`) and the decisions in
`GRILL-multilevel-mediation-2026-11-10.md`, section "Contrast and equality grill". Authorizations and stop conditions of
`GOALS-2026-11-10.md` apply; release, tag, `main`, CRAN, FIML admission, Hopper and medsim stay out of scope.

## Overview

Three pieces of work remain on the lavaan two-level adapter (issue #394, slice S2) before it is fit to ship in 0.17.0:

1. a hardening PR for eight review findings (in flight: session `medfit-twolevel-hardening`, branch `feature/twolevel-hardening`);
2. implementing the two decided statistical rules (contrast is `NA` only when both `a` and `b` are equated across levels;
   algebraic equalities detected by alias-row correlation);
3. keeping the private book (`Data-Wise/medfit-book`, chapter 9) and the docs consistent with those rules.

## Decisions already made (do not reopen)

- C-Q1: contrast = a_w*b_w - a_b*b_b returned unless both `a` and `b` are equated; then `NA` (constrained).
- C-Q2 (REVISED after the Codex adversarial review, 2026-11-10): `a` or `b` is recorded in `cross_level_equal` when the estimated
  difference of its two alias rows AND the variance of that difference are both effectively zero (scale-aware tolerances, set against the
  oracle fits), in addition to the two existing label-based routes. The first version (|correlation| within 1e-8 of 1) was rejected:
  correlation -1, or +1 between proportional but unequal paths, does not imply equality and would silently turn an estimable contrast into `NA`.
- Inadmissible refits are kept in the cluster bootstrap; the percentile interval is the recommended summary.
- Version bump belongs to release prep, not to feature PRs.

## Phase 1: hardening PR (in flight)

### Task 1: review and merge the hardening PR
**Acceptance criteria:**
- [ ] each of the eight findings has a test that failed before the fix and a planted defect that fails after it is removed;
- [ ] the two undecided-then-decided contrast items are NOT touched in this PR;
- [ ] NEWS entry under the development version; no version bump.
**Verification:** full suite on an isolated install of the PR head (baseline on `dev`: 210 files, 2321 tests, 0 failed, 7 skipped,
`NOT_CRAN=true`); lint 0; `Rscript tests/sim/risk-tier.R <changed files>` low or normal; hosted checks green on the exact head;
leak scan clean. **Dependencies:** none. **Size:** M. **Action:** review in its own tree, merge `--match-head-commit`, verify ancestry.

## Phase 2: implement the decided rules (starts after Task 1 merges; both touch `R/classes-twolevel.R`)

### Task 2: contrast rule
**Description:** `.twolevel_contrast_available()` becomes `isTRUE(between_identified) && !all(c("a", "b") %in% cross_level_equal)`.
`print`, `tidy()`, `twolevel_statistic("nie_contrast")` and the `medfit_error_twolevel_constrained` check follow it.
**Acceptance criteria:**
- [ ] with only `a` equated (shared label), the contrast equals a(b_w - b_b) and its delta SE equals lavaan's `:=` defined parameter within 1e-4;
- [ ] the same with only `b` equated (separate oracle fit; the gradient and the cross-level covariance cancellation differ): contrast and delta SE
      equal both lavaan's `:=` and a hand delta method on the joint vcov within 1e-4;
- [ ] with both equated, the contrast is `NA` and `twolevel_statistic()` raises the classed error;
- [ ] a planted defect (rule reverted to "either equated") fails a test.
**Verification:** touched tests; full suite; lint; risk-tier. **Dependencies:** Task 1. **Size:** S.

### Task 3: numeric equality detection
**Description:** detect equated `a`/`b` from the alias rows' correlation in the extraction (`R/extract-lavaan-twolevel.R`).
**Acceptance criteria:**
- [ ] a lavaan fit constrained by `a1 - a2 == 0` is flagged in `cross_level_equal`, and both detection routes (labels, equality) still agree with it;
- [ ] criterion: estimated difference and its variance both effectively zero (scale-aware); NOT the correlation;
- [ ] not flagged: a pair with correlation -1, a pair of proportional unequal paths (correlation +1), an unconstrained pair with correlation just inside
      1 - 1e-8 but a nonzero difference; each is a test;
- [ ] a planted defect (correlation-only rule, or tolerance 1e-2) fails a test; the tolerances are documented.
**Verification:** as Task 2. **Dependencies:** Task 2 (same file). **Size:** S.

### Task 4: docs follow the rules
**Description:** `model-twolevel.qmd`, methods section, troubleshooting row, `NEWS.md`, `CLAUDE.md` mention; every quoted message has a
`test-guide-*` check. **Acceptance criteria:** [ ] the page states the contrast rule and the tolerance; [ ] no number is stated
without an oracle transcript. **Dependencies:** Tasks 2, 3. **Size:** S.

### Checkpoint C: rules shipped on dev
- [ ] Tasks 1-4 merged on green exact heads; `dev` full suite 0 failed (baseline above plus new tests), lint 0, risk-tier low.

## Phase 3: book and housekeeping

### Task 5: book chapter 9 follows the rules (repo `Data-Wise/medfit-book`)
**Acceptance criteria:** [ ] the contrast paragraph matches Task 2; [ ] the chapter's equated-path chunks run against the `dev` install
(`scripts/render-check.sh` passes); [ ] PR #1 (render check and outline) is reviewed and merged first. **Release dependency:** the reviewed
chapter update, rendered against the exact release candidate, is a gate of Task 7 (no release candidate with the package and the book disagreeing).
**Dependencies:** Checkpoint C. **Size:** S.

### Task 6: issue and PR triage (medfit)
**Description:** #369, #357, #360, #320, #249: close with evidence or restate; #376 decide; dependabot #381 and #346: merge or close;
retitle or close #394 to the unstarted slices (S4 native fitter, S5 latent mediators).
**Acceptance criteria:** [ ] each item has a recorded disposition and a link to the merged evidence; [ ] nothing closed without a
quoted merged PR or test. **Dependencies:** none. **Size:** S.

## Phase 4: release readiness (NOT authorized; planning only)

### Task 7: 0.17.0 release checklist, written not executed
**Acceptance criteria:** [ ] a checklist file (version bump, NEWS, CITATION/DESCRIPTION dates, tag, GitHub release, `main` merge) exists; [ ] each
gate is named with its evidence and its stop condition, modeled on the 0.16.0 release record: built-package `R CMD check` (strict flavors),
platform matrix and no-Suggests jobs on the exact head, both simulation shards (`gates (rest)`, `gates (reliability)`), hosted coverage on the
release PR, evaluated site build with an inspected link check, pinned dependent suites (probmed, RMediation) against the candidate, the book
render (Task 5) against the candidate; [ ] no step is run. **Dependencies:** Checkpoint C, Task 5. **Size:** XS.

## Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Hardening and contrast PRs conflict in `R/classes-twolevel.R` | Med | strict ordering: Task 1 merges before Task 2 starts |
| Equality detector flags a pair that is merely correlated (-1, proportional, near +1) | High (silent wrong NA) | criterion is difference and its variance, not correlation; planted negative, proportional and just-inside tests (Codex review, finding 1) |
| Delta SE with a one-equated path double-counts the shared parameter | High (wrong SE) | oracle: lavaan `:=` and a hand delta method on the joint vcov before any doc states a number |
| Book chapter 9 drifts from the package | Med | `render-check.sh` runs the chapter against the `dev` install; update in the same week |
| Worker counts differ from the PR tree | High | every review reruns tests in the PR's own tree |

## Open questions

- Should `cross_level_equal` also record the detection route (label, equality, correlation) for diagnostics?
- What scale-aware tolerances for "difference and its variance effectively zero" hold on the oracle fits (lavaan's constrained vcov can carry finite-difference noise)? Set them against the oracle fits, not by guess.
- Does the one-equated contrast need a different caveat in the docs ("descriptive, not a test") when the shared path is `a`?
