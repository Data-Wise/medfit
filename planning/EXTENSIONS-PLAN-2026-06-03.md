# medfit Extensions Plan (post-v0.2.0)

**Created:** 2026-06-03 · **Updated:** 2026-08-22 · **Package state:** v0.3.2 accepted +
published on CRAN (2026-07-23). Simple + serial + **parallel** (Ext A) + **interaction/4-way**
(Ext B) mediation all shipped; extraction (lm/glm/lavaan), fitting (GLM), bootstrap
(parametric/nonparametric/plugin), and the generics layer
(`nie/nde/te/pm/paths/coef/vcov/confint/tidy/glance`) are all in place. Ext A and Ext B are
both COMPLETE and merged to `dev` — only Ext C (engine adapters) remains.

This plan supersedes the status framing in `medfit-roadmap.md` (whose detailed Phase 7/7b/7c
*designs* remain the reference — this doc is the prioritized, current **board**).

---

## Guiding principle (unchanged)

> medfit provides **infrastructure, not effect sizes**. Each extension adds a new
> *structure* (class) or *engine* (adapter) and returns a standardized object;
> methodological contributions live in probmed / RMediation / medrobust.

Each extension is a **separate S7 class or adapter** — clean separation, no
over-engineering, type-safe via validators. This is the established medfit pattern
(`MediationData` → `SerialMediationData`).

---

## The board

### 🟢 Quick wins (≤ 1 day each)
| # | Item | Why now |
|---|------|---------|
| Q1 | Refresh `medfit-roadmap.md` header (v0.1.0 → v0.2.0; mark Phases 1–6 done) | Stops the roadmap from misreporting shipped state |
| Q2 | Add a `parallel-mediation` *design stub* section (class sketch below) | The one structure with no design doc yet |
| Q3 | pkgdown: ensure `reference:` lists all v0.2.0 exports + serial article | Website currently pre-serial in places (see website task) |

### ✅ Extension A — Parallel mediation — COMPLETE
**New class:** `ParallelMediationData` (X → M₁..Mₖ → Y, independent mediators).
The natural sibling to `SerialMediationData`; currently the only core structure with
**no design doc**. Indirect effect = Σ aⱼ·bⱼ.

```r
ParallelMediationData <- S7::new_class("ParallelMediationData",
  properties = list(
    a_paths = S7::class_numeric,   # c(a1, a2, ...)
    b_paths = S7::class_numeric,   # c(b1, b2, ...)
    c_prime = S7::class_numeric,
    estimates = S7::class_numeric, vcov = S7::class_matrix,
    # ... standard metadata (treatment, mediators, outcome, n_obs, ...)
  ),
  validator = function(self) {
    if (length(self@a_paths) != length(self@b_paths))
      return("a_paths and b_paths must have equal length")
    NULL
  })
```
**Work:** class + validator → `extract_mediation()` parallel detection (multiple
mediator models, no chaining) → `paths()`/`nie()` sum-of-products → vcov naming
contract (`a1,b1,a2,b2,…`) → tests vs hand-built + lavaan parallel SEM → vignette.
**Spec to write:** `planning/specs/SPEC-parallel-mediation.md`.

### ✅ Extension B — Treatment×mediator interaction / VanderWeele 4-way — COMPLETE
**New class:** `InteractionMediationData`. Full design already in `medfit-roadmap.md §7`
(formulas, class, delta-method SEs, identification notes). Total = CDE + INTref + INTmed + PIE.
**Work:** class + validator (component-sum invariants) → interaction detection in
`extract_mediation()` (`X:M` term) → four-way formulas (continuous Y/M first) →
delta-method SEs (bootstrap already available) → tests vs `regmedint`/`med4way` →
vignette. **Spec:** `planning/specs/SPEC-interaction-fourway-2026-06-03.md` (drafted
2026-06-03; PR split B1 class / B2a lm+SEs / B2b lavaan+docs).

