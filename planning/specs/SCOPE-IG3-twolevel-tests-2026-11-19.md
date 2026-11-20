# Scope note: IG3, optional tests for the native two-level fit

**Date:** 2026-11-19 · **Status:** scope note only; no code. Open decisions D1-D6 await the maintainer.
**Gap register:** [PLAN-multilevel-implementation-gaps-2026-11-11.md](../PLAN-multilevel-implementation-gaps-2026-11-11.md) (IG3)
**Plan:** [PLAN-multilevel-remainder-2026-11-18.md](../PLAN-multilevel-remainder-2026-11-18.md) (IG3, "after S4; boundary law")

## 1. Two tests, kept apart from the contrast

| Test | Null | Shape of the null |
|---|---|---|
| T-A: product null per level | `a_w b_w = 0` (within) and, separately, `a_b b_b = 0` (between) | union of two lines (`a = 0` or `b = 0`); singular at the origin |
| T-B: equal indirect effects | `a_w b_w = a_b b_b` | one smooth nonlinear surface, singular only where all four paths are 0 |

The descriptive contrast `a_w b_w - a_b b_b` from `nie(level = "contrast")` stays descriptive (Q4). These tests are
separate, opt-in functions; `nie()` and `tidy()` never report a p-value for the contrast.

## 2. What exists today

| Fact | Where |
|---|---|
| Linear constraints are accepted by the native two-level fitter (`.sem_constraint_rows()` on the two-level table) | `R/sem-fit.R:271-345` (`.sem_fit_twolevel()`) |
| Every nonlinear constraint is refused with `medfit_error_twolevel_nonlinear`, including `a_w*b_w == 0` | `R/fit-sem.R:496-498`; test `test-sem-twolevel-guards.R:102-107` |
| The zero-product branch split `.sem_fit_branches()` is single-level only | `R/sem-fit.R:430` |
| `mbco_sem()` refits each path at 0 as a linear model and keeps the minimum LR; it calls `.sem_fit_syntax()` without `cluster` | `R/sem-mbco.R:119`, refit loop :198-213 (`cluster` absent at :208-211) |
| That refit therefore hits the single-level guard, which raises the S4a "not implemented" message | `R/sem-fit.R:63-68` (`.sem_single_level_only()`), called at :88 and :112 |
| `compare_lr()` runs `mbco_sem()` first, so it fails the same way | `R/compare-lr.R:186` |
| `mbco_sem()` documents its reference as a mixture of chi-squares and the chi-square(1) test as conservative | `R/sem-mbco.R:84-97` |
| `compare_lr()`'s known limit (#320): on `a*b == 0` an engine can stop on the line with the larger minimum | `R/compare-lr.R:315-333` |
| `fit@data` has no cluster column; `fit@internals$cluster_ids` carries it | probe below |

Probe (2026-11-19, `tl_data_balanced()`, two-level model of `helper-twolevel-likelihood.R:181` fitted with `fit_sem(cluster = )`):

- `mbco_sem(f, a = "a_w", b = "b_w")` and `compare_lr(f, paths = c("a_w", "b_w"))` both error: "the refit with `a_w == 0`
  failed (native two-level estimation is not implemented yet (S4a, experimental); ...)". The message is stale now that
  S4a is merged; the cause is the dropped `cluster`. **Finding, not fixed here:** until IG3 routes the refit, `mbco_sem()`
  should refuse a two-level fit with its own class.
- `anova()` on two nested native two-level fits (free vs `a_w == a_b`) works: chi-square difference 1.576 on 1 df,
  p = .209. The absolute "Chisq" column is `-2 logL` (2122.8 with 0 df for the full model), not a model-fit statistic,
  but the difference is a valid LR.

## 3. Hosting in the native fit

- **T-A needs no nonlinear rows.** The product null is the union of `a_w == 0` and `b_w == 0`; each branch is a linear
  constraint, which the two-level fitter already accepts. The LR is the minimum over the two branch refits, which is what
  `mbco_sem()` computes for single-level fits. The work is routing: pass `cluster` (from `internals$cluster`) and the data
  with the cluster column into the refit. No risk-file change in the likelihood is needed; `R/sem-mbco.R` is not on
  `tests/sim/risk-files.txt`, but `R/sem-fit.R` is if the routing goes through it.
- **T-B needs a nonlinear row.** `a_w*b_w == a_b*b_b` requires lifting the refusal at `R/fit-sem.R:496-498` for this one
  row shape and validating the nonlinear gate (SLSQP with `cons$nl`, Lagrangian Hessian, polish) on the two-level
  objective. That is a risk-file change (`R/fit-sem.R`, `R/sem-fit.R`, `R/sem-constraints.R`, `R/sem-optim.R`).

## 4. Reference law

- **T-A.** Under the null, the LR from the minimum over branches is bounded by chi-square(1); at the origin (`a = b = 0`)
  the law is not chi-square(1) and the chi-square(1) test is conservative, as `?mbco_sem` states. When a level-2 variance is
  near zero, the null also sits near a variance boundary, where mixture laws apply [SelfLiang1987; StramLee1994; Stoel2006;
  Andrews2001; SavaleiKolenikov2008]. The literature register lists "boundary plus product plus level-specific" as open
  (G3, `LIT-multilevel-sem-gaps-2026-11-11.md:334`); no closed-form law is claimed.
