# GRILL: medfit 0.11.0 release and S7 1.0 readiness (2026-10-17)

Target: `planning/PLAN-0.11.0-scope-2026-10-16.md` and `planning/PLAN-s7-1.0-readiness-2026-10-17.md`, after Checkpoint 2
passed. One question at a time; the author's answers are the decisions. Recommended answer first on every question.

## Decisions

| # | Branch | Question | Decision | Consequence accepted |
|---|---|---|---|---|
| G1 | Weakest recommendation | CRAN 0.3.2 still ships results earlier releases fixed as wrong (#81, #82) and the hold's triggers are passive | Submit 0.11.0 to CRAN after a one-week soak (recommended) | A CRAN review of a much larger package (native engine, nloptr Imports, OpenMx Suggests) and the strict-check and cran-comments routine; fixes the wrong results on CRAN and unblocks probmed's `medfit (>= 0.3.0)` gate |

## Open Questions

- (filled as the grill proceeds)
