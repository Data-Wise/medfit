# GRILL: medfit 0.11.0 release and S7 1.0 readiness (2026-10-17)

Target: `planning/PLAN-0.11.0-scope-2026-10-16.md` and `planning/PLAN-s7-1.0-readiness-2026-10-17.md`, after Checkpoint 2
passed. One question at a time; the author's answers are the decisions. Recommended answer first on every question.

## Decisions

| # | Branch | Question | Decision | Consequence accepted |
|---|---|---|---|---|
| G1 | Weakest recommendation | CRAN 0.3.2 still ships results earlier releases fixed as wrong (#81, #82) and the hold's triggers are passive | Submit 0.11.0 to CRAN after a one-week soak (recommended) | A CRAN review of a much larger package (native engine, nloptr Imports, OpenMx Suggests) and the strict-check and cran-comments routine; fixes the wrong results on CRAN and unblocks probmed's `medfit (>= 0.3.0)` gate |
| G2 | Riskiest assumption | `run-gates.R` is the single release gate but nothing enforces it; T5b showed a gate sit red unseen | CI job running `run-gates.R --sim` on PRs to `main` (recommended) | About 8 min of runner time per release PR, a workflow that installs lavaan, OpenMx and nloptr, and a decision on making it a required check |
| G3 | Implementation regret | The freeze covers the `?medfit-syntax` grammar, but categorical support (roadmap B1-B3) needs new grammar and naming | Reserve additive extensions in the freeze list and pin the current canonical names with a test (recommended) | About an hour; commits B1-B3 to an additive design (no renaming of dummy columns or `m:x` rows) |

## Open Questions

- (filled as the grill proceeds)
