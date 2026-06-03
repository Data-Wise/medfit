# SPEC: Treatment×mediator interaction — VanderWeele four-way decomposition

**Status:** Draft (for a future increment) · **Created:** 2026-06-03 · **Author:** Davood Tofighi (with Claude Code)
**Plan:** `planning/EXTENSIONS-PLAN-2026-06-03.md` → **Extension B** (gate: Extension A merged ✓ — #34/#36/#37)
**Design source:** `planning/medfit-roadmap.md §7` (formulas, class sketch, identification notes)
**Reuses (do NOT reimplement):** the Extension A machinery —
`.expand_vcov_with_aliases()` (`R/utils.R:41-78`), the `structure`-style auto-detection pattern
(`.classify_multimediator_structure*`), and the delta-method `confint()` skeleton
(`confint(ParallelMediationData)` in `R/methods-base.R`).

---

## 0. Why this spec exists

Extension A closed the **structural** trio (simple / serial / parallel). Extension B adds the
first **estimand** extension: when treatment `X` and mediator `M` interact, the total effect splits
into four pieces (VanderWeele 2014). This is a new S7 class plus the formulas, extraction, and
standard errors to populate it — all for **simple** mediation with an `X:M` term (interaction with
serial/parallel structures is explicitly out of scope, §8).

The good news: the inferential core is **not new**. The two interaction components are
cross-equation coefficient products (`INTmed = θ₃β₁`, `PIE = θ₂β₁`), exactly the shape parallel
mediation already solved. The vcov assembly, the lm-vs-lavaan covariance divergence, and the
delta-method `confint()` all carry over from PR #36/#37.

## 1. Scope (MVP) and non-goals

**In scope (MVP):**
- **Continuous** outcome `Y` and **continuous** mediator `M`; **binary** treatment `X` (0 → 1).
- Single mediator (simple structure) with an `X:M` term in the outcome model.
- Engines: **lm/glm (Gaussian)** and **lavaan**, mirroring the Ext A two-route pattern.
- Four-way components (CDE, INTref, INTmed, PIE) + derived NDE/NIE/TE, with delta-method SEs and
  `bootstrap_mediation()` as the robust fallback.
- Configurable reference mediator level `m_star` (default `0`); covariates evaluated at their
  sample means.

**Out of scope (defer / separate spec):**
- Binary or survival `Y`, binary `M` (the roadmap’s "High complexity" rows §7.9) — non-linear link
  closed forms differ; flag with an informative `stop()` if requested.
- Interaction combined with serial/parallel structures.
- An abstract `Decomposition` container class. The EXTENSIONS-PLAN names one for Ext B, but a
  single concrete `InteractionMediationData` (one class per structure, matching the established
  pattern) is sufficient here and avoids over-engineering. **Decision:** introduce the shared
  `Decomposition` abstraction in **Extension C** (engine adapters), where multiple engines must emit
  a common decomposition type. Record this in the PR description so C knows where the seam is.

## 2. The class — `InteractionMediationData`

Per `medfit-roadmap.md §7.4`. Key points / refinements:

- Path slots: `a_path` (β₁: X→M), `b_path` (θ₂: M→Y main), `c_prime` (θ₁: X→Y main),
  `interaction` (θ₃: X×M).
- Component slots: `cde`, `int_ref`, `int_med`, `pie`; derived `nde`, `nie`, `total_effect`;
  reference `m_star`.
- Standard metadata slots identical to `MediationData` (`estimates`, `vcov`, `sigma_m`, `sigma_y`,
  `treatment`, `mediator`, `outcome`, `mediator_predictors`, `outcome_predictors`, `data`,
  `n_obs`, `converged`, `source_package`).
- **`sigma_m`/`sigma_y` must be `S7::class_numeric | NULL`** and the validator must guard length-0,
  per gotcha #1 in `[[s7-medfit-gotchas]]` (`class_numeric | NULL` defaults to `numeric(0)`, not
  `NULL`).
- **Validator** (the value-add of this class — algebraic invariants, §7.4):
  - `length(interaction) == 1`;
  - `|(cde + int_ref + int_med + pie) - total_effect| < tol`;
  - `|(cde + int_ref) - nde| < tol`;
  - `|(int_med + pie) - nie| < tol`.
  Use a relative-or-absolute tolerance (e.g. `1e-8 * max(1, |total_effect|)`) so large-scale data
  doesn’t trip an absolute `1e-10`.
- **`total_effect` is defined as the decomposition sum** (CDE+INTref+INTmed+PIE), which equals the
  model-implied marginal total effect `θ₁ + θ₃·E[M|X=1-ish] + θ₂β₁` under the linear model.
  Document that this is the *model-based* total, not a separately fitted `Y~X` slope.
