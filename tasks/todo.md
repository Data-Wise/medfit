# medfit 0.9.0 task list (native observed mean structure)

Plan: `tasks/plan.md`. Spec plan: `planning/specs/PLAN-native-mean-structure-2026-10-12.md`. The closed 0.8.0 list is `planning/archive/TODO-0.8.0-closed-2026-10-12.md`.

## Done
- [x] T1: `has_mean` flag and frozen v0.8.0 values (#170)
- [x] `anova()` nesting fixes (#171, #173); `y ~ 1 + x` amendment approved

## Slices
- [x] S1: observed intercepts end to end (parse `y ~ 1 + x`, tri-state `meanstructure`, likelihood, counts, SEs, messages)
- [x] S2: scale robustness, centered gate, sweep to 1e5 (**Checkpoint A**)
- [x] S3: `~0*1` restriction, logLik fix, `anova()` across status, shared labels
- [x] S4: weights and sandwich
- [ ] S5: constraints, MBCO, re-fit plumbing, lavaan parity (**Checkpoint B**)
- [ ] S6: methods, extraction, four-way refusal, OpenMx, worked example
- [ ] S7: docs and close-out (**Checkpoint C**)

## Follow-ups from T1
- [ ] Tolerance and platform: say whether 1e-12 is relative; confirm the fixture on the ubuntu CI BLAS before Checkpoint A
- [ ] Seed: `.sem_seed()` must not hash the `m` vector when the flag is off; add a frozen retry case
