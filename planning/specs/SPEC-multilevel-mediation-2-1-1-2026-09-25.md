# Spec: multilevel mediation, module 1 — cluster-level treatment (2-1-1)

**Date:** 2026-09-25 · **Status:** draft, awaiting approval
**Grill:** [GRILL-multilevel-mediation-ext-d-2026-09-25.md](GRILL-multilevel-mediation-ext-d-2026-09-25.md) (D1–D9)
**Background:** [REVIEW-multilevel-mediation-2026-09-25.md](REVIEW-multilevel-mediation-2026-09-25.md)
(sections 1, 3, 5, 6; read depth for every source is in its section 9)
**Origin:** Ext D in [BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md](BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md)

**Approval items.** The grill left these to the spec; each is proposed here and needs a yes:

| # | Item | Proposal |
|---|---|---|
| A1 | Class name | `ClusterMediationData` (treatment varies at the cluster level). Module 2's 1-1-1 class is named in its own grill. |
| A2 | Few-cluster warning (D5) | Warn when J < 25 with `se_type = "model"`; warn at J < 10 whatever the SE type |
| A3 | Small-cluster warning (D8) | `decompose()` warns when the harmonic mean cluster size is below 20, and prints the size of the gap |
| A4 | `se_type = "kr"` scope | Replaces the fixed-effect vcov only; every interval stays normal-based |
| A5 | Model rows | Both models must use identical rows; cluster means are checked against those rows |

## Goals

1. A user with clustered data, where treatment is assigned to whole clusters (for example a
   cluster-randomized trial), gets the natural indirect, natural direct and total effects of
   that treatment from two linear mixed models, with standard errors. The estimand is stated,
   and so are the assumptions behind each number.
2. The same object comes from both routes: `fit_mediation(engine = "lmer", cluster = )` builds
   the models, and `extract_mediation()` reads the user's own `lmer` fits (D3).
3. The indirect effect splits into an own-mediator part and a spillover part through
   cluster-mates' mediators (D2), labeled as a large-cluster, cluster-average split (D8).
4. Inference matches the other classes: delta-method SEs in `tidy()`/`confint()`/`summary()`
   (D4), opt-in Kenward-Roger vcov (D5), and a cluster bootstrap (D4).
5. Every numeric claim passes an independent oracle, and a planted defect fails it.

## Non-goals (module 1)

Each of these gets an error naming the problem (see Behavior) or a line in the docs:

- **1-1-1 designs** (treatment varies within clusters) and σ_ab. These are module 2 (D1).
- **`glmer` or other non-Gaussian families.** `a·b_B` on the link scale is not the NIE (D7).
- **Treatment × mediator products**, including cross-level ones (D7).
- **Latent cluster means.** The estimand uses the observed cluster mean (see Estimand). The
  latent-covariate approach of Lüdtke et al. (2008) is a different model, not an option here.
- **Individual-average effects** and the exact finite-cluster own/spillover split (D8, module 2).
- **`weights` and `se_type = "sandwich"` with `lmer`.** lme4 weights are precision weights,
  not the IPW weights of the glm engine.
- **Three-level or cross-classified models** (more than one grouping factor).
- **Multilevel lavaan** (`cluster =` in `lavaan::sem()`).

## Capability map

Module 1 has three independently testable slices. Module 2 depends on this module's class
conventions but not on its code.

| Module id | Responsibility | Depends on | This spec |
|---|---|---|---|
| `ml211-extract` | `ClusterMediationData`, `extract_mediation()` for `lmerMod`, gradients, effect generics, print with the assumptions block | — | **yes** |
| `ml211-fit` | `fit_mediation(engine = "lmer", cluster = )`, `se_type = "kr"`, few-cluster warnings | `ml211-extract` | **yes** |
| `ml211-boot` | Cluster resampling in `bootstrap_mediation()` | `ml211-extract` | **yes** |
| `ml111` | 1-1-1 designs, σ_ab, cluster weighting | module 1 conventions | no (own grill) |

Build order: `ml211-extract` → `ml211-fit` and `ml211-boot` in either order.

## Estimand and formulas

**Design.** Clusters j = 1…J of size n_j. Treatment X_j is constant within a cluster. The
mediator M_ij and outcome Y_ij are measured on individuals. M̄_j is the **observed** mean of the
mediator over the cluster members in the analysis rows.

