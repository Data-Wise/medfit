---
decisions:
  - id: R19-1
    topic: book gate R6
  - id: R19-2
    topic: few-clusters harness timing
  - id: R19-3
    topic: dependent suites R5
  - id: R19-4
    topic: numeric-neutrality gate N1
  - id: R19-5
    topic: known limits in the release notes
---

# Decisions: 0.19.0 release grill (2026-11-16)

Target: `planning/PLAN-0.19.0-release-checklist-2026-11-16.md`. Open decisions from
`planning/specs/BRAINSTORM-release-0.19.0-2026-11-16.md`. Answers come from the maintainer, through the grill.

## Evidence found before the questions

- A single-mediator two-level fit still returns `TwoLevelMediationData` (`R/extract-lavaan-twolevel.R:483`). Only k >= 2
  takes the new branch, so the minor bump to 0.19.0 stands (brainstorm decision 1, settled by the code).
- `man/TwoLevelParallelMediationData.Rd`, `vignettes/articles/model-twolevel.qmd` and NEWS each say "experimental", and
  the class is not pinned in `test-api-freeze.R` (brainstorm decision 2, settled by the code).
- None of probmed, RMediation, missingmed, mediationverse or medsim references `TwoLevel*` in its `R/` directory.

## Decision ledger

| # | Question | Decision | Consequence |
|---|---|---|---|
| R19-1 | What does gate R6 (the book) require? | Render `medfit-book` `draft` against the candidate, and record a one-line waiver in the checklist: the parallel-mediator content follows the release | R6 can't go silently unmet again (0.17.0 did); a book section on parallel mediators is follow-up work in `medfit-book` |
| R19-2 | Does the release wait for the few-clusters harness? | No. R2 gains a check: any harness work on `dev` at the candidate has its `tests/sim/` files Rbuildignored and its testthat test skipped on CRAN | no delay; internal tooling can't leak into the tarball or slow CRAN checks |
| R19-3 | How much of R5 (dependent suites) runs? | probmed and RMediation only, per-test counts against published 0.18.0. This departs from the five-suite R5 of 0.17.0 and 0.18.0 | the release runs faster; a regression in missingmed, mediationverse or medsim from the shared-code changes (`R/bootstrap.R`, `R/effect-se.R`, `R/methods-tidy.R`, `R/generics-effects.R`, `R/methods-base.R`) would go unseen until their own CI runs |
| R19-4 | Does R2 check that existing classes give the same numbers? | Yes, a new gate N1: install 0.18.0 and the candidate in separate libraries, run `tidy()`, `confint()` and `nie()` on `mediation_demo` for `MediationData`, `SerialMediationData`, `ParallelMediationData` and single-mediator `TwoLevelMediationData`, and require agreement to 1e-10 | a silent number change in shared code stops the release before the tag; this partly covers what the narrower R5 (R19-3) gives up |
| R19-5 | What do the release notes say about limits? | A "Known limits" block in NEWS and the GitHub release: experimental API; the between-within contrast is descriptive, not a test; the within-only object when the treatment or mediator ICC < 0.01; no serial two-level mediators; no native two-level fitting (S4, NO-GO); no latent mediators (S5, NO-GO); FIML numerically verified but not statistically admitted. Each limit links to the model page or its plan | users of a new experimental feature see its edges in one place; R1 writes the block, R9 copies it into the release |

Brainstorm decisions 1 (version 0.19.0) and 2 (experimental label) were settled by the code evidence above and need no
row; gate E1 checks both.

## Open questions

- None. The parallel-mediator book section (R19-1) and the narrowed dependent coverage (R19-3) are follow-ups, not open
  questions.
