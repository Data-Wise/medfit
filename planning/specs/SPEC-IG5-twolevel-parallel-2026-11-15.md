# Spec: IG5, parallel mediators in the two-level (1-1-1) lavaan adapter

**Date:** 2026-11-15 · **Status:** **approved** 2026-11-15 (D1-D5 as recommended)
**Gap register:** [PLAN-multilevel-implementation-gaps-2026-11-11.md](../PLAN-multilevel-implementation-gaps-2026-11-11.md) (IG5)
**Scope decision (user, 2026-11-15):** parallel mediators only. Serial chains are out of scope.
**Plan:** [PLAN-IG5-twolevel-parallel-2026-11-15.md](../PLAN-IG5-twolevel-parallel-2026-11-15.md)

## 1. Problem

`extract_mediation()` on a two-level lavaan fit accepts exactly one mediator. A model with two or more mediators
that each carry X to Y at both levels is refused with `medfit_error_twolevel_unsupported` ("A two-level fit supports
exactly one mediator"). IG5 is the only open multilevel gap with no technical blocker: it needs no native two-level
fitter (S4), no random slopes (Q3) and no latent mediators (S5).

## 2. Model

At level `l` (within `w`, between `b`), for mediators `M_1, ..., M_k`, `k >= 2`:

- `M_j ~ a_j^l X` for each j
- `Y ~ c'^l X + sum_j b_j^l M_j`

Per level:

- specific indirect effect `a_j^l b_j^l`
- total NIE `sum_j a_j^l b_j^l`
- NDE `c'^l`; TE = NIE + NDE; PM = NIE / TE
- contrast (between minus within) of each specific effect and of the total, descriptive and not a test, as in the
  one-mediator class

Mediator residual covariances (`M_1 ~~ M_2`) at either level are allowed. They do not enter any effect, but the
parameter covariance carries them through the joint information.

## 3. Decisions

Each decision was approved by the user on 2026-11-15 as recommended.

| # | Question | Recommendation | Alternative |
|---|---|---|---|
| D1 | Class shape | **New class `TwoLevelParallelMediationData`**, separate from `TwoLevelMediationData`. Properties `a_within`, `b_within`, `a_between`, `b_between` are named vectors of length k; `c_prime_within`, `c_prime_between` scalars; `mediators` (character, length k) replaces `mediator`; every other property is unchanged. This follows the one-class-per-structure rule (`MediationData` / `ParallelMediationData`) and leaves the 35 property names pinned in `test-dependents-contract.R` untouched. | Make `TwoLevelMediationData`'s paths vectors. The experimental label allows it (DECISIONS-0.17.0 #2), but it changes a pinned contract and every scalar consumer. |
| D2 | Between identification with k mediators | **All or nothing.** The object is within-only (between properties `NA`, `medfit_between_unidentified`) when the ICC of the treatment or of *any* mediator is below 0.01. Same rule as today, applied to each mediator. | Per-mediator partial between paths. More states, and the total between NIE would still be undefined. |
| D3 | Mediator residual covariance | **Accept silently.** Free or fixed, `M_j ~~ M_j'` changes the fit, not the extraction. The `@vcov` sub-block is read from lavaan's joint covariance, so Cov(a_j, a_j') is carried whatever the model says. The page states that, unlike the lm/glm `ParallelMediationData` `@vcov`, this one carries Cov(a_j, a_j'). | Warn when the covariance is absent (a modeling opinion the extractor does not otherwise hold). |
| D4 | `twolevel_statistic()` with k mediators | **Extend it in this slice.** Bootstrap is the documented inference route for two-level fits (cookbook recipe 23), so a class that can only be bootstrapped by hand is half done. Effects `"nie"` (total), `"nie_j"` (specific, by mediator name), `"nde"`, `"te"`, each with `level =`. | Refuse with `medfit_error_twolevel_unsupported` and ship bootstrap later. |
| D5 | Contrast availability (#415) | **Per specific effect:** the contrast of `a_j b_j` is `NA` only when both `a_j` and `b_j` are equated across levels (`.twolevel_pair_equal()` per mediator). The total contrast is `NA` only when every specific contrast is `NA`. `@cross_level_equal` lists equated paths by their `a_j_*` / `b_j_*` names. | One flag for the whole object. |

## 4. API

- `extract_mediation(fit, treatment = "X", mediator = c("M1", "M2"), outcome = "Y")` on a two-level lavaan fit
  returns `TwoLevelParallelMediationData`. A length-one `mediator` still returns `TwoLevelMediationData`.
- `nie(x, level = , type = c("total", "specific"))`: total by default. `specific` returns a named vector.
- `nde()`, `te()`, `pm()`: `level =` as in the one-mediator class.
- `paths()`: `a_<M>_within`, `b_<M>_within`, ..., `c_prime_within`, and the between set.
- `decompose()`: per level, each specific effect, the total and the contrast.
- `tidy()`, `confint()`, `summary()`, `print()`: rows for each specific effect, the total, NDE, TE, PM, per level,
  with delta-method SEs from one gradient builder in `R/effect-se.R`.
- Labeled experimental, like the rest of the two-level API.

Refused, with the existing classes: `standardized = TRUE`, products, three-level, multigroup, a mediator that
predicts another mediator at either level (serial; `medfit_error_twolevel_unsupported`, new message naming the
`M_j ~ M_j'` row).

## 5. Internals

- `.twolevel_key_rows()` gains a vector `mediator`. Row order per level: `a_<M_1>`, ..., `a_<M_k>`, `b_<M_1>`, ...,
  `b_<M_k>`, `c_prime`; within then between. The key stays the free-parameter index.
- `.twolevel_subvcov()` is unchanged: it already works for any key length. The block is `2(2k + 1)` square and
  carries the cross-level and the cross-mediator covariances.
- `.twolevel_check_args()` accepts `length(mediator) >= 1`; a duplicate or the treatment/outcome among the
  mediators errors.
- `.twolevel_identification()` loops the ICC check over the mediators (D2).
- Gradients: `d(sum a_j b_j)/d a_j = b_j`, `d/d b_j = a_j`, per level; the contrast gradient is the between minus the
  within gradient.

## 6. Verification

| Claim | Oracle | Planted defect |
|---|---|---|
| Paths and `@vcov` | lavaan `parameterEstimates()` and `vcov()` on the same fit, by free index | swap two mediators' `b` rows in the key |
| Total and specific NIE, SEs, per level | lavaan `:=` defined parameters (`a1w*b1w + a2w*b2w`, between, contrast) with lavaan's delta SEs | zero the cross-mediator block of `@vcov`; the total-NIE SE test must fail |
| Contrast `NA` rule | equality by label, by `==` row, and numeric; one mediator equated, both equated | flag the contrast `NA` when only `a_j` is equated |
| Within-only rule | fixture with one low-ICC mediator | check only the first mediator's ICC |
| Bootstrap callback | parametric and cluster-refit statistics equal `nie()` at the estimate | return the within value for `level = "between"` |

Metamorphic checks: with k = 1 the new code reproduces `TwoLevelMediationData` exactly (paths, effects, SEs);
permuting the mediator order leaves totals unchanged and permutes the specific effects; renaming a mediator changes
names only.

Risk tier: not high-risk. No file in `tests/sim/risk-files.txt` changes (the adapter reads a lavaan fit; it does not
optimize).

## 7. Files

- `R/classes-twolevel.R` (new class, print, summary), `R/extract-lavaan-twolevel.R`, `R/twolevel-statistic.R`,
  `R/generics-effects.R`, `R/effect-se.R`, `R/methods-tidy.R`, `R/zzz.R` (S4 registration)
- Tests: new `test-twolevel-parallel-*.R`, `helper-twolevel.R` (a two-mediator fixture),
  `test-twolevel-docs.R` (the one-mediator refusal at line 146 is replaced by the serial refusal),
  `test-dependents-contract.R` (pin the new class's properties), `test-refcard-coverage.R`
- Docs: `vignettes/articles/model-twolevel.qmd`, `guide-troubleshooting.qmd` (row at line 96), cookbook recipe 23
  or a new recipe, the reference card, `_pkgdown.yml`, NEWS, `CLAUDE.md` class list,
  `PLAN-multilevel-implementation-gaps-2026-11-11.md` (IG5 status)

## 8. Out of scope

Serial chains; mediators measured at one level only; random slopes (IG4); native two-level fitting (IG1);
cluster-robust SEs (IG2); tests of the product null per level (IG3).