**Models (Talloen et al. 2016, eqs. 5–6, p. 367, read in full).** With covariates C_ij and
cluster random intercepts:

- Mediator: `M_ij = β0 + a·X_j + β2'C_ij + v_j + r_ij`
- Outcome, within parameterization: `Y_ij = θ0 + c′·X_j + b_W·(M_ij − M̄_j) + b_B·M̄_j + θ4'C_ij + u_j + e_ij`
- Outcome, raw parameterization: `Y_ij = θ0 + c′·X_j + b_W·M_ij + κ·M̄_j + θ4'C_ij + u_j + e_ij`,
  with contextual effect κ and `b_B = b_W + κ` (medfit-side identity, test R1)

Talloen et al. write the outcome with the raw M and the class mean, and replace the mean of
the classmates other than i by the class mean, noting the two are close in groups of 20 or more.

**Effects.**

| Effect | Formula | Accessor |
|---|---|---|
| NIE | `a·b_B` | `nie()` |
| NDE | `c′` | `nde()` |
| TE | `a·b_B + c′` | `te()` |
| PM | `a·b_B / (a·b_B + c′)` | `pm()` |
| Own-mediator (within) indirect | `a·b_W` | `decompose()` |
| Spillover (contextual) indirect | `a·(b_B − b_W)` | `decompose()` |

The within/contextual terms and their product forms follow Talloen et al. (2016, pp. 365,
369). VanderWeele (2010) defines the NDE and NIE of a cluster-level treatment and shows that,
in linear random-intercept models without X×M, they reduce to coefficient products. Cheng &
Li (2026) name the parts the individual and spillover mediation effects and define the
cluster-average and individual-average versions.

**Why the NIE needs no weighting (D8).** Changing X_j shifts every member's mediator by a. The
deviations M_ij − M̄_j do not change, M̄_j moves by a, and Y moves by a·b_B in every cluster.
This holds with random slopes on level-1 terms, because X cannot carry a random slope (it is
constant within clusters) and M̄_j has none. So the cluster-average and individual-average NIE
coincide in module 1.

**Medfit-side derivations.** These are not taken from a paper. Each has a test that can fail.

- **D-own. Exact own effect under the fitted model.** Shift only individual i's mediator by a.
  M̄_j moves by a/n_j and the deviation by a(1 − 1/n_j), so the own effect is
  `a·b_W + a·(b_B − b_W)/n_j`. Averaged with equal cluster weights, the gap from `a·b_W` is
  `a·(b_B − b_W)·mean(1/n_j) = a·(b_B − b_W)/H`, where H is the harmonic mean cluster size.
  This gives the D8 warning its number. Tests O3 and O4.
- **R1. Raw to within.** `b_B = b_W + κ`, with the linear vcov transform `J V J'`. Test R1.
- **D4. Block-diagonal vcov.** `Cov(â, b̂_B) = Cov(â, ĉ′) = 0` is an assumption: the models are
  fit separately. The only evidence is one simulated dataset, where the cluster-bootstrap
  correlation was −0.06. The coverage study (test group 5) must hold with unbalanced clusters and
  random within-slopes before the assumption stands.

**Identification assumptions (printed per D9).**

| Quantity | Needs (beyond linearity, no X×M, no unmeasured X–M or X–Y confounding) | Source |
|---|---|---|
| Own `a·b_W` | no unmeasured lower-level M–Y confounding; unmeasured upper-level confounders allowed if additive | Talloen et al. 2016, abstract and p. 367 (M1) |
| Spillover, and so the NIE | also no unmeasured upper-level M–Y confounding | Talloen et al. 2016, abstract |
| The own/spillover split itself | a cross-world assumption across individuals in a cluster | Talloen et al. 2016, eq. 4; VanderWeele et al. 2013 |
| All | interference only through the cluster mean of the mediator; none between clusters | Talloen et al. 2016; VanderWeele 2010 |

## Behavior

**Extraction (`ml211-extract`).** `extract_mediation(model_m, model_y = , treatment = ,
mediator = , cluster = NULL, se_type = c("model", "kr"))`, where `model_m` is an `lmerMod`:

1. Both models are `lmerMod`, or inherit from it, as `lmerModLmerTest` does. A `glmerMod`
   errors (D7).
2. `cluster` defaults to the single grouping factor shared by both models. With more than one
   factor, or factors that differ, it errors and asks for `cluster =`.
