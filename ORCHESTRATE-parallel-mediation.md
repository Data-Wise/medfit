# ORCHESTRATE: ParallelMediationData (Extension A, medfit v0.3.0)

**Worktree:** `~/.git-worktrees/medfit/feature-parallel-mediation`
**Branch:** `feature/parallel-mediation` (off `dev`)
**Source plan:** `planning/EXTENSIONS-PLAN-2026-06-03.md` → Extension A
**Created:** 2026-06-03

## Goal
Add the third core mediation *structure* — **parallel** mediation
(`X → M₁..Mₖ → Y`, independent mediators). Indirect effect = Σ aⱼ·bⱼ.
Completes the structural trio: simple (`MediationData`) → serial
(`SerialMediationData`) → **parallel (`ParallelMediationData`)**. Additive, non-breaking.

## Increments
- [x] **I1 — Class + validator** (`R/classes.R`): `ParallelMediationData` S7 class,
      `a_paths`/`b_paths` equal-length ≥ 2, square vcov, unique mediators, sigma checks.
- [x] **I2 — Effects methods** (`R/generics-effects.R`): `nie` (Σ aⱼbⱼ), `nde` (c'),
      `te`, `pm` (zero-guard), `paths` (named `a1,b1,a2,b2,…,c_prime`).
- [x] **I3 — Registration** (`R/zzz.R`): `S7::S4_register(ParallelMediationData)`.
- [x] **I4 — Tests** (`tests/testthat/test-parallel-mediation.R`): construction,
      validator rejections, effect identities (nie+nde=te), paths naming.
- [x] **I5 — Docs**: roxygen `@export` + example; `NEWS.md` entry; `document()`.
- [ ] **Follow-up (next PR, noted not done here):** `extract_mediation()` parallel
      detection (multiple independent mediator models); `coef`/`vcov`/`confint`/`print`
      methods for the class; pkgdown reference entry; vignette. Tracked in EXTENSIONS-PLAN.

## Done-when
`devtools::document()` clean, `devtools::test()` green for the new file, class exported,
NEWS updated. PR `feature/parallel-mediation → dev`.

> Note: implemented in-session per explicit user direction (override of the usual
> "ORCHESTRATE → stop → new session" handoff). Scope deliberately bounded to the
> foundational class + effects; extraction/methods are the next increment.