- `print` method at source time (S3) ✓; if a `show` (S4) method is wanted, register it in `.onLoad`
  after `S7::S4_register()` with a local `show <- methods::show` bind — gotcha #2.
- Register in `R/zzz.R`: `S7::S4_register(InteractionMediationData)` **before** `methods_register()`.

## 3. Four-way formulas (continuous Y, M; binary X)

From `medfit-roadmap.md §7.3`, reference level `m*` (default 0), covariates `c` at their means:

| Effect | Formula |
|--------|---------|
| **CDE(m\*)** | `θ₁ + θ₃·m*` |
| **INTref** | `θ₃·(β₀ + β₁·0 + β₂ᵀc̄ − m*)` = `θ₃·(E[M | X=0, c̄] − m*)` |
| **INTmed** | `θ₃·β₁` |
| **PIE** | `θ₂·β₁` |
| NDE | `CDE + INTref` |
| NIE | `INTmed + PIE` |
| TE | `CDE + INTref + INTmed + PIE` |

- `β₀` = mediator-model intercept; `β₂ᵀc̄` = covariate contribution at sample means; with no
  covariates and `m*=0`, `INTref = θ₃·β₀`.
- **θ₃ = 0 sanity check** (must be a test): CDE = NDE = θ₁; INTref = INTmed = 0; NIE = PIE = θ₂β₁ —
  i.e. it collapses to the standard simple-mediation decomposition. This is the bridge to
  `MediationData` and a strong correctness anchor.

## 4. Extraction — interaction detection

Mirror Ext A’s explicit-arg + auto pattern. Add to the `extract_mediation()` lm/glm/lavaan paths:

- A reference-level arg `m_star = 0` and (optional) `decomposition = c("auto", "four_way", "two_way")`.
  **`"auto"`** inspects the outcome model for an `X:M` term: present → `InteractionMediationData`
  (four-way); absent → existing `MediationData` (unchanged behavior). `"four_way"` errors if no
  interaction term is found; `"two_way"` forces the legacy path.
- **Interaction-term name resolution:** lm/glm name the term `X:M` *or* `M:X` depending on formula
  order — resolve θ₃ by checking both (`paste0(treatment, ":", mediator)` and the reverse) in
  `names(coef(model_y))`. lavaan: the `:` interaction appears as an `op == "~"` row whose `rhs` is
  the product term; resolve analogously.