3. Each model has a `(1 | cluster)` intercept, or it errors with the corrected formula (D7).
4. X is constant within every cluster, or it errors: "treatment varies within clusters; 1-1-1
   designs are not supported yet".
5. Both models use identical rows, or it errors (A5).
6. **Term detection is by values, not names.** In the outcome model's fixed-effect design:
   - the cluster-mean term is the column that is constant within clusters and equal to M̄_j on
     the model rows (to 1e-8);
   - the within term equals M − M̄_j;
   - the raw term equals M.
   The within + mean pair and the raw + mean pair are accepted (D3). If the mean term is missing,
   it errors with the corrected formula. If a column matches the full-data mean but not the
   model-row mean, it errors: "compute the cluster mean on the rows the models use (complete cases)".
7. Any product of X with a mediator term errors, naming the term (D7). Random slopes on
   level-1 terms are accepted. A random slope on X errors: it is not identified.
8. `@vcov` is block-diagonal over the alias rows `a`, `c_prime`, `b_within`, `b_between`, plus
   the full fixed effects of each model. `se_type = "kr"` uses `pbkrtest::vcovAdj()` per model
   (A4).
9. The warnings from A2 fire here, and again from `fit_mediation()`.

**Fit engine (`ml211-fit`).** `fit_mediation(formula_y = Y ~ X + M + C, formula_m = M ~ X + C,
data, treatment, mediator, engine = "lmer", cluster = "school", se_type = "model",
engine_args = list())`:

- The engine drops incomplete rows once, computes `<M>_cm` and `<M>_cwc` on the remaining rows,
  rewrites the outcome formula to the within parameterization, adds `(1 | cluster)` to both
  models, and fits with `REML = TRUE` (D5).
- `engine_args` accepts `random_m` and `random_y` (one-sided formulas for extra level-1 random
  slopes) and `REML`. Anything else errors.
- `weights` and `se_type = "sandwich"` error with `engine = "lmer"`.
- lme4 is not installed: an error naming the package. `se_type = "kr"` without pbkrtest: the same.

**Effects and methods.**

- `nie()`, `nde()`, `te()`, `pm()` and `paths()` follow the table above.
- `decompose()` returns own, spillover and NIE, labeled "cluster-average, large-cluster
  approximation". It warns under A3, stating `|a·(b_B − b_W)|/H`.
- `tidy()`, `confint()` and `summary()` use `.effect_gradients()`: NIE `(a: b_B, b_between: a)`,
  own `(a: b_W, b_within: a)`, spillover `(a: b_B − b_W, b_between: a, b_within: −a)`.
  Intervals are normal-based (A4).
- `print()` and `summary()` end with the "Estimand and assumptions" block: the design, the
  number of clusters and the cluster-size range, and one line per quantity from the
  assumptions table (D9). `tidy()` and `glance()` stay plain tibbles. `glance()` gains
  `n_clusters`.

**Cluster bootstrap (`ml211-boot`).** `bootstrap_mediation(method = "nonparametric",
cluster = "school", ...)`:

- Draws J cluster ids with replacement and gives each draw a fresh id before `statistic_fn`
  sees the data. Otherwise a cluster drawn twice would be refit as one bigger cluster. Field &
  Welsh (2007; abstract read) is cited for resampling whole clusters only.
- Counts the resamples that failed to refit. It warns when any failed and stores the count on
  `BootstrapResult`, instead of silently dropping `NA`s.
- `cluster = NULL` keeps today's row bootstrap unchanged.

## Class sketch

```r
ClusterMediationData <- S7::new_class(
  "ClusterMediationData",
  properties = list(
    a_path = S7::class_numeric, b_within = S7::class_numeric,
    b_between = S7::class_numeric, c_prime = S7::class_numeric,
    estimates = S7::class_numeric, vcov = S7::class_any,
    treatment = S7::class_character, mediator = S7::class_character,
    outcome = S7::class_character, cluster = S7::class_character,
    n = S7::class_integer, n_clusters = S7::class_integer,
    cluster_sizes = S7::class_integer,          # one entry per cluster
    parameterization = S7::class_character,     # "within" or "raw" (as fitted)
    se_type = S7::class_character,              # "model" or "kr"
    reml = S7::class_logical, converged = S7::class_logical,
    sigma_m = S7::class_numeric, sigma_y = S7::class_numeric,  # residual SDs
    tau_m = S7::class_numeric, tau_y = S7::class_numeric,      # intercept SDs
    data = S7::class_any
  ),
  validator = function(self) {
    # scalars are length 1; n_clusters == length(cluster_sizes); sum(cluster_sizes) == n;
    # alias rows a, c_prime, b_within, b_between present in estimates and vcov and equal
    # to the path properties; parameterization and se_type in their sets
  }
)
```

