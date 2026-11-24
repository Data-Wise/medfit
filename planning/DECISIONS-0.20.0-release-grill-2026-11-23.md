---
decisions:
  - id: R20-1
    topic: cluster formal of fit_sem (E1)
  - id: R20-2
    topic: dependent suites R5
  - id: R20-3
    topic: book gate R6
  - id: R20-4
    topic: few-clusters guidance in user docs
  - id: R20-5
    topic: known limits in the release notes
---

# Decisions: 0.20.0 release grill (2026-11-23)

Target: `planning/PLAN-0.20.0-release-checklist-2026-11-21.md`. Answers come from the maintainer, through the grill.
Authorization (P1): the maintainer wrote "Release" on 2026-11-23, taken to mean the drafted 0.20.0. T8 is in PR #520
(entry gate P0), to be merged by the maintainer.

## Evidence found before the questions

- `cluster` is already the last name in `pin_fit_sem_args` in `tests/testthat/test-api-freeze.R`, so its name and order
  are frozen against moving without a deprecation.
- No dependent touches the two-level path. probmed has an unrelated `cluster` argument; RMediation and missingmed call
  single-level `fit_sem()` (missingmed also `mbco_sem()`, `missingmed/R/mbco_sem.R:222`); medsim has an unrelated
  `cluster` run mode; mediationverse has no reference.
- User docs already cover few clusters in `cookbook.qmd`, `extraction.qmd` and `guide-troubleshooting.qmd`, including
  `medfit_warning_between_weak`.
- The 0.19.0 book gate was a render plus a waiver (`medfit-book` `draft` `a8226ff`, 2026-11-17); the number checks were
  not run.

## Decision ledger

| # | Question | Decision | Consequence |
|---|---|---|---|
| R20-1 | What status does 0.20.0 give the `cluster` formal of `fit_sem()` (E1)? | Pinned name and order, behavior experimental | The existing pin stays; NEWS and the Rd pages say two-level behavior, refusals and results may change without the deprecation period; renaming or moving `cluster` still needs a deprecation |
| R20-2 | Which dependent suites run (R5)? | probmed, RMediation and missingmed, per-test counts against published 0.19.0 | Covers the one dependent that calls `fit_sem()` and `mbco_sem()` directly on a release that edits `fit-sem.R` and `sem-fit.R`; one more suite of runtime than 0.19.0 |
| R20-3 | What does the book gate require (R6)? | Render `medfit-book` `draft` against the candidate and record a waiver line: the native two-level chapter follows the release; number checks not run | Same as 0.19.0; R6 cannot go silently unmet; the book's numbers stay unchecked |
| R20-4 | Where does the T8 few-clusters guidance appear for users? | A short hedged note in `model-twolevel.qmd` plus a Known limits line; the full table stays in planning | Users get the caution; the note goes into docs PR G; the note says the simulations used the lavaan adapter and no bootstrap arm |
| R20-5 | What goes in the Known limits block? | The R1 list plus the T8 specifics: unequal small clusters (n = 5) fail often even at J = 50; between-level coverage is below nominal; within-only result below ICC .01; S4b and the cluster bootstrap are not in this release | Honest and traceable to #520; longer notes |

Note on R20-5 numbers: the shipped behavior is the unconstrained fit (P0), so any coverage figure in the notes comes from
the P0 rows of `planning/studies/few-clusters/T8-README.md`, not the P1 medians; P1 (the floor) is not shipped and S4b
is deferred.

## Open Questions

- Docs PR G (the R20-4 note and the Known limits wording) is not yet written.
- Release entry gate P0 waits on the merge of #520; P2 waits on this file merging into `dev`; P4, P5 and P6 are
  unchecked.
