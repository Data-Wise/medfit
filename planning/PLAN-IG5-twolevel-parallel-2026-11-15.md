# Plan: IG5, parallel mediators in the two-level adapter

**Date:** 2026-11-15 · **Spec:** [SPEC-IG5-twolevel-parallel-2026-11-15.md](specs/SPEC-IG5-twolevel-parallel-2026-11-15.md)
**Status:** spec approved 2026-11-15 (D1-D5 as recommended); T1-T4 done, T5 (docs) is next.

Each task runs through the `medfit-orchestrator` pipeline (implement, oracle QA, gates, docs) on its own
`feature/*` branch from `dev`.

| Task | Content | Depends on | Acceptance |
|---|---|---|---|
| - [x] T1 | Class `TwoLevelParallelMediationData`, validator, S4 registration, print; contract pin | spec (approved) | validator rejects length mismatches and duplicate mediators; contract test lists the properties |
| - [x] T2 | Extraction: vector key rows, `2(2k+1)` vcov block, ICC rule (D2), contrast rule (D5), serial refusal | T1 | lavaan oracle on paths and `@vcov`; k = 1 equals `TwoLevelMediationData`; planted key swap caught |
| - [x] T3 | Effects and SEs: `nie(type =)`, `nde`, `te`, `pm`, `paths`, `decompose`, gradient builder, `tidy`/`confint`/`summary` | T2 | lavaan `:=` oracle per level and contrast, at 1e-6; zeroed cross-mediator block caught |
| - [x] T4 | `twolevel_statistic()` for k mediators (D4) (PR #463) | T3 | parametric and refit statistics equal `nie()` at the estimate; bootstrap runs on the fixture |
| - [x] T5 | Docs: model page, troubleshooting row, cookbook recipe, reference card, NEWS, gap register | T4 | docs-consistency tests pass; each quoted message is triggered |