Validator rules follow the existing classes. The `class_numeric | NULL` pitfall in the S7
gotchas memory applies to any optional property.

## Commands

```r
devtools::load_all(); devtools::document()
testthat::test_file("tests/testthat/test-cluster-211.R")
devtools::test()                              # report failed + error counts
Rscript tests/sim/coverage-2-1-1.R            # coverage study (not run by testthat)
# lint the way CI does
R CMD INSTALL --library=<scratch> . && R_LIBS=<scratch> Rscript -e 'lintr::lint_package()'
spelling::spell_check_package(); urlchecker::url_check()
devtools::check(cran = TRUE, args = c("--run-donttest", "--no-manual"), document = FALSE,
  env_vars = c(`_R_CHECK_DEPENDS_ONLY_` = "true", `_R_CHECK_SUGGESTS_ONLY_` = "true",
               `_R_CHECK_CRAN_INCOMING_` = "true", `_R_CHECK_CRAN_INCOMING_REMOTE_` = "true"))
```

## Project structure

| File | Change | Slice |
|---|---|---|
| `R/classes.R` | `ClusterMediationData`, validator, print | extract |
| `R/extract-lmer.R` (new) | `.extract_mediation_lmer()`: checks 1–7, value-based term detection, raw-to-within transform, vcov, warnings | extract |
| `R/zzz.R` | register the `lmerMod` method in `.onLoad` behind `requireNamespace("lme4")`, like lavaan | extract |
| `R/effect-se.R` | `ClusterMediationData` branch in `.effect_gradients()`, plus own and spillover | extract |
| `R/generics-effects.R` | `nie`/`nde`/`te`/`pm`/`paths`/`decompose` methods | extract |
| `R/methods-base.R`, `R/methods-tidy.R` | print/summary with the assumptions block; `glance()` `n_clusters` | extract |
| `R/fit-lmer.R` (new), `R/fit-glm.R` | the `"lmer"` engine, `cluster =`, `se_type = "kr"` | fit |
| `R/bootstrap.R` | `cluster =`, relabeling, failure count; add the class to `.assert_param_mediation_data()` | boot |
| `DESCRIPTION` | `lme4`, `pbkrtest` in Suggests (approved in D3/D5) | extract, fit |
| `_pkgdown.yml`, `NEWS.md`, `inst/WORDLIST` | entries | each PR |
| `vignettes/articles/methods.qmd` | a 2-1-1 section: the models, the effects, D-own, R1, the vcov assumption | fit |
| `tests/testthat/helper-cluster.R` (new) | verification harness below | extract |
| `tests/testthat/test-cluster-211.R` (new) | test groups 1–4, 6–8 | extract, fit, boot |
| `tests/sim/coverage-2-1-1.R` (new), `.Rbuildignore` | coverage study (group 5); `^tests/sim$` | extract |
| `CLAUDE.md`, `AGENTS.md`, `README.md` | class list ("all six classes" becomes seven), file list, engines table | final PR |

## Code style

Match the existing extractors: `checkmate` validation at entry, explicit namespacing
(`lme4::fixef()`, `lme4::getME()`), internal helpers prefixed with `.`, S7 methods `@noRd`,
and error messages that name the model and the term.

```r
# The cluster-mean column is found by value: constant within clusters and equal
# to the mediator's cluster mean on the rows the model used.
.find_cluster_mean_term <- function(X, m, cl, tol = 1e-8) {
  m_bar <- stats::ave(m, cl)
  hits <- colnames(X)[vapply(colnames(X), function(nm) {
    max(abs(X[, nm] - m_bar)) < tol
  }, logical(1))]
  if (length(hits) == 0L) return(NA_character_)
  hits[1L]
}
```

## Testing strategy

Every lme4 test starts with `skip_if_not_installed("lme4")`, and every KR test with
`skip_if_not_installed("pbkrtest")`, so the noSuggests CI job stays green. Seeds are fixed
inside each `test_that()` block, which is the existing convention (`withr` is not in DESCRIPTION).
Heavy oracles use `skip_on_cran()`. CI runs them: r-lib's check action sets `NOT_CRAN = "true"`
(settled in the joint work, `.STATUS`). Each heavy oracle has an always-on companion at small J,
with a value pinned to 1e-8.

