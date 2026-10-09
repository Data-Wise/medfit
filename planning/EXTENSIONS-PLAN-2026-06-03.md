# medfit Extensions Plan (post-v0.2.0)

**Created:** 2026-06-03 · **Updated:** 2026-09-25 · **Package state:** v0.3.2 on CRAN; **v0.5.0**
released on `main`/GitHub/r-universe (2026-09-25, tag `v0.5.0`, not CRAN-submitted by decision),
carrying #62-#82 on top of 0.4.0. Simple + serial + **parallel** (Ext A) +
**interaction/4-way** (Ext B) + **regmedint engine adapter** (Ext C) + **joint multi-mediator
interactions** (D8(b)) all shipped; extraction (lm/glm/lavaan), fitting (GLM + regmedint), bootstrap
(parametric/nonparametric/plugin), and the generics layer (`nie/nde/te/pm/paths/coef/vcov/confint/tidy/glance`,
with delta-method effect SEs) are all in place. CMAverse (Ext C.1) remains, blocked; Ext D/E are
brainstormed, not spec'd.

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
The natural sibling to `SerialMediationData`; designed in
`specs/SPEC-parallel-extractor-2026-06-03.md` and shipped in #34/#36/#37. Indirect effect = Σ aⱼ·bⱼ.

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
**Spec:** `planning/specs/SPEC-parallel-extractor-2026-06-03.md`.

### ✅ Extension B — Treatment×mediator interaction / VanderWeele 4-way — COMPLETE
**New class:** `InteractionMediationData`. Full design already in `medfit-roadmap.md §7`
(formulas, class, delta-method SEs, identification notes). Total = CDE + INTref + INTmed + PIE.
**Work:** class + validator (component-sum invariants) → interaction detection in
`extract_mediation()` (`X:M` term) → four-way formulas (continuous Y/M first) →
delta-method SEs (bootstrap already available) → tests vs `regmedint`/`med4way` →
vignette. **Spec:** `planning/specs/SPEC-interaction-fourway-2026-06-03.md` (drafted
2026-06-03; PR split B1 class / B2a lm+SEs / B2b lavaan+docs).

### ✅ Extension C — Engine adapter: regmedint — COMPLETE
**Spec:** `planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md` (grilled —
`GRILL-engine-adapter-architecture-2026-08-22.md`). Substantially revised from the original
`§7b–7c` design after a 2026-08-22 adversarial-review + grill pass found the original CMAverse-first
plan rested on an unverified assumption: **CMAverse is not on CRAN**, and its simulation-based
effects (g-formula/IPW) have no correct slot given `nie()`/`nde()`'s live-computed contract
(`a_path*b_path`). Revised scope: extend `fit_mediation(engine=)`'s existing dispatch (no new
registry abstraction, no generic `Decomposition` class) with one **regmedint** adapter (CRAN,
closed-form, already medfit's own Ext B validation target). **Shipped 2026-08-22 (PR #59,
`08351f1`)** — `fit_mediation(engine = "regmedint")` returns `MediationData`/
`InteractionMediationData`; a follow-up rode along promoting `m_star` to a first-class
`fit_mediation()` argument (`planning/specs/SPEC-m-star-argument-2026-08-22.md`). Implementation
found `regmedint::vcov()` (v1.0.2) returns variances only (no off-diagonal covariance), correcting
the spec's original delta-method-via-full-vcov assumption — see the SPEC's own "Implementation
correction" note. Version bumped 0.3.2→0.4.0; tagged `v0.4.0` and released on GitHub 2026-08-23
(not CRAN-submitted).

### ✅ D8(b) — Joint effects for multi-mediator X:M products — COMPLETE (released in 0.5.0)
**New class:** `JointMediationData` + `joint_effects()`. Joint natural effects of all mediators
as a block (VanderWeele & Vansteelandt 2014) when an outcome model with two or more mediators
carries treatment-by-mediator products; no per-mediator split of the NIE. Spec
`planning/specs/SPEC-joint-mediator-interactions-2026-09-23.md`, plan
`PLAN-joint-mediator-interactions-2026-09-23.md`. PR A #76 (`fff0ab7`, core) and PR B #77
(`b40444e`, methods/docs) merged to `dev` 2026-09-24. lavaan multi-mediator fits with products
still error.

