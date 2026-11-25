---
decisions:
  - id: R21-1
    topic: MLR label and the estimator pin
  - id: R21-2
    topic: dependent suites R5
  - id: R21-3
    topic: book gate R6
  - id: R21-4
    topic: known limits in the release notes
  - id: R21-5
    topic: release scope and tooling in the notes
---

# Decisions: 0.21.0 release (2026-11-25)

Target: `planning/PLAN-0.21.0-release-checklist-2026-11-25.md`. A grill-lite: defaults chosen by the preparer under the
maintainer's standing authorization (2026-11-25: "finish all the new release tasks; you have all the git permissions;
I approved; do not stop and ask"; "Cut 0.21.0 release"). The maintainer can overturn any row before the tag.

## Evidence found before the decisions

- `estimator` is already the last name in `pin_fit_sem_args` in `tests/testthat/test-api-freeze.R` (appended by #542).
- The lavaan plan (`PLAN-lavaan-parity-0.21.0-2026-11-24.md`) keeps "Estimators other than ML" Partial (ML, MLR).
- The 0.20.0 grill (R20-2, R20-3) set probmed, RMediation and missingmed as dependents and a book waiver.
- `origin/main..origin/dev` touches risk files `R/fit-sem.R`, `R/sem-fit.R`, `R/sem-mlr.R`, `R/sem-model.R`,
  `R/sem-parse.R` and `tests/sim/gates.csv`.

## Decision ledger

| # | Question | Decision (default) | Alternative rejected | Consequence |
|---|---|---|---|---|
| R21-1 | How is MLR labeled, and what happens to the `estimator` pin? | Supported, not experimental, for its stated class (single-level, complete data, linear equality constraints); the lavaan row stays Partial. The `estimator` formal stays pinned in name and position, appended last; no new pin | Label MLR experimental; add a value-level pin of `c("ML", "MLR")` | Adding a value (such as MLM) later is not a breaking change; refusals are classed and documented; the pin file is unchanged |
| R21-2 | Which dependent suites run (R5)? | probmed, RMediation and missingmed, per-test counts on the candidate and on `v0.20.0` | Only probmed and RMediation | The same set as 0.20.0; missingmed calls `fit_sem()` and `mbco_sem()` directly, and #542 edits `fit-sem.R` and `sem-fit.R` |
| R21-3 | What does the book gate require (R6)? | A waiver line: no chapter for MLR; render and number checks not run, as in the 0.20.0 grill | Render `medfit-book` `draft` against the candidate | R6 cannot go silently unmet; the book's numbers stay unchecked (the 0.17.0 R6 item stays not met) |
| R21-4 | What goes in the Known limits block? | MLR refused combinations and the classed errors; no scaled fit indices; product models still NA chi-square; two-level route experimental (and refused under MLR); FIML not statistically admitted; CRAN hold | Omit limits that did not change this release | Honest and traceable to #540 and #542; each line is true of the shipped code |
| R21-5 | Do the notes mention tooling and CI changes? | One non-user-facing bullet naming #536, #538, #539, #541 | Leave them out of NEWS | Every merged change since 0.20.0 is accounted for |

## Open Questions

- R5 and R7 evidence (dependent counts, the first hosted OpenBLAS run of the `mlr` gate) is not yet collected.