1. **Known answer (counterfactual truth).** Simulate from the D-own data-generating process
   (observed-mean interference, as in the Estimand section) with J = 200, n_j = 30.
   `true_cluster_effects()` computes NIE, NDE and TE by switching mediators and treatment
   in the simulated units and differencing means, never through the formulas. The estimates
   fall within 3 SE of the truth, for both parameterizations and for both routes.
2. **Reductions and identities.**
   - The raw and within parameterizations of the same data give the same `b_B`, NIE and SEs
     (R1, 1e-8).
   - Both routes give the same object (1e-8).
   - With `b_W = b_B` in the data-generating process, spillover is within 3 SE of zero.
3. **Total-effect oracle.** `te()` is within 3 SE of the X coefficient in
   `lmer(Y ~ X + C + (1 | cluster))` on the same data.
4. **D-own gap (O3, O4).**
   - With n_j = 50, the own estimate `a·b_W` is within 3 SE of the simulated exact own effect.
   - With dyads (n_j = 2), it misses the truth by the D-own gap, with the gap matching
     `a·(b_B − b_W)/H` to Monte Carlo error. The A3 warning fires.
5. **Coverage (D4, the block-diagonal assumption).**
   - `tests/sim/coverage-2-1-1.R` runs R = 1000 replications per scenario:
     - balanced clusters, 60 × 10;
     - unbalanced sizes drawn from 3–30;
     - a random within-slope;
     - J = 15 with `se_type = "kr"`.
   - Delta-method 95% intervals for NIE, own and spillover cover in [0.936, 0.964], which is
     about ±2 Monte Carlo SE at R = 1000.
   - At J = 15 the normal interval for a product can miss the band because the product's
     sampling distribution is skewed, even with a correct vcov. There the band applies to the
     path intervals (a, b_W, b_B), and product coverage is reported, not gated.
   - The per-replication correlation of â and b̂_B is reported. Results go in a CSV under
     `tests/sim/results/` and in the PR body.
   - The testthat companion runs R = 200 at a wider band, [0.91, 0.99], behind `skip_on_cran()`.
6. **Guards.** Each error from Behavior 1–7 and the fit engine, with a regex naming the term or
   model:
   - `glmerMod`;
   - no cluster intercept;
   - treatment varying within clusters;
   - different rows;
   - a missing mean term;
   - a full-data mean on dropped rows;
   - `X:M_cwc`, `X:M_cm` and `I(X * M)`;
   - a random slope on X;
   - two grouping factors;
   - `weights` and `se_type = "sandwich"` with `engine = "lmer"`;
   - unknown `engine_args`.
   The `lmerModLmerTest` dispatch test passes.
7. **Inference.**
   - With KR, the vcov equals `pbkrtest::vcovAdj()` (1e-10).
   - The A2 warnings fire at J = 20 (model) and J = 8 (any), and stay silent at J = 30.
   - Cluster bootstrap: SEs are within 10% of the model-based delta SE at J = 60 with B = 2000.
   - The relabeling defect is caught (see harness).
   - The failure count is stored.
   - A parametric bootstrap from `@estimates`/`@vcov` reproduces the point NIE exactly.
8. **Positive controls (planted defects, via `effects_from(effect_fn = )`).** Each must make an
   oracle fail:
   - NIE computed as `a·b_W` (the conflated-effect mistake): oracle 1 fails when b_W ≠ b_B.
   - Spillover with its sign flipped: oracle 4 fails.
   - The raw parameterization read as if it were within (`b_B = κ`): oracle 2 (R1) fails.
   - A cluster bootstrap without relabeling: the bootstrap SE check in group 7 fails.
9. **Assumption claims (D9).** With correlated random intercepts, Corr(v_j, u_j) = 0.5 (unmeasured
   additive upper-level confounding), the own estimate stays within 3 SE of the truth, while
   NIE misses it by more than 3 SE at J = 200. This checks the printed assumption lines against
   Talloen et al.'s abstract claim.

## Verification harness

**`tests/testthat/helper-cluster.R`** (new). Each oracle is written once, and planted defects
are injected without editing production code:

