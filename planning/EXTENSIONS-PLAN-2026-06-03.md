# medfit Extensions Plan (post-v0.2.0)

**Created:** 2026-06-03 · **Package state:** v0.2.0 released to `main`, submitted to CRAN
(awaiting acceptance). Simple + **serial** mediation shipped; extraction (lm/glm/lavaan),
fitting (GLM), bootstrap (parametric/nonparametric/plugin), and the generics layer
(`nie/nde/te/pm/paths/coef/vcov/confint/tidy/glance`) are all in place.

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

### 🟡 Extension A — Parallel mediation (1–2 weeks)
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

### 🟡 Extension B — Treatment×mediator interaction / VanderWeele 4-way (1–2 weeks)
**New class:** `InteractionMediationData`. Full design already in `medfit-roadmap.md §7`
(formulas, class, delta-method SEs, identification notes). Total = CDE + INTref + INTmed + PIE.
**Work:** class + validator (component-sum invariants) → interaction detection in
`extract_mediation()` (`X:M` term) → four-way formulas (continuous Y/M first) →
delta-method SEs (bootstrap already available) → tests vs `regmedint`/`med4way` →
vignette. **Spec to write:** `planning/specs/SPEC-interaction-fourway.md`.

### 🔴 Extension C — Engine adapter architecture + CMAverse (2–3 weeks)
**Design already in `medfit-roadmap.md §7b–7c`** (registry, adapter contract, CMAverse
mapping). Wrap validated external estimators (g-formula, IPW, TMLE) behind one
`engine = "gformula"|"ipw"|...` interface; all return `MediationData`.
**Sequencing:** depends on B (shares the `Decomposition` class + `estimate_mediation()`
front door). Start with the **registry + `.adapter_regression`** (internal, always
available), then the **CMAverse adapter** (Suggests). **Specs:** `SPEC-engine-registry.md`,
`SPEC-cmaverse-adapter.md`.

---

## Sequencing & rationale

```
v0.2.0 (CRAN, in flight)
   │
   ├─ Q1–Q3 quick wins ........................ now, on dev (docs only)
   │
   ├─ A: ParallelMediationData ................ v0.3.0  (independent; do first — closes the structure set)
   │
   ├─ B: InteractionMediationData (4-way) ..... v0.4.0  (introduces Decomposition class)
   │        │
   │        └─ C: Engine registry + CMAverse .. v0.5.0  (builds on B's Decomposition + estimate_mediation())
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
| C Adapters | `estimate_mediation`, engine registry | CMAverse (Suggests) | 2–3 wk | B merged |

All work happens on **feature worktrees off `dev`** (code can't land on `dev`/`main`
directly). Each extension: spec → worktree → TDD → vignette → PR → CRAN-clean check.

---

## Immediate next actions
1. ~~Q1–Q3~~ done (roadmap header refreshed; pkgdown reference verified complete).
2. **Extension A increment 1 — class:** DONE — `ParallelMediationData` + effects + coef/vcov/nobs/show, 34 tests. **PR #34** (`feature/parallel-mediation → dev`).
3. **Extension A increment 2 — extractor + inference:** spec'd in
   `planning/specs/SPEC-parallel-extractor-2026-06-03.md` (defines the `@vcov`
   naming contract that unblocks `confint()` + `extract_mediation()` parallel
   detection). Implement after PR #34 lands.
4. **Toolchain:** roxygen2 8.0.0 migration tracked in **issue #35** (fixes the S7
   `\usage` rendering + the `Config/roxygen2/version` field move, package-wide).
5. Hold B/C specs until A lands (keeps the board focused).

See also: `medfit-roadmap.md` (detailed designs), `CASCADE-cran-flip-2026-06-03.md`
(post-CRAN dependent updates), `MEDIATIONVERSE-PROPOSAL.md` (ecosystem context).
