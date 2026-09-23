# Plan: delta-method effect SEs in `tidy()` and `confint()`

**Date:** 2026-09-23 · **Status:** approved 2026-09-23
**Spec:** [SPEC-tidy-effect-se-2026-09-23.md](SPEC-tidy-effect-se-2026-09-23.md) (approved) ·
**Decisions:** [GRILL-tidy-effect-se-2026-09-23.md](GRILL-tidy-effect-se-2026-09-23.md) D1–D7
**Where:** worktree `~/.git-worktrees/medfit/feature-tidy-effect-se`, branch
`feature/tidy-effect-se` from `dev` (created only on an explicit "make the worktree").

## Approach

Build the helper first and prove it against the oracles in isolation, then move each caller onto
it behind regression pins captured before any refactor. `tidy()` changes last, because it depends
on every class's gradients and on `confint()` being settled.

```
T1 pins ──→ T2 helper (Simple/Serial/Parallel) ──→ T3 helper (Interaction)
                                                        │
                    T5 Serial confint() ←── T4 confint() via helper
                                  │
                                  └──→ T6 tidy() ──→ T7 docs, NEWS, gates, PR
```

All tasks are sequential: T2–T6 touch the same three files, so parallel work would only create
merge conflicts.

## Risks

| Risk | Mitigation |
|---|---|
| Interaction's glm branch has a data-dependent covariate term in the INTref gradient; moving it could change numbers silently | T1 pins current Interaction output to 1e-10 before T3; T3 moves the block verbatim |
| The regmedint branch reads component SEs from its own stored `vcov` diagonal, not from gradients | helper accepts unit gradients (1 on the `cde`/`nie`/... row), so both branches go through one code path |
| Output names differ per method (Parallel `indirect`/`direct`/`total`, Interaction `nde`/`nie`/`total`) | helper uses canonical keys (`nie`, `nde`, `te`, components); each caller maps; T1 pins row names too |
| Serial path named `d` in `tidy()` but `d1` in `@vcov` | gradient builder maps `d`/`d1..dk`; tested with 2 and 3 mediators |
| Bootstrap oracle flakiness | fixed seed, 20,000 draws, 3% tolerance (SE of an SD estimate at that n is ~0.5%) |
| Serial with 3+ mediators is not in `mediation_demo` | T2 adds a small fixed-seed 3-mediator fixture for the serial gradient only |

## Tasks

- [ ] **T1 — Capture regression pins (before any code change).**
  - Acceptance: `tests/testthat/test-effect-se.R` exists with (a) Parallel and Interaction (glm
    and regmedint engines) `confint(parm = "effects")` values and row names pinned from current
    `dev`, (b) Simple NIE/NDE pinned, (c) the D2 pin (Simple TE SE 0.1194 ± 5e-4) marked as the
    one expected failure.
  - Verify: `testthat::test_file("tests/testthat/test-effect-se.R")` → only the D2 pin fails.
  - Files: `tests/testthat/test-effect-se.R`
- [ ] **T2 — Helper with Simple, Serial, Parallel gradients.**
  - Acceptance: `R/effect-se.R` defines `.effect_se(x, terms)` and `.effect_gradients(x)` for the
    three classes, per the spec's gradient table; unknown keys fail via `checkmate`.
  - Verify: new tests pass — Oracle A (lavaan `:=`, 1e-6) for Simple/Serial/Parallel; Oracle B
    (parametric bootstrap SD, 3%) for the same; Serial with 2 and 3 mediators.
  - Files: `R/effect-se.R`, `tests/testthat/test-effect-se.R`
- [ ] **T3 — Interaction gradients in the helper.**
  - Acceptance: `.effect_gradients()` covers `InteractionMediationData`, moving the glm-branch
    gradient block from `confint()` unchanged and returning unit gradients for the regmedint
    branch; keys `cde`, `int_ref`, `int_med`, `pie`, `nde`, `nie`, `te`.
  - Verify: Oracle B for Interaction (glm engine); helper SEs equal the T1-pinned Interaction
    values to 1e-10 for both engines.
  - Files: `R/effect-se.R`, `tests/testthat/test-effect-se.R`
- [ ] **T4 — `confint(parm = "effects")` through the helper (Simple, Parallel, Interaction).**
  - Acceptance: the three methods call `.effect_se()`; warnings/messages and row names unchanged;
    Simple TE now uses the full gradient.
  - Verify: all T1 pins pass, including the D2 pin; existing `test-methods-base.R` passes (update
    only an expectation that encoded the old TE SE, and say so in the commit).
  - Files: `R/methods-base.R`, possibly `tests/testthat/test-methods-base.R`
- [ ] **T5 — New `confint(<SerialMediationData>)`.**
  - Acceptance: `parm = "paths"` (rows `a`, `d` or `d1..dk`, `b`, `c_prime`) and
    `parm = "effects"` (rows `nie`, `nde`, `te`); normal approximation with the same warning as
    the Simple method; `level` validated with `checkmate`.
  - Verify: tests for both `parm` values, 2 and 3 mediators, `level = 0.90`; values match
    `estimate ± z * .effect_se()`.
  - Files: `R/methods-base.R`, `tests/testthat/test-effect-se.R`
- [ ] **T6 — `tidy()` through the helper, all four classes.**
  - Acceptance: every effect/component row has a numeric `std.error`; Serial gains path SEs and a
    `std.error` column; `conf.int = TRUE` no longer returns `NA` or warns for Serial; `tidy()`
    emits nothing; `@details` carries the approximation note, the lm-chain block-diagonal
    sentence, and the "bootstrap PM" note.
  - Verify: consistency test (`tidy()` CIs = `confint()` CIs to 1e-12 after name mapping) and
    `expect_silent()` for all four classes; `glance()` unchanged; no `pm` row in `tidy()`.
  - Files: `R/methods-tidy.R`, `tests/testthat/test-effect-se.R`
- [ ] **T7 — Docs, NEWS, gates, positive control, PR.**
  - Acceptance: NEWS "New features" + "Bug fixes" entries (D7); `devtools::document()` with the
    roxygen churn reverted; positive control run (flip one gradient sign per class → Oracles A
    and B fail) with its transcript saved for the PR body.
  - Verify: full `devtools::test()` 0 failed / 0 errors; `lintr` adds no hits; spelling clean;
    strict check 0/0 with only the Date NOTE; `run_examples(run_donttest = TRUE)` clean; PR to
    `dev` with counts and the positive-control transcript.
  - Files: `NEWS.md`, `man/*.Rd`

## Checkpoints

1. **After T1:** the pins reflect current `dev` exactly (only the D2 pin fails).
2. **After T4:** every existing `confint()` number is unchanged except Simple TE.
3. **After T6:** `tidy()` and `confint()` agree for all four classes; full suite green.