| Helper | What it does |
|---|---|
| `sim_cluster211(J, sizes, a, b_W, b_B, c_prime, tau_m, tau_y, rho_vu = 0, slope_sd = 0, seed)` | Data from the observed-mean data-generating process in the Estimand section. `sizes` is a scalar or a vector (unbalanced); `rho_vu` correlates the random intercepts (group 9); `slope_sd` adds a random within-slope. Returns the data plus the true parameters. |
| `true_cluster_effects(dgp, seed)` | Counterfactual truth. Recomputes each unit's mediator under X = 0 and X = 1 with the same noise, then the outcome under: all mediators switched (NIE), treatment switched with mediators held at X = 0 (NDE), and only unit i's mediator switched (exact own effect). It returns differences of means and never calls the effect formulas. |
| `fit_cluster211(dat, parameterization = c("within", "raw"), slope = FALSE, route = c("extract", "fit"), se_type = "model")` | Fits both models the way the tests share, and returns the `ClusterMediationData`. |
| `te_oracle(dat)` | `lmer(Y ~ X + C + (1 \| cluster))`: the X coefficient and its SE. |
| `boot_cluster_se(dat, B, seed, relabel = TRUE)` | Cluster bootstrap, independent of `bootstrap_mediation()`. `relabel = FALSE` is the planted defect. |
| `effects_from(obj, effect_fn = NULL)` | The object's effects. With `effect_fn` supplied, it recomputes them from `@estimates`; the group 8 controls pass broken functions. |

**`tests/sim/coverage-2-1-1.R`** sources the helper file, runs group 5, and writes
`tests/sim/results/coverage-<date>.csv`. It is excluded from the tarball.

**End-to-end run (before each PR).**
- In a fresh R session, simulate a 40-cluster trial with n_j from 5 to 25.
- Fit it through both routes.
- Paste into the PR body: the printed object with its assumptions block, `tidy()`,
  `decompose()` with its warning state, and the oracle-1 comparison.
- A mismatch beyond 3 SE blocks the PR.

## Outcomes

What "done" looks like, check by check. Each row can fail.

| Check | Expected outcome | Pass criterion | PR |
|---|---|---|---|
| Oracle 1 | NIE, NDE and TE match the counterfactual truth, both parameterizations and both routes | within 3 SE | A, B |
| R1 identity | The raw and within fits agree on `b_B`, NIE and SEs | 1e-8 | A |
| Route identity | The fit and extract routes give the same object | 1e-8 | B |
| TE oracle | `te()` matches the reduced-form `lmer` X coefficient | within 3 SE | A |
| D-own gap | Large clusters: the own effect is within 3 SE; dyads: the gap matches `a·(b_B − b_W)/H` and the warning fires | 3 SE; Monte Carlo error | A |
| Coverage | NIE, own and spillover intervals, four scenarios | [0.936, 0.964] at R = 1000 | A (KR scenario: B) |
| Planted defects | All four are caught | each fails its oracle | A, C |
| Guards | Every listed error fires, naming the term or model; the lmerTest fit dispatches | `expect_error()` with a regex | A, B |
| KR vcov | Equals `pbkrtest::vcovAdj()` | 1e-10 | B |
| Cluster bootstrap | SE close to the delta SE; failures counted | within 10% | C |
| Assumption check | Upper-level confounding leaves the own effect unbiased and biases the NIE | 3 SE, both directions | A |
| No regressions | Existing classes and the row bootstrap are unchanged | full suite 0 failed, 0 errors | A, B, C |
| noSuggests job | Passes with lme4 absent | CI green | A, B, C |
| CRAN runtime | The always-on part of `test-cluster-211.R` | target under 10 s, measured in PR A | A |
| Gates | lint, spelling, urls, strict check | 0 lints; clean; 0/0 plus only the Date note | A, B, C |
| E2E transcript | The 40-cluster run through both routes | pasted in the PR body; oracle 1 within 3 SE | A, B, C |

Two rows are targets rather than facts: CRAN runtime and coverage. Coverage is the one that
can overturn a decision: if the block-diagonal vcov under-covers with unbalanced clusters,
D4 goes back to the grill before PR A merges.

## Boundaries