### 🔴 Extension C — Engine adapter: regmedint (1 week) — SPEC'D + GRILLED, next to implement
**Spec:** `planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md` (grilled —
`GRILL-engine-adapter-architecture-2026-08-22.md`). Substantially revised from the original
`§7b–7c` design after a 2026-08-22 adversarial-review + grill pass found the original CMAverse-first
plan rested on an unverified assumption: **CMAverse is not on CRAN**, and its simulation-based
effects (g-formula/IPW) have no correct slot given `nie()`/`nde()`'s live-computed contract
(`a_path*b_path`). Revised scope: extend `fit_mediation(engine=)`'s existing dispatch (no new
registry abstraction, no generic `Decomposition` class) with one **regmedint** adapter (CRAN,
closed-form, already medfit's own Ext B validation target) — verified numerically to map onto
`InteractionMediationData`'s slots with analytical (not bootstrap) SEs.

### ⏸ Extension C.1 — CMAverse adapter (not yet spec'd, blocked)
Deferred from C. Blocked on: (1) CRAN-availability strategy for a non-CRAN `Suggests` dependency,
(2) the engine-native-effects representation problem for simulation-based methods. Do not start
until both are resolved in `SPEC-cmaverse-adapter.md`.

---

## Sequencing & rationale

```
v0.3.2 (CRAN, accepted + published 2026-07-23)
   │
   ├─ Q1–Q3 quick wins ........................ ✅ done
   │
   ├─ A: ParallelMediationData ................ ✅ done (merged to dev)
   │
   ├─ B: InteractionMediationData (4-way) ..... ✅ done (merged to dev)
   │        │
   │        └─ C: regmedint adapter .......... SPEC'D + GRILLED — next to implement
   │                 └─ C.1: CMAverse adapter . blocked (CRAN availability + effect repr.)
```

**Why A before B/C:** Parallel mediation completes the *structural* trio
(simple/serial/parallel) with the least new machinery — no new estimands, just
sum-of-products. B and C introduce new estimands (causal decomposition) and external
deps, so they carry more design + review risk and should follow.

**Ecosystem coordination:** each new class is a downstream opportunity, not a breaking
change — additive only. Per CLAUDE.md, breaking changes need a 2-month notice +
`lifecycle::deprecate_warn()`; none of A/B/C is breaking.

---

## Effort & gates

| Ext | New exports | External deps | Est. | Gate |
|-----|-------------|---------------|------|------|
| A Parallel | `ParallelMediationData` (+ method updates) | none | 1–2 wk | none |
| B Interaction | `InteractionMediationData`, `Decomposition` | none | 1–2 wk | A merged (shared test scaffold) |
| C Adapter | one new `engine_args` param on `fit_mediation()` | regmedint (Suggests) | ~1 wk | B merged |
| C.1 Adapter (deferred) | — (blocked, not spec'd) | CMAverse (Suggests, non-CRAN) | TBD | CRAN-availability + effect-repr. resolved |

All work happens on **feature worktrees off `dev`** (code can't land on `dev`/`main`
directly). Each extension: spec → worktree → TDD → vignette → PR → CRAN-clean check.

---

## Immediate next actions
1. ~~Q1–Q3~~ done (roadmap header refreshed; pkgdown reference verified complete).
2. ~~Extension A~~ **DONE** — class (#34), lm/glm extractor+confint (#36), lavaan
   extractor+vignette+pkgdown (#37) all merged to `dev`.
3. ~~Extension B~~ **DONE** — `InteractionMediationData` class (#38, 35 tests), lm/glm
   extraction+decomposition+delta CI (#39, 27 tests), lavaan extraction+vignette (#40,
   22 tests) all merged to `dev`. Spec: `planning/specs/SPEC-interaction-fourway-2026-06-03.md`.
4. ~~Toolchain: roxygen2 8.0.0 migration~~ **DONE** (issue #35, landed alongside 0.3.x work).
5. **Extension C is spec'd + grilled, next to implement** —
   `planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md` (regmedint adapter; CMAverse
   deferred to Ext C.1, blocked — see `GRILL-engine-adapter-architecture-2026-08-22.md`). No
   worktree open for this yet.

See also: `medfit-roadmap.md` (detailed designs), `CASCADE-cran-flip-2026-06-03.md`
(post-CRAN dependent updates), `MEDIATIONVERSE-PROPOSAL.md` (ecosystem context).