- Preserve all existing `MediationData` outputs when no interaction is present — this must be a
  **backward-compatibility** guarantee (regression risk exactly like PR #36, where inserting a
  detection branch upstream broke existing error paths — gotcha #5). Detection must be conservative
  and never change the no-interaction return.

## 5. `@vcov` naming contract + assembly

Aliases (named rows/cols of `@estimates`/`@vcov`), reusing `.expand_vcov_with_aliases()`:

```
a (β₁), b (θ₂), c_prime (θ₁), theta3 (θ₃)
```

- **Source mapping:** `a → m_<treatment>`; `b → y_<mediator>`; `c_prime → y_<treatment>`;
  `theta3 → y_<interaction-term>`. Plus `b0 (β₀)` from `m_(Intercept)` if INTref SEs need the
  intercept (see §6).
- **Covariance structure (the Ext A divergence repeats):**
  - **lm/glm** — block-diagonal across the two separate fits: `cov(β₁, θ_*) = 0`; within `model_y`,
    `cov(θ₁, θ₂), cov(θ₁, θ₃), cov(θ₂, θ₃)` are preserved.
  - **lavaan** — single joint SEM: **all** off-diagonals preserved, including `cov(β₁, θ₂)` and
    `cov(β₁, θ₃)`. Tests must NOT hardcode these to 0 for lavaan.

## 6. Standard errors — delta method per component

Each component is linear or bilinear in the coefficients, so the delta method gives
`Var = gᵀ Σ g` over the relevant alias sub-block (`Σ = @vcov[idx, idx]`). Gradients:

| Component | Parameters | Gradient `g` |
|-----------|------------|--------------|
| **CDE** = θ₁ + θ₃m\* | θ₁, θ₃ | `[1, m*]` |
| **INTmed** = θ₃β₁ | θ₃, β₁ | `[β₁, θ₃]` |
| **PIE** = θ₂β₁ | θ₂, β₁ | `[β₁, θ₂]` |
| **INTref** = θ₃(β₀ + β₂ᵀc̄ − m\*) | θ₃, β₀ (, β₂) | `[β₀+β₂ᵀc̄−m*, θ₃, θ₃·c̄]` |

- Critical cross-terms: `Var(INTmed)`/`Var(PIE)` need `cov(θ₃,β₁)` / `cov(θ₂,β₁)` — **0 for lm,
  non-zero for lavaan**. The delta code is identical across engines; only Σ differs (this is why the
  vcov assembly must preserve the right blocks).
- `Var(TE)` and `Var(NDE)`/`Var(NIE)`: build the full gradient of each aggregate over the joint
  `{β₁, θ₁, θ₂, θ₃, β₀}` block — do **not** sum component variances independently (that drops the
  covariances). Reuse the `confint(ParallelMediationData)` full-block pattern.
- `method = "boot"` → `stop()` directing to `bootstrap_mediation()` (already engine-agnostic).
- Provide `confint(InteractionMediationData, parm = c("paths", "components", "effects"))`:
  `"paths"` → a/b/c'/θ₃; `"components"` → CDE/INTref/INTmed/PIE; `"effects"` → NDE/NIE/TE.

## 7. Effect accessors

- `nde()`, `nie()`, `te()` methods already exist as generics — add `InteractionMediationData`
  methods returning the §3 aggregates.
- **Decision (flag at implementation):** expose the four components either as (a) new S7 generics
  `cde()/int_ref()/int_med()/pie()` (mirrors `nie()/nde()` ergonomics) or (b) a single
  `decompose(x)` returning a named vector / tibble of all four + derived effects. Recommend **(b)
  `decompose()`** as the primary API (one tidy table, less surface area) with slot access for power
  users; revisit if downstream packages want the individual generics.
- Extend `tidy()`/`glance()` if present so the components appear in tabular summaries.

## 8. Delivery (suggested PR split, mirroring Ext A)

- **PR B1 — class only:** `InteractionMediationData` + validator + `print` + `nde/nie/te/decompose`
  methods, tested against hand-built objects (incl. the θ₃=0 collapse and the invariant validator).
  No extraction yet. (Analogue of #34.)
- **PR B2a — lm/glm extraction + four-way + delta SEs:** interaction detection, `m_star`,
  `decomposition` arg, `.extract_interaction_mediation_lm()`, `confint()`. Tests vs **regmedint** /
  **med4way** numeric output. (Analogue of #36.)
- **PR B2b — lavaan extraction + vignette + pkgdown:** `.extract_interaction_mediation_lavaan()`
  (joint-cov divergence), a "treatment×mediator interaction" vignette section, `_pkgdown.yml`
  reference entry, NEWS. (Analogue of #37.)

Each PR: feature worktree off `dev`; keep `RoxygenNote: 7.3.3` after `document()` (restore the pin,
verify `git diff dev -- DESCRIPTION` empty — gotcha #3); CI green (8 checks) before merge.

## 9. Acceptance criteria

- [ ] `InteractionMediationData` validator enforces the three invariants (sum, NDE, NIE).
- [ ] `extract_mediation(..., decomposition="auto")` returns `InteractionMediationData` iff an `X:M`
      term is present; the no-interaction path returns an unchanged `MediationData`.
- [ ] θ₃ = 0 reproduces the simple-mediation decomposition (CDE=NDE=θ₁; INTref=INTmed=0; NIE=θ₂β₁).
- [ ] Four-way components match **regmedint**/**med4way** on a shared continuous-Y/M example
      (within numerical tolerance).
- [ ] Delta-method SEs validated against bootstrap; lm vs lavaan SEs differ in the documented
      direction (lavaan keeps `cov(β₁, θ₂)`, `cov(β₁, θ₃)`).
- [ ] `R CMD check --as-cran` clean; vignette + pkgdown reference present.

## 10. Identification (document, don't enforce)

Per VanderWeele (2014), causal reading needs the four no-unmeasured-confounding assumptions
(`medfit-roadmap.md §7.8`). **medfit computes the decomposition; causal interpretation is the
user’s responsibility** — state this in the class docs and the vignette.

## References
- VanderWeele TJ (2014). *A unification of mediation and interaction: a 4-way decomposition.*
  Epidemiology 25(5):749-61. <https://pubmed.ncbi.nlm.nih.gov/25000145/>
- Valeri L, VanderWeele TJ (2013). *Mediation analysis allowing for exposure–mediator
  interactions…* Psychological Methods 18(2):137-150.
- Discacciati A et al. (2019). *Med4way…* Int J Epidemiol 48(1):15-20.
- Validation targets: **regmedint** (CRAN), **med4way** (Stata) — for numeric cross-checks.
- Internal: `SPEC-parallel-extractor-2026-06-03.md` (reuse patterns); `[[s7-medfit-gotchas]]`;
  `[[parallel-mediation-progress]]`.
```