- **Always:**
  - cite only sources in the review's section 9, and characterize each only from the part that
    was read (depth F or W for substantive claims; Field & Welsh 2007 and Lüdtke et al. 2008
    are abstract-only);
  - label medfit-side derivations (D-own, R1, the D4 assumption) as such, each with a test;
  - state thresholds as medfit's choices, anchored to McNeish (2017) and Hox et al. (2014) as
    recorded in D5;
  - run the full suite, the CI-style lint and the strict check before each PR.
- **Ask first:**
  - adding any dependency beyond lme4 and pbkrtest in Suggests;
  - changing an existing class, the row bootstrap's default behavior, or the `tidy()` contract;
  - changing a CI workflow;
  - widening scope to any non-goal;
  - installing packages to reproduce module-2 known answers.
- **Never:**
  - report `a·b_W` as the NIE, or present the conflated coefficient as an effect;
  - accept a `glmer` fit or an X×M term silently;
  - cite the unpublished bridge derivation (review section 4) as a result;
  - cite or characterize a paper that was not read.

## Success criteria

- A 2-1-1 trial fit through either route returns `ClusterMediationData`, whose NIE, NDE and TE
  pass oracle 1 and whose intervals pass the coverage band in all four scenarios.
- `decompose()` gives own and spillover parts labeled as cluster-average and large-cluster,
  with the warning firing for small clusters.
- `print()` and `summary()` state the design, the estimand and the per-quantity assumptions.
- Every non-goal that code can reach errors, naming the fix.
- Full suite 0 failed, 0 errors; lint adds no hits; strict check 0/0 with only the Date NOTE;
  noSuggests green.
- Documentation updated:
  - the Methods and Formulas article covers the 2-1-1 section;
  - `?ClusterMediationData` states the estimand, the assumptions and the observed-mean model;
  - `NEWS.md`, `_pkgdown.yml` and `inst/WORDLIST` have entries;
  - `CLAUDE.md`, `AGENTS.md` and `README.md` list the seventh class, the new files and the `lmer`
    engine.

## Delivery

One feature branch per PR, each merged to `dev` by squash after the gates:

- **PR A (`ml211-extract`):** the class, extraction, gradients, effect generics, print and
  assumptions block, harness, test groups 1–6, 8 and 9 for the extract route, and the coverage
  study for model-based SEs.
- **PR B (`ml211-fit`):** the `lmer` engine, `se_type = "kr"`, the A2 warnings, the route
  identity, the KR coverage scenario, and the Methods and Formulas section.
- **PR C (`ml211-boot`):** cluster resampling, relabeling, the failure count, the bootstrap
  defect control, NEWS, and the `CLAUDE.md`/`AGENTS.md`/`README.md` updates.

## Open questions

- **A1–A5** need approval before the plan.
- If coverage fails (group 5), the options are a joint fit for the cross-equation block, or the
  cluster bootstrap as the default interval. Either reopens D4.
- Module 2's grill should revisit D8 with the individual-average own effect and the D-own exact
  form.

## References

All read for the review; DOIs verified there (section 9). Depth: F full text, W web full text or
sections, A abstract.

- Cheng, C., & Li, F. (2026). *Biometrics*, 82(1). doi:10.1093/biomtc/ujag017 (F)
- Field, C. A., & Welsh, A. H. (2007). Bootstrapping clustered data. *JRSS-B*, 69(3), 369–390.
  doi:10.1111/j.1467-9868.2007.00593.x (A)
- Hox, J. J., Moerbeek, M., Kluytmans, A., & van de Schoot, R. (2014). *Frontiers in
  Psychology*, 5. doi:10.3389/fpsyg.2014.00078 (F)
- Lüdtke, O., Marsh, H. W., Robitzsch, A., & Trautwein, U. (2008). *Psychological Methods*,
  13(3), 203–229. doi:10.1037/a0012869 (A; named as a non-goal only)
- McNeish, D. (2017). *Structural Equation Modeling*, 24(4), 609–625.
  doi:10.1080/10705511.2017.1280797 (F)
- Talloen, W., Moerkerke, B., Loeys, T., & De Naeghel, J. (2016). *JEBS*, 41(4), 359–391.
  doi:10.3102/1076998616636855 (F)
- VanderWeele, T. J. (2010). *Sociological Methods & Research*, 38(4), 515–544.
  doi:10.1177/0049124110366236 (F)
- VanderWeele, T. J., Hong, G., Jones, S. M., & Brown, J. L. (2013). *JASA*, 108(502),
  469–482. doi:10.1080/01621459.2013.779832 (W)
