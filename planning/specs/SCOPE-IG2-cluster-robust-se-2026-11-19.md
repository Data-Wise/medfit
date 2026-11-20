# Scope note: IG2, cluster-robust (sandwich) standard errors for the native two-level fit (S6)

**Date:** 2026-11-19 · **Status:** D1-D6 accepted as recommended (2026-11-19); implemented on `feature/ig2-cluster-sandwich`.
**Gap register:** [PLAN-multilevel-implementation-gaps-2026-11-11.md](../PLAN-multilevel-implementation-gaps-2026-11-11.md) (IG2)
**Plan:** [PLAN-multilevel-remainder-2026-11-18.md](../PLAN-multilevel-remainder-2026-11-18.md) (IG2, "after S4"; S4a merged, #486 to #493)

## 1. What exists today

| Fact | Where |
|---|---|
| The single-level sandwich is HC0-type `A^-1 B A^-1`, with `B = crossprod(scores)` from casewise scores | `R/sem-se.R:22` (`.sem_vcov()`), meat at `R/sem-se.R:46`; roxygen at `R/fit-sem.R:58-64` |
| Casewise scores read row data `smp$x` and the single-level implied moments | `R/sem-sandwich.R:14` (`.sem_scores()`) |
| With active constraints the sandwich is projected: `Z (Z'AZ)^-1 Z'BZ (Z'AZ)^-1 Z'` | `R/sem-se.R:14-15` (comment), same function |
| Two-level sample statistics: per-cluster vectors `c_j` and within scatter `SSW_j` are built, then pooled by cluster size | `R/sem-ml.R:460-481` (`.sem_sample_ml2()`; per cluster :470-474, pooled :475-479) |
| The two-level gradient is formed per size, `G_n = -1/2 (c_n V_n^-1 - V_n^-1 C_n V_n^-1)` with `V_n = Sigma_B + diag(Sigma_W / n, 0)` | `R/sem-ml.R:566-595` (`.sem_ml2_grad_moments()`), `.sem_eval_ml2()` at :602 |
| The two-level fit stores model-based vcov only: `"model"` is hardcoded | `R/sem-fit.R:333` and `:337` (`.sem_fit_twolevel()`) |
| `se_type = "sandwich"` with `cluster` is refused, class `medfit_error_twolevel_weights` (shared with the weights refusal) | `R/fit-sem.R:489-491`; weights at :486-488; test `test-sem-twolevel-guards.R:99` |
| `information = "expected"` is refused for two-level; the bread is the observed information | `R/fit-sem.R:508-510` |
| The fit keeps the cluster ids | `fit@internals$cluster_ids` (set in `.sem_fit_twolevel()`, `R/sem-fit.R:271-345`) |

So per-cluster score vectors do not exist. The pooled statistics answer the likelihood and the gradient, but a cluster meat
needs one score per cluster. This is the whole of the new numerical work.

## 2. Estimand

For cluster `j` with size `n_j`, cluster-mean vector `c_j` and within scatter `SSW_j`, the cluster log-likelihood
contribution `l_j(theta)` is the O8 term already summed by `.sem_loglik_ml2()` (`R/sem-ml.R:497`). Define

- score `s_j = d l_j / d theta` (the per-size gradient formula of `R/sem-ml.R:566-595` evaluated with `c_j c_j'` and
  `SSW_j` of one cluster instead of the size totals, chained through `.sem_ram_chain` per level as in `.sem_eval_ml2()`);
- bread `A` = the observed information already used for the model-based vcov;
- meat `B = sum_j s_j s_j'` (CR0);
- `V = A^-1 B A^-1`, projected exactly as the single-level sandwich when constraints are active.

This is the two-level sandwich of [YuanBentler2002] and the estimator lavaan reports for `se = "robust.huber.white"` on a
two-level fit. It is robust to non-normality within the stated two-level mean and covariance structure; it does not repair a
wrong structure, and with fixed slopes (Q3) it does not model random slopes.

Identity: `sum_j s_j` equals the total gradient, which is about 0 at the optimum. That identity is the cheapest check that
the per-cluster split is right.

## 3. Few clusters

The CR0 meat is biased downward when the number of clusters `J` is small [Cameron2008; Cameron2015; Imbens2016;
MacKinnon2023]. Available adjustments: the `J / (J - 1)` scale (CR1-type), the bias-reduced CR2-type estimator with
Satterthwaite-type degrees of freedom [Pustejovsky2018], and `t` references with `J - 1` df. These results are for linear
and generalized linear models. Their transfer to ML SEM and to products of paths is labeled **SPECULATIVE** in the
literature file (I4, `LIT-multilevel-sem-gaps-2026-11-11.md`); [Falk2018] is the SEM-side evidence. medfit must not
present an adjustment as calibrated for products until T6 says so.

## 4. Dependencies

- **S4a** (merged): the native two-level likelihood, gradient, joint vcov and admissibility check.
- **T6/U4** (`PLAN-few-clusters-design-study-2026-11-16.md`, T6 at :181, T8 builds U4): the few-cluster study decides whether
  any small-`J` correction ships and what reference distribution the Wald intervals use. IG2's CR0 core can be built
  before T6 ends; the choice of adjustment (D3, D4) waits for it.
- IG3's Wald variants depend on IG2 (`SCOPE-IG3-twolevel-tests-2026-11-19.md`).

## 5. Oracles

| Oracle | Comparison | Tolerance |
|---|---|---|
| lavaan `se = "robust.huber.white"`, `fixed.x = FALSE`, same `information = "observed"` on a two-level fit (fixture pattern: `helper-twolevel.R:85`, `test-twolevel-extract.R:224`) | every SE | TL-2 (1e-3 relative), TL-3 convention |
| Hand-built cluster sandwich from the O8 likelihood (`helper-twolevel-likelihood.R`): per-cluster log-likelihood differentiated numerically, `A` from the hand Hessian | full `V` | 1e-6 relative (both sides use the same likelihood) |
| Nonparametric cluster bootstrap of `fit_sem(cluster = )`: a hand loop that resamples clusters and refits (`twolevel_statistic()` refits lavaan only, `R/twolevel-statistic.R:205-238`) | SD of estimates vs sandwich SE | sanity only (TL-7 sets that the bootstrap is a sanity check, not a tolerance) |
| OpenMx (TL-5), if U3 covers robust SEs | SEs | TL-2 |

Fixtures: `tl_data_balanced()` and `tl_data_unbalanced()` (`helper-twolevel-likelihood.R:174-175`); the unbalanced one is
required, since pooling by size hides nothing when all sizes are equal.

## 6. Planted defects

Each must fail the oracle it is listed against (TL-7 rule).

| Defect | Caught by |
|---|---|
| Meat from per-size pooled scores instead of per-cluster scores | lavaan robust SEs and the hand sandwich (unbalanced fixture) |
| Casewise (level-1 row) scores as in `.sem_scores()` | lavaan robust SEs |
| A dropped cross-level block of the meat | hand sandwich; SE of `a_w - a_b` (TL-7 defect pattern) |
| Scores that do not sum to the gradient (one cluster dropped or counted twice) | the sum identity in section 2 |
| Bread from the expected instead of the observed information | lavaan robust SEs at TL-2 |
| Projection skipped when an equality constraint is active | hand sandwich on a constrained fit (`a_w == a_b`) |

Metamorphic checks (PLAN-multilevel-mediation section 7): relabeling clusters and reordering rows leave `V` unchanged to
1e-10; duplicating every cluster halves `V` to TL-2.

## 7. Admission checklist (seven items)

IG2 edits risk files (`R/fit-sem.R`, `R/sem-fit.R`, possibly `R/sem-ml.R`; `tests/sim/risk-files.txt`). The PR body
carries the seven items: independent oracle (section 5), reliability cell (a `tests/sim` gate on the unbalanced fixture),
planted defect (section 6), metamorphic invariance (section 6), fault injection (a cluster with one row; `J = 2`),
registration (`gates.csv` row with `oracle` and `mutants`, `tests/sim/structures.csv` row), platform run on the OpenBLAS
runner.

## 8. API sketch

```r
fit_sem(model, data, cluster = "school", se_type = "sandwich")
```

- `se_type = "sandwich"` with `cluster` gives the cluster-level sandwich (D1). The refusal at `R/fit-sem.R:489-491` is
  lifted for this case only.
- Still refused, each with its own class: `weights` (sampling weights at two levels need a separate estimand),
  products (already refused, `R/fit-sem.R:484`), nonlinear constraints (already refused, :496-498), `information =
  "expected"` (:508-510).
- Linear constraints are accepted with the projected sandwich (D4).
- `glance()` and `print()` name the SE type and the number of clusters; the existing few-clusters warning stays.

## 9. Out of scope

Sampling weights at either level; random slopes; corrections beyond CR0 until T6 reports; the lavaan adapter's SEs
(lavaan already reports robust SEs there); CR-type corrections for `twolevel_statistic()`; cluster-robust tests (IG3).

## 10. Open decisions

D1-D6 accepted as recommended (2026-11-19).

**D1. Argument value.** Reuse `se_type = "sandwich"` (cluster level automatically when `cluster` is given) or add
`se_type = "cluster"`? **Recommended: reuse `"sandwich"`.** It matches lavaan, where the robust estimator follows the
model's levels, and adds no value that means something only in one route.

**D2. Where per-cluster statistics come from.** (a) keep `c_j` and `SSW_j` per cluster in `.sem_sample_ml2()` (risk file
`R/sem-ml.R`), or (b) recompute them after the fit from the data and `internals$cluster_ids` in a new file.
**Recommended: (b).** It leaves the likelihood path untouched, so the S4a gates cannot move, and the sum identity in
section 2 ties the two computations together.

**D3. Small-`J` correction.** CR0, CR1-type `J / (J - 1)`, or CR2-type [Pustejovsky2018]? **Recommended: CR0 by default,
matching lavaan**, with a `J / (J - 1)` option added only if T6 shows it helps for these models.

**D4. Constraints.** Allow linear constraints with the projected sandwich? **Recommended: yes**; the projection exists and
the hand sandwich oracle covers it.

**D5. Reference distribution for Wald intervals.** Normal or `t` with `J - 1` df? **Recommended: normal now**, with the
few-clusters warning, and revisit after T6.

**D6. Refusal class.** The current `medfit_error_twolevel_weights` covers both weights and the sandwich. **Recommended:**
keep it for weights only once the sandwich ships; no new class is needed for the sandwich because it is no longer refused.
