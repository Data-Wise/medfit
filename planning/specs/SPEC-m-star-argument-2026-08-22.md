# SPEC: `m_star` as a first-class `fit_mediation()` argument

**Date:** 2026-08-22 · **Status:** implemented · **Branch:** `feature/engine-adapter-architecture`
**Origin:** `BRAINSTORM-version-and-mstar-2026-08-22.md` item 2.
**Depends on:** Extension C (`engine = "regmedint"`, `engine_args`), same unreleased 0.4.0 cycle.

---

## 1. Problem

`fit_mediation()` returns an `InteractionMediationData` whenever `formula_y` carries a
treatment-by-mediator term, and that class exposes `@m_star` — the reference mediator level at
which the CDE/INTref split is evaluated:

```
CDE     = theta1 + theta3 * m*
INTref  = theta3 * (E[M | X = 0] - m*)
```

`m*` is reachable through `extract_mediation()` (both the lm/glm and lavaan methods take
`m_star = 0`) but **not** through `fit_mediation()`. `.fit_mediation_glm()` calls
`extract_mediation()` without it, so the glm path is hardwired to `m_star = 0`.

Verified behavior before this change:

```r
fit_mediation(Y ~ X * M, M ~ X, data = d, treatment = "X", mediator = "M", m_star = 1)
#> ERROR: unused argument (m_star = 1)
```

A hard error, raised by `glm.control()` after `...` routes the argument into `stats::glm()`. There
is no silent behavior to preserve, so this change is **purely additive** for the glm path.

The regmedint engine reached the same quantity by a different name, `engine_args$m_cde`. Two
spellings of one concept.

---

## 2. Non-goals

- **`decomposition=` stays unexposed.** Grill decision #9 rejected it and this is not a re-open:
  #9 rejected a *mode* argument, one that changes which class comes back. `m_star` is a *value*
  argument that changes a number inside a class already being returned.
- No change to `extract_mediation()`'s own signature — it already takes `m_star`.
- No lavaan engine for `fit_mediation()` (none exists).

---

## 3. Decisions

### D1 — One knob, not two

`m_star` becomes the argument. `m_cde` is **removed** from the regmedint adapter's recognized
`engine_args` names; supplying it errors with a pointer to `m_star`.

*Rationale:* `m_cde` was only ever regmedint's local spelling. Accepting both invites an object
whose `@m_star` disagrees with the value the engine actually used. This costs nothing to do now:
`engine_args` is itself unreleased (it ships in 0.4.0 alongside the engine), so no deprecation
cycle is owed. `c_cond` and the other six names are unaffected.

### D2 — The mechanism asymmetry is documented, not hidden

| Engine | When `m_star` is applied | Path |
|---|---|---|
| `"glm"` | **extraction-time** | four-way is computed from the fitted coefficients, then evaluated at `m*` |
| `"regmedint"` | **fitting-time** | passed as regmedint's `m_cde`, consumed by its closed-form `cde` estimator |

Same observable effect, different route. Stating this is what makes one argument routing to both
coherent rather than a leaky abstraction.

### D3 — Refuse a value that cannot be used

`m_star` has meaning only for the four-way decomposition. When it is **explicitly supplied** and
the fit will not produce an interaction, `fit_mediation()` errors rather than silently dropping it.

*Rationale:* consistent with the adapter's existing stance — it already refuses `weights` and
`se_type != "model"` on the regmedint engine rather than ignoring them. A silently-ignored numeric
argument is the failure mode `checkmate`-everywhere exists to prevent. Detection uses
`missing(m_star)`, so the default is never second-guessed.

The interaction is detected from `formula_y` via `.find_interaction_term_formula()`; for the
regmedint engine an explicit `engine_args$interaction` overrides that detection, and the check
honors the override.

### D4 — Signature hygiene

Appended **after `engine_args`, before `...`**. No existing named argument moves, so positional
callers reaching through `se_type` keep working.

```r
fit_mediation(formula_y, formula_m, data, treatment, mediator,
              engine = "glm", family_y, family_m, weights = NULL,
              se_type = c("model", "sandwich"), engine_args = list(),
              m_star = 0, ...)
```

---

## 4. Implementation surface

| File | Change |
|---|---|
| `R/fit-glm.R` | signature + `assert_number` + D3 guard + thread to both engines; `.fit_mediation_glm()` gains `m_star` and passes it to `extract_mediation()` |
| `R/aab-generics.R` | matching stub signature + `@param m_star` + details block (both roxygen blocks merge into `fit_mediation.Rd`) |
| `R/fit-regmedint.R` | `.adapter_regmedint()` and `.regmedint_build_args()` gain `m_star`; `m_cde` leaves `known` with a redirect error |
| `tests/` | new tests, both engines + the D3 guard + the D1 redirect |
| `NEWS.md`, vignettes | document the argument and the asymmetry |

---

## 5. Acceptance criteria

1. `fit_mediation(Y ~ X * M, ..., m_star = m)` returns `@m_star == m` on **both** engines.
2. The two engines agree on `@cde` and `@int_ref` at the same `m_star`, to delta-method tolerance.
3. `nde()`, `nie()`, `te()`, `pm()` are **invariant** to `m_star` — only the CDE/INTref split moves.
4. `fit_mediation(Y ~ X + M, ..., m_star = 1)` errors (D3); the same call without `m_star` does not.
5. `engine_args = list(m_cde = ...)` errors with a message naming `m_star` (D1).
6. Omitting `m_star` reproduces byte-identical output to the pre-change glm path.
7. `R CMD check --as-cran` and the strict flavors stay 0/0/0.
