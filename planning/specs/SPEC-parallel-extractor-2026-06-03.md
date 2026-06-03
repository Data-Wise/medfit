# SPEC: Parallel mediation extractor + inference

**Status:** Draft · **Created:** 2026-06-03 · **Author:** Davood Tofighi (with Claude Code)
**Depends on:** PR #34 (`ParallelMediationData` class — merged/in review)
**Unblocks:** `confint(ParallelMediationData)`, `extract_mediation()` parallel detection
**Plan:** `planning/EXTENSIONS-PLAN-2026-06-03.md` → Extension A (implementation increment 2)

---

## 0. Why this spec exists

PR #34 shipped the `ParallelMediationData` *class* (foundation) but deferred two
pieces, both of which depend on a **canonical `@vcov` naming contract** that only
the extractor can define. This spec fixes that contract and the extraction logic so
the deferred work becomes implementable without rework.

Parallel mediation: `X -> M_j -> Y` for *k* independent mediators
(`j = 1..k`). Total indirect = `sum(a_j * b_j)`. Unlike serial chains, mediators are
**not** regressed on one another.

## 1. The `@vcov` naming contract (the linchpin)

The extractor MUST name `@estimates` / `@vcov` rows with stable path aliases so that
`paths()`, `coef()`, and `confint()` can locate each coefficient **by name**:

```
a1, b1, a2, b2, ..., ak, bk, c_prime
```

- This matches the existing `paths(ParallelMediationData)` ordering (already implemented).
- `a_j` = coefficient of `X` in the model for `M_j`.
- `b_j` = coefficient of `M_j` in the outcome model.
- `c_prime` = coefficient of `X` in the outcome model.
- Decision: positional `a{j}/b{j}` indices follow the order of the `mediators` vector
  (mirrors the serial `d1,d2,...` convention from `SPEC-lm-serial-extractor`).

## 2. Covariance structure

Two fitting routes (mirror the serial extractor's two paths):

| Route | `@vcov` structure |
|-------|-------------------|
| **lavaan** (single SEM) | full covariance — off-diagonals among all `a_j`, `b_j`, `c_prime` preserved from `lavInspect(fit, "vcov")`. |
| **lm/glm** (separate regressions) | **block-structured**: each mediator model `M_j ~ X` contributes `var(a_j)`; the single outcome model contributes the joint covariance of all `b_j` and `c_prime` (they share one equation, so `cov(b_j, b_{j'})` and `cov(b_j, c')` are real and preserved). Cross-equation `cov(a_j, b_{j'})` = 0 by construction (separate fits). |

> Note the contrast with serial: in parallel/lm the `b_j` are **jointly** estimated in
> the outcome model, so their mutual covariances are non-zero (unlike the per-equation
> `a_j` which are independent across mediator models).

## 3. `extract_mediation()` parallel detection

Input API (mirrors serial's `mediator_models`):

```r
extract_mediation(
  fit_m1,                              # first mediator model: M1 ~ X (+ C)
  model_y = fit_y,                     # outcome: Y ~ X + M1 + M2 + ... (+ C)
  treatment = "X",
  mediator = c("M1", "M2"),            # parallel mediators
  mediator_models = list(fit_m2),      # remaining mediator models: M2 ~ X (+ C)
  structure = "parallel"               # NEW: disambiguates parallel vs serial
)
```

**Detection decision:** require an explicit `structure = c("auto","serial","parallel")`
argument (default `"auto"`). In `"auto"`, infer from the mediator models' predictors:
- if `M_{j}` is a predictor in the model for `M_{j+1}` → **serial**;
- if each `M_j ~ X (+ C)` with no other mediators on the RHS → **parallel**.
Ambiguous/mixed → error asking the user to set `structure` explicitly.
(`"auto"` is a convenience; the explicit value is authoritative.)

## 4. `confint()` method (now implementable)

With §1's naming contract, `confint(ParallelMediationData)` mirrors the
`MediationData`/`SerialMediationData` methods:
- `parm = "paths"` → normal-approx CI for each `a_j, b_j, c_prime` using
  `sqrt(diag(@vcov))` located **by alias name**.
- `parm = "effects"` → delta-method (or bootstrap) CI for `nie = sum(a_j b_j)`:
  `Var(nie) = g' Σ g` where `g = d(nie)/d(theta)` has entries `b_j` (wrt `a_j`) and
  `a_j` (wrt `b_j`); `Σ` is the `@vcov` sub-block over the `a*/b*` aliases.
- `method = "boot"` → defer to `bootstrap_mediation()`.

## 5. Acceptance criteria

- [ ] `extract_mediation(..., structure="parallel")` returns `ParallelMediationData`
      with `@vcov` named `a1,b1,...,c_prime` for both lavaan and lm/glm fits.
- [ ] `"auto"` correctly distinguishes parallel from serial; mixed → informative error.
- [ ] lm/glm: `cov(b_j, b_{j'})` and `cov(b_j, c')` non-zero; `cov(a_j, b_{j'})` = 0.
- [ ] `confint()` paths + effects (delta) + boot; CIs bracket truth in simulation.
- [ ] Tests vs hand-built objects AND a lavaan parallel SEM; `R CMD check` clean.
- [ ] Vignette section + pkgdown reference entry.

## 6. Out of scope (later)
- Treatment×mediator interaction in parallel (folds into Extension B).
- Mixed serial+parallel structures (separate class/spec if ever needed).

## References
- `SPEC-lm-serial-extractor-2026-05-31.md` (the analogous serial work — reuse patterns).
- `EXTENSIONS-PLAN-2026-06-03.md`; `ORCHESTRATE-parallel-mediation.md` (class increment).