### ✅ Post-0.4.0 fixes and docs — COMPLETE (released in 0.5.0)
`mediation_demo` dataset (#62-#65, #67); delta-method effect SEs in `tidy()`/`confint()` for all
classes (#70) with lavaan alias fixes (#69, #71, #73), wrapped-product detection (#74),
`sandwich`/`vcov_fun` on every worker plus identity-link and unused-`m_star` guards (#75);
Methods and Formulas article (#79); four-way factor covariates (#78); joint SEs with
caller-supplied `data =` (#80). **Two behavior changes:** serial `te()`/`pm()` sum every path,
new `nie(type = "total")` (#81); `confint(parm = "paths")` finds rows by alias and errors instead
of position-guessing (#82). Articles evaluate at site build (`b888ffe`).

### ⏸ Extension C.1 — CMAverse adapter (not yet spec'd, blocked)
Deferred from C. Blocked on: (1) CRAN-availability strategy for a non-CRAN `Suggests` dependency,
(2) the engine-native-effects representation problem for simulation-based methods. Do not start
until both are resolved in `SPEC-cmaverse-adapter.md`. (Verified 2026-09-24: CMAverse is not
in DESCRIPTION `Suggests`, no adapter code in `R/`.)

### ⏸ Extension D — Multilevel/clustered mediation (brainstormed, not spec'd)
`MultilevelMediationData` from lme4/nlme fits, 1-1-1 first. See
`planning/specs/BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md`. Not blocked on
Ext C. No lme4 code in `R/` yet.

### ⏸ Extension E — Longitudinal/time-varying mediation (brainstormed, not spec'd)
Same brainstorm. Largest new estimand; was meant to reuse an Ext C adapter registry that Ext C
did not build, so its reuse needs are open until its own spec is written.

---

## Sequencing & rationale

```
v0.3.2 (CRAN, accepted + published 2026-07-23)
   │
   ├─ Q1–Q3 quick wins ........................ ✅ done
   │
   ├─ A: ParallelMediationData ................ ✅ done (#34/#36/#37)
   │
   ├─ B: InteractionMediationData (4-way) ..... ✅ done (#38/#39/#40)
   │        │
   │        └─ C: regmedint adapter .......... ✅ done (PR #59) → v0.4.0 (GitHub, 2026-08-23)
   │                 └─ C.1: CMAverse adapter . blocked (CRAN availability + effect repr.)
   │
   ├─ D8(b): JointMediationData ............... ✅ done (#76/#77) → v0.5.0
   │
   ├─ 0.5.0 release ........................... ✅ done (GitHub + r-universe, 2026-09-25)
   │
   └─ D: multilevel / E: longitudinal ......... brainstormed, not spec'd
```

**Why A before B/C:** Parallel mediation completes the *structural* trio
(simple/serial/parallel) with the least new machinery — no new estimands, just
sum-of-products. B and C introduce new estimands (causal decomposition) and external
deps, so they carry more design + review risk and should follow.

**Ecosystem coordination:** each new class is a downstream opportunity, not a breaking
change — additive only. Per CLAUDE.md, breaking changes need a 2-month notice +
`lifecycle::deprecate_warn()`; none of A/B/C or D8(b) is breaking. #81 and #82 change results
(bug fixes, documented as behavior changes with ecosystem notes in NEWS).

---

## Effort & gates

| Ext | New exports | External deps | Est. | Gate |
|-----|-------------|---------------|------|------|
| A Parallel | `ParallelMediationData` (+ method updates) | none | 1–2 wk | none |
| B Interaction | `InteractionMediationData`, `decompose()` (no `Decomposition` class was built) | none | 1–2 wk | A merged (shared test scaffold) |
| C Adapter | `engine_args` and `m_star` params on `fit_mediation()` | regmedint (Suggests) | ~1 wk | ✅ B merged, C done |
| D8(b) Joint | `JointMediationData`, `joint_effects()` | none | done | ✅ released in 0.5.0 |
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
5. ~~Extension C~~ **DONE** (2026-08-22) — regmedint adapter merged (PR #59, `08351f1`); `m_star`
   promoted to a first-class `fit_mediation()` arg alongside it. Released as 0.4.0 (2026-08-23).
   `planning/specs/SPEC-engine-adapter-architecture-2026-08-22.md` (regmedint adapter; CMAverse
   deferred to Ext C.1, blocked — see `GRILL-engine-adapter-architecture-2026-08-22.md`).
6. ~~D8(b) joint effects + post-0.4.0 fixes~~ **DONE** (#62-#82, merged to `dev`).
7. ~~0.5.0 release~~ **DONE** (2026-09-25, #84, tag `v0.5.0`; GitHub-only).
8. **Next: Ext D spec** (multilevel); Ext C.1 stays blocked.

See also: `medfit-roadmap.md` (detailed designs), `archive/CASCADE-cran-flip-2026-06-03.md`
(post-CRAN dependent updates; historical), `MEDIATIONVERSE-PROPOSAL.md` (ecosystem context).