- **T-B.** Away from the all-zero point the null is a regular surface and the LR is asymptotically chi-square(1). Near
  it the same singularity as T-A returns. The between-level paths rest on `J` clusters, so the asymptotics are in `J`;
  T6 decides the small-`J` story.
- **#320.** The T-A branch minimum is exactly the setting of the #320 limit: an external engine fitting `a*b == 0`
  directly can settle on the wrong line. medfit's branch refits avoid it by construction; the oracle must therefore fit
  both lines separately, not the product constraint.

## 5. Dependencies

- S4a (merged).
- IG2 for any Wald variant (`SCOPE-IG2-cluster-robust-se-2026-11-19.md`).
- T6/U4 (`PLAN-few-clusters-design-study-2026-11-16.md`): calibration at small `J`.
- The nonlinear-gate work (T-B only).

## 6. Oracles

| Oracle | Use | Tolerance |
|---|---|---|
| lavaan two-level LR with linear constraints: fit `a_w == 0` and `b_w == 0` separately, take the minimum | T-A statistic | TL-4 difference rule (1e-6 absolute on the log-likelihood difference) |
| lavaan two-level with the nonlinear constraint `a_w*b_w == a_b*b_b` (LIT I2 marks support as unverified; probe it first) | T-B statistic | TL-4 |
| Hand O8 likelihood (`helper-twolevel-likelihood.R`) maximized under each branch | T-A and T-B statistics | TL-4 |
| Parametric bootstrap of the LR from the constrained fit | null distribution, size at small `J` | sanity and calibration, not a tolerance |
| Single-level `mbco_sem()` on a fit whose between part is degenerate | T-A within-level statistic should match the single-level value on the same within data structure | design-dependent; sanity |

## 7. Planted defects

| Defect | Caught by |
|---|---|
| Refit drops `cluster` (today's behavior) | the classed refusal test now; the lavaan oracle later |
| Wrong level label (`a_b` tested when `a_w` was asked) | lavaan branch refits |
| Maximum instead of minimum over branches | lavaan branch minimum |
| Product constraint fitted directly instead of two branches | a fixture where the lines have different minima (#320 pattern) |
| Contrast reported as a test through `nie(level = "contrast")` | docs-consistency test: no p-value column on the contrast |
| T-B with the sign of one product flipped | lavaan T-B statistic |

## 8. Admission checklist

T-A routing touches `R/sem-mbco.R` and possibly `R/sem-fit.R`; T-B touches the constraint and optimizer risk files. Both
carry the seven items: oracle (section 6), reliability cell (size at `J = 20, 50`), planted defect (section 7), metamorphic
invariance (cluster relabel, row reorder, swapping the roles of the two branches), fault injection (a branch refit that
fails to converge must make the result unresolved, not a number), registration (`gates.csv`, `structures.csv`),
OpenBLAS platform run.

## 9. API sketch

```r
mbco_sem(fit, a = "a_w", b = "b_w")          # T-A, within (fit has cluster)
mbco_sem(fit, a = "a_b", b = "b_b")          # T-A, between
twolevel_equal_indirect(fit)                 # T-B, LR; name open (D3)
```

Refused: products, weights, `fiml`, and any fit the two-level guard already refuses. Output carries the level and the
number of clusters, and the boundary warning machinery of `R/sem-mbco.R:321` and :354 applies to level-2 variances.

## 10. Out of scope

A test built on the descriptive contrast; random-slope indirect effects; three-level and multigroup models; two-level
`compare_lr()`; the lavaan adapter's tests (users can fit constrained lavaan models directly).

## 11. Open decisions

**D1. Host for T-A.** Extend `mbco_sem()` to two-level fits, or a new function? **Recommended: extend `mbco_sem()`.** The
statistic and its reference are the same; only the refit routing differs. Until then, a classed refusal replaces the
stale message.

**D2. T-B statistic.** LR with the nonlinear row, Wald with IG2 SEs, or parametric bootstrap only? **Recommended: LR,
calibrated by a parametric bootstrap at small `J`.** A Wald test of `a_w b_w - a_b b_b = 0` is the descriptive contrast
over its SE, which Q4 keeps out of inference, and the delta-method SE is poor near zero products. No Wald test of the
product null either: that null is singular.

**D3. T-B entry point.** A separate exported function, not an option of `nie()`. **Recommended: a separate function**, so
the contrast in `nie(level = "contrast")` is never shown next to a p-value.

**D4. Reference law for T-A.** chi-square(1) with the conservativeness note, or a bootstrap? **Recommended:
chi-square(1)**, as single-level `mbco_sem()`, plus the boundary warning for level-2 variances; a bootstrap option after T6.

**D5. Order.** **Recommended: T-A first** (no risk-file change in the likelihood or optimizer), T-B after the nonlinear gate
is validated on the two-level objective.

**D6. Two-level `compare_lr()`.** **Recommended: defer**; the lavaan branch-refit oracle covers T-A in tests.
