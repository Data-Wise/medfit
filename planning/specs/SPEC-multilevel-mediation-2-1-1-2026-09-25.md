# Spec: multilevel mediation, module 1 — cluster-level treatment (2-1-1)

**Date:** 2026-09-25 · **Status:** **approved** 2026-09-25 (revision 2, after two adverse reviews; A1-A2 approved as D15-D16)
**Grill:** [GRILL-multilevel-mediation-ext-d-2026-09-25.md](GRILL-multilevel-mediation-ext-d-2026-09-25.md)
(D1–D9; D10–D14 triage the adverse reviews; D15–D16 approve A1–A2)
**Background:** [REVIEW-multilevel-mediation-2026-09-25.md](REVIEW-multilevel-mediation-2026-09-25.md)
(sections 1, 3, 5, 6; read depth for every source is in its section 9)
**Origin:** Ext D in [BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md](BRAINSTORM-medfit-mediationverse-next-features-2026-08-22.md)

**Approval items.**

| # | Item | Status |
|---|---|---|
| A1 | Class name `ClusterMediationData` (treatment varies at the cluster level). Module 2's class is named in its own grill. | approved, D15 |
| A2 | Few-cluster warning: J < 25 with `se_type = "model"` points to `"kr"` and the cluster bootstrap; J < 10 warns whatever the SE type. Both numbers are medfit's choices (see Inference). | approved, D16 |
| A3 | Approximation warning in `decompose()` fires on the relative size of the gap | decided, D11 |
| A4 | `se_type = "kr"`: Kenward-Roger df give t intervals for paths | decided, D10 |
| A5 | Complete-case rows for both models and the cluster means | decided, D12 |

## Goals

1. A user with clustered data, where treatment is assigned to whole clusters (for example a
   cluster-randomized trial), gets the natural indirect, natural direct and total effects of
   that treatment from two linear mixed models, with standard errors. The estimand is stated,
   and so are the assumptions behind each number.
2. The same object comes from both routes: `fit_mediation(engine = "lmer", cluster = )` builds
   the models, and `extract_mediation()` reads the user's own `lmer` fits (D3).
3. The indirect effect splits into an own-mediator part and a spillover part through
   cluster-mates' mediators (D2), labeled as a cluster-average, large-cluster split (D8).
4. Inference matches the other classes: delta-method SEs in `tidy()`/`confint()`/`summary()`
   (D4), Kenward-Roger df for paths (D10), and a cluster bootstrap (D4).
5. Every numeric claim passes an independent oracle, and each planted defect fails one, with
   the power to fail stated in advance.

## Non-goals (module 1)

Each of these gets an error naming the problem (see Behavior) or a line in the docs:

- **1-1-1 designs** (treatment varies within clusters) and σ_ab. These are module 2 (D1).
- **`glmer` or other non-Gaussian families.** `a·b_B` on the link scale is not the NIE (D7).
- **Products of a mediator term with the treatment or with a covariate**, including cross-level
  ones. They make `a·b_B` a conditional effect (D7, D13).
- **Random slopes on the raw mediator or on its cluster mean.** A slope on raw M loads on M̄_j
  and changes the model (D13). Random slopes on the *within* term are accepted.
- **Latent cluster means and partially sampled clusters.** The estimand uses the observed mean
  of the members in the analysis rows (see Estimand). The latent-covariate approach of
  Lüdtke et al. (2008) is a different model, not an option here.
- **Individual-average effects** and the exact finite-cluster own/spillover split (D8, module 2).
- **`weights` and `se_type = "sandwich"` with `lmer`.** lme4 weights are precision weights,
  not the IPW weights of the glm engine.
- **Three-level or cross-classified models** (more than one grouping factor).
- **Multilevel lavaan** (`cluster =` in `lavaan::sem()`).
- **KR degrees of freedom for products.** Product intervals stay normal-based (D10).

## Capability map

| Module id | Responsibility | Depends on | This spec |
|---|---|---|---|
| `ml211-extract` | `ClusterMediationData`, `extract_mediation()` for `lmerMod`, gradients, effect generics, print with the assumptions block | — | **yes** |
| `ml211-fit` | `fit_mediation(engine = "lmer", cluster = )`, `se_type = "kr"`, few-cluster warnings | `ml211-extract` | **yes** |
| `ml211-boot` | Cluster resampling in `bootstrap_mediation()` | `ml211-extract` | **yes** |
| `ml111` | 1-1-1 designs, σ_ab, cluster weighting | module 1 conventions | no (own grill) |

Build order: `ml211-extract` → `ml211-fit` and `ml211-boot` in either order.

## Estimand and formulas

**Design.** Clusters j = 1…J of size n_j. Treatment X_j is constant within a cluster and
clusters stay intact (no one moves between clusters; Talloen et al. 2016, p. 363). The mediator
M_ij and outcome Y_ij are measured on individuals. M̄_j is the **observed** mean of the
mediator over the cluster members in the analysis rows.

**Models (Talloen et al. 2016, eqs. 5–6, p. 367; read in full).** Level-1 covariates C_ij enter
the outcome model centered, with their cluster means, as in Talloen's eqs. 9–10 (p. 370).
Level-2 covariates W_j enter both models as they are.

- Mediator: `M_ij = β0 + a·X_j + β2'C_ij + β3'W_j + v_j + r_ij`
- Outcome, within parameterization:
  `Y_ij = θ0 + c′·X_j + b_W·(M_ij − M̄_j) + b_B·M̄_j + θ4'(C_ij − C̄_j) + θ5'C̄_j + θ6'W_j + u_j + e_ij`
- Outcome, raw parameterization: the same with `b_W·M_ij + κ·M̄_j` in place of the mediator
  terms, so `b_B = b_W + κ` (medfit-side identity R1; it holds for random-intercept fits and for
  random slopes on the within term only).

Talloen et al. define interference through the mean of the other members of the cluster
(p. 363), then use the class mean instead, noting the two are close in groups of 20 or more
(p. 367). Medfit follows the class-mean model.

**Effects.**

| Effect | Formula | Accessor | Source of the product form |
|---|---|---|---|
| NIE | `a·b_B` | `nie()` | Talloen et al. p. 368 (`β1(θ2 + θ3)`) |
| NDE | `c′` | `nde()` | Talloen et al. p. 368 |
| TE | `a·b_B + c′` | `te()` | — |
| PM | `a·b_B / (a·b_B + c′)` | `pm()` | — |
| Own-mediator (within) indirect | `a·b_W` | `decompose()` | Talloen et al. p. 368 (`β1θ2`) |
| Spillover (contextual) indirect | `a·(b_B − b_W)` | `decompose()` | Talloen et al. p. 368 (`β1θ3`) |

Talloen et al. define the decomposition in eqs. 1–2 (p. 364). VanderWeele (2010) defines the
NDE and NIE of a cluster-level treatment and gives coefficient products for linear
random-intercept models without interference (pp. 528–529); the interference case used here
rests on Talloen et al. Cheng & Li (2026) name the parts the individual and spillover mediation
effects and define cluster-average and individual-average versions.

**Why the NIE needs no weighting (D8).** Changing X_j shifts every member's mediator by a. The
deviations M_ij − M̄_j do not change, M̄_j moves by a, and Y moves by a·b_B in every cluster.
This holds with random slopes on the within term because X cannot carry a random slope (it is
constant within clusters) and M̄_j carries none (D13). This argument is medfit's; Talloen's
modeling assumptions (pp. 367–368) exclude slope heterogeneity.

**Medfit-side derivations.** These are not taken from a paper. Each has a test that can fail.

- **D-own. Exact own effect under the fitted model.** Shift only individual i's mediator by a.
  M̄_j moves by a/n_j and the deviation by a(1 − 1/n_j), so the own effect is
  `a·b_W + a·(b_B − b_W)/n_j`. With equal cluster weights the gap from `a·b_W` is
  `a·(b_B − b_W)·mean(1/n_j) = a·(b_B − b_W)/H`, where H is the harmonic mean cluster size.
  Under Talloen's peer-mean model, the fitted `b_W` equals θ2 − θ3/(n_j − 1), and D-own recovers
  aθ2 exactly for balanced clusters only. Tests O3, O4 and O5.
- **R1. Raw to within.** `b_B = b_W + κ`, with the linear vcov transform `J V J'`. Test R1.
- **D4. Block-diagonal vcov.** Given (X, M, C, W), the outcome errors have mean zero under the
  model, and â depends only on (X, M, C, W). So Cov(â, b̂_B) and Cov(â, ĉ′) are zero to first
  order. The argument fails under upper-level M–Y confounding, the same condition that biases
  the NIE. One simulated dataset gave a cluster-bootstrap correlation of −0.06. Test group 5
  gates it.

**Identification assumptions (printed per D9).** In every row, the models are linear with no
mediator × treatment or mediator × covariate products, X is unconfounded (randomized), and
clusters are intact.

| Quantity | Also needs | Source |
|---|---|---|
| Own `a·b_W` | no unmeasured lower-level M–Y confounding. Unmeasured upper-level confounders are allowed if their effects are additive, **provided level-1 covariates are cluster-mean centered**. | Talloen et al. 2016, abstract; M1 p. 367; eqs. 9–10 and 14, pp. 370, 372–374 |
| Spillover, NIE and NDE | also no unmeasured upper-level M–Y confounding. Under it, the direct and contextual estimators are biased, while their sum `c′ + a·κ` is not. | Talloen et al. 2016, p. 374 (eqs. 17–18) |
| TE | none beyond the first line (X randomized) | — |
| The own/spillover split | a cross-world assumption across individuals in a cluster; no treatment-induced M–Y confounding | Talloen et al. 2016, eq. 4 and A4, pp. 365–366; Cheng & Li 2026, Assumption 5 |
| All | interference only through the observed cluster mean of the mediator, none between clusters; members missing from the analysis rows are assumed not to drive their peers' outcomes (D12) | Talloen et al. 2016, pp. 363, 367; D12 |

## Behavior

**Extraction (`ml211-extract`).** The generic dispatches on its first argument, `object`:
`extract_mediation(object, model_y = , treatment = , mediator = , cluster = NULL,
se_type = c("model", "kr"))`, where `object` is the mediator model. The lm method selects its
vcov with `vcov_fun`. The lmer method uses `se_type`, matching `fit_mediation()`, and errors on
`vcov_fun`.

1. The method is registered for lme4's `merMod` class in `.onLoad`, behind
   `requireNamespace("lme4")`, like lavaan. It accepts `lmerMod` and anything that inherits
   from it. `glmerMod` gets the D7 error, not S7's "can't find method".
2. `cluster` defaults to the single grouping factor shared by both models. With more than one
   factor, or factors that differ, it errors and asks for `cluster =`.
3. Each model has a `(1 | cluster)` intercept, or it errors with the corrected formula.
4. X is constant within every cluster, or it errors: "treatment varies within clusters; 1-1-1
   designs are not supported yet".
5. Both models use identical rows: the same number of rows, the same cluster vector and the same
   treatment vector in the same order. Otherwise it errors (D12).
6. **Term detection is by values, not names.** In the outcome model's fixed-effect design
   (`lme4::getME(fit, "X")`):
   - the cluster-mean term is the column that is constant within clusters and an exact affine
     function of M̄_j on the model rows, which covers grand-mean centering and `scale()`;
   - the within term is an affine function of M − M̄_j with zero cluster means;
   - the raw term is an affine function of M.
   Coefficients are rescaled by the affine slope, and the vcov accordingly. The within + mean pair
   and the raw + mean pair are accepted (D3). A missing mean term errors with the corrected
   formula. A near-miss, meaning constant within clusters and correlated above 0.99 with M̄_j but
   not affine, errors: "the cluster mean must be computed on the rows the models use (complete
   cases)".
7. Product guards (D7, D13) run on the names found by value detection, not on the user's names.
   Any product of a mediator term with X or a covariate errors, naming the term. Random slopes
   are read from `lme4::getME(fit, "cnms")`. A slope on the within term is accepted. A slope on
   the raw term, on the mean term or on X errors as unsupported.
8. Level-1 covariates in the outcome model that vary within clusters but have no cluster-mean
   companion are accepted. The printed own-effect line then drops the upper-level robustness
   clause and says why.
9. `@vcov` is block-diagonal over the alias rows `a`, `c_prime`, `b_within`, `b_between`, plus
   each model's full fixed effects, coerced to base matrices (lme4 returns a `dpoMatrix`).
10. `se_type = "kr"` needs REML fits and errors on ML fits, because `pbkrtest::vcovAdj()`
    silently returns the REML matrix. It stores the KR vcov and the KR df of each path
    coefficient.
11. The A2 warnings fire once per call (`.notify_once`).

**Fit engine (`ml211-fit`).** `fit_mediation(formula_y = Y ~ X + M + C + W, formula_m =
M ~ X + C + W, data, treatment, mediator, engine = "lmer", cluster = "school",
se_type = c("model", "sandwich", "kr"), engine_args = list())`:

- The engine drops incomplete rows once (D12), and flags level-1 covariates as those that vary
  within some cluster. It computes `<M>_cm`, `<M>_cwc`, `<C>_cm` and `<C>_cwc` on the remaining
  rows. It rewrites the outcome formula to the within parameterization with centered level-1
  covariates plus their means, adds `(1 | cluster)` to both models, and fits with `REML = TRUE`
  (D5).
- `engine_args` accepts:
  - `random_y`, a one-sided formula of level-1 terms to get correlated random slopes in the
    outcome model (`~ M` is rewritten to the within term);
  - `random_m`, the same for the mediator model;
  - `REML`.
  Anything else errors, and `...` does not reach `lmer()`.
- `cluster =` and `se_type = "kr"` error with the glm and regmedint engines. `weights` and
  `se_type = "sandwich"` error with `engine = "lmer"`.
- If lme4 is not installed, it errors naming the package; `se_type = "kr"` without pbkrtest, the
  same.
- The fitted models are passed to `extract_mediation()`, so the route identity holds by
  construction for the effects, and the test checks the plumbing.

**Effects and methods.**

- `nie()`, `nde()`, `te()`, `pm()` and `paths()` follow the effects table.
  `coef()`, `vcov()`, `nobs()` and `confint(parm = "paths")` use the alias rows through
  `.path_se()`.
- `decompose()` returns own, spillover and NIE, labeled "cluster-average, large-cluster
  approximation". **D11:** it warns when the D-own gap `|a·(b_B − b_W)|/H` exceeds half the own
  effect's SE. `summary()` always prints the gap.
- `tidy()`, `confint()` and `summary()` use `.effect_gradients()`: NIE
  `(a: b_B, b_between: a)`, own `(a: b_W, b_within: a)`, spillover
  `(a: b_B − b_W, b_between: a, b_within: −a)`.
  - **D10:** with `se_type = "kr"`, path intervals are t intervals with the KR df.
  - Product intervals are normal delta-method intervals. With J < 25, the A2 warning points to
    the cluster bootstrap for them.
- `print()` and `summary()` end with the "Estimand and assumptions" block: the design, the
  number of clusters and the cluster-size range, then one line per row of the assumptions
  table, adjusted by Behavior 8 (D9). `tidy()` and `glance()` stay plain tibbles; `glance()`
  gains `n_clusters`, following the `n_mediators` precedent.
- `quick()` works; `med()` does not take `cluster =` in module 1.

**Cluster bootstrap (`ml211-boot`).** `bootstrap_mediation(method = "nonparametric",
cluster = "school", ...)`:

- It draws J cluster ids with replacement and gives each draw a fresh id before `statistic_fn`
  sees the data. Without this, a cluster drawn twice would be refit as one bigger cluster.
  Field & Welsh (2007; abstract read) is cited only for resampling whole clusters.
- **D14:** singular fits and convergence warnings from a refit count as failures. They are
  caught with `withCallingHandlers()`, their per-refit messages are suppressed, and the count
  goes into the existing warning. `@n_boot` already holds the successes. `BootstrapResult` is
  unchanged.
- `cluster = NULL` keeps today's row bootstrap unchanged. `cluster =` with `method =
  "parametric"` or `"plugin"` errors.

## Class sketch

Property names and types follow the existing classes in `R/classes.R`:

```r
ClusterMediationData <- S7::new_class(
  "ClusterMediationData",
  package = "medfit",
  properties = list(
    a_path = S7::class_numeric, b_within = S7::class_numeric,
    b_between = S7::class_numeric, c_prime = S7::class_numeric,
    estimates = S7::class_numeric, vcov = S7::new_S3_class("matrix"),
    kr_df = S7::class_numeric | NULL,           # per path, se_type = "kr" only
    treatment = S7::class_character, mediator = S7::class_character,
    outcome = S7::class_character, cluster = S7::class_character,
    n_obs = S7::class_integer, n_clusters = S7::class_integer,
    cluster_sizes = S7::class_integer,          # one entry per cluster
    parameterization = S7::class_character,     # "within" or "raw" (as fitted)
    covariates_centered = S7::class_logical,    # drives Behavior 8
    se_type = S7::class_character,              # "model" or "kr"
    reml = S7::class_logical, converged = S7::class_logical,
    sigma_m = S7::class_numeric, sigma_y = S7::class_numeric,  # residual SDs
    tau_m = S7::class_numeric, tau_y = S7::class_numeric,      # intercept SDs
    data = S7::class_data.frame | NULL,
    source_package = S7::class_character
  ),
  validator = function(self) {
    # scalars are length 1; n_clusters == length(cluster_sizes); sum(cluster_sizes) == n_obs;
    # alias rows a, c_prime, b_within, b_between present in estimates and vcov and equal to the
    # path properties; parameterization and se_type in their sets; kr_df present iff se_type
    # is "kr"
  }
)
```

The `class_numeric | NULL` pitfall (it defaults to `numeric(0)`) applies to `kr_df`.
`.onLoad` gains `S4_register()`, the `show` method and the `print.summary` registration for the
class, plus its branches in the tidy/glance chains.

## Inference

- **SEs.** Model-based fixed-effect vcov from lme4 by default. Kenward-Roger changes the SEs
  very little: one check at J = 15 with unbalanced clusters gave ratios of 1.000–1.002. Its
  value is the df (D10).
- **Few clusters (A2, approved as D16).** J < 25 with model-based SEs warns and points to `"kr"` for paths
  and the cluster bootstrap for products. J < 10 warns whatever the SE type. Both numbers are
  medfit's choices. For the record:
  - McNeish (2017) always used REML with KR in the mixed-model arm, and judged coverage
    against Bradley's band;
  - Hox et al. (2014) varied the number of clusters per treatment condition and studied ML-SEM
    in Mplus;
  - neither shows that lme4's model-based SEs fail below 25 clusters.

## Commands

```r
devtools::load_all(); devtools::document()
testthat::test_file("tests/testthat/test-cluster-211.R")
devtools::test()                              # report failed + error counts
Rscript tests/sim/coverage-2-1-1.R            # simulation gates (not run by testthat)
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
| `R/extract-lmer.R` (new) | `.extract_mediation_lmer()`: checks 1–10, value-based affine term detection, `.raw_to_within()`, vcov, KR df, warnings | extract |
| `R/zzz.R` | `merMod` method registration behind `requireNamespace("lme4")`; `S4_register`, `show`, `print.summary` | extract |
| `R/effect-se.R` | `ClusterMediationData` branch in `.effect_gradients()`, own and spillover; KR df for path intervals | extract |
| `R/generics-effects.R` | `nie`/`nde`/`te`/`pm`/`paths`/`decompose` methods | extract |
| `R/methods-base.R`, `R/methods-tidy.R` | coef/vcov/nobs/confint/print/summary with the assumptions block; tidy/glance branches, `n_clusters` | extract |
| `R/fit-lmer.R` (new), `R/fit-glm.R` | the `"lmer"` engine, `cluster =`, `se_type = "kr"`, engine checks | fit |
| `R/bootstrap.R` | `cluster =`, relabeling, failure counting; the class in `.assert_param_mediation_data()` | boot |
| `DESCRIPTION` | `lme4`, `pbkrtest` in Suggests (approved in D3/D5); drop the "future support for mixed models" line | extract, fit |
| `_pkgdown.yml`, `NEWS.md`, `inst/WORDLIST` | entries | each PR |
| `vignettes/articles/methods.qmd` | 2-1-1 section: models, effects, D-own, R1, the D4 argument, the assumptions table | fit |
| `tests/testthat/helper-cluster.R` (new) | verification harness | extract |
| `tests/testthat/test-cluster-211.R` (new) | always-on tests and the `skip_on_cran()` companions | extract, fit, boot |
| `tests/sim/coverage-2-1-1.R` (new), `tests/sim/results/`, `.Rbuildignore` | simulation gates (groups 5 and 9); `^tests/sim$` | extract |
| `CLAUDE.md`, `AGENTS.md`, `README.md` | seven classes, new files, the `lmer` engine | final PR |

## Code style

Match the existing extractors: `checkmate` validation at entry, explicit namespacing
(`lme4::fixef()`, `lme4::getME()`), internal helpers prefixed with `.`, S7 methods `@noRd`,
and error messages that name the model and the term.

```r
# The cluster-mean column is found by value: constant within clusters and an
# exact affine function of the mediator's cluster mean on the model rows.
# Returns the column name and the slope used to rescale its coefficient.
.find_cluster_mean_term <- function(X, m, cl, tol = 1e-8) {
  m_bar <- stats::ave(m, cl)
  for (nm in colnames(X)) {
    x <- X[, nm]
    if (max(abs(x - stats::ave(x, cl))) > tol || stats::sd(x) == 0) next
    fit <- stats::lm.fit(cbind(1, m_bar), x)
    if (max(abs(fit$residuals)) < tol) {
      return(list(term = nm, slope = unname(fit$coefficients[2])))
    }
  }
  NULL
}
```

## Testing strategy

- Every lme4 test starts with `skip_if_not_installed("lme4")`, and every KR test with
  `skip_if_not_installed("pbkrtest")`, so the noSuggests CI job stays green. Examples that use
  lme4 are wrapped in `if (requireNamespace("lme4", quietly = TRUE))`.
- Seeds are fixed inside each `test_that()` block, the existing convention.
- **Tolerances.** Identities computed within one run (R1, route identity, gradients) use 1e-8.
  Constants pinned against a stored value use 1e-6 relative: changing the lme4 optimizer moved
  fixed effects by about 4e-8 and SEs by about 7e-7.
- **Where heavy checks run.** Anything that needs many replications runs in `tests/sim/`, not
  testthat. testthat keeps deterministic checks and `skip_on_cran()` companions. CI runs the
  companions: r-lib's check action sets `NOT_CRAN = "true"` (settled in the joint work, `.STATUS`).
- **Power.** Every oracle that must fail for a planted defect states the defect's size in SE
  units. It is at least 6 SE, or the check runs as mean bias over replications.

**Test groups.**

1. **Known answer (counterfactual truth).**
   - Data: the class-mean process, J = 200, n_j = 30, with centered covariates.
   - `true_cluster_effects()` computes NIE, NDE and TE with equal cluster weights by switching
     mediators and treatment in the simulated units, never through the formulas.
   - The estimates fall within 3 SE, for both parameterizations and both routes.
   - A pinned small-J companion stays always-on.
2. **Identities.**
   - R1: raw and within random-intercept fits give the same `b_B`, NIE and SEs (1e-8).
   - Route identity (1e-8).
   - Affine detection: a grand-mean-centered and a `scale()`d mean term give the same effects
     (1e-8).
3. **Total effect.** `te()` against the X coefficient of `lmer(Y ~ X + C̄ + W + (1 | cluster))`,
   judged against the SE of the difference from the cluster bootstrap in the harness, not 3 SE
   of either estimate. Heavy; `tests/sim/`.
4. **D-own (O3–O5).**
   - O3: with n_j = 50, own is within 3 SE of the simulated exact own effect.
   - O4: with dyads, the estimate misses the truth by the D-own gap, which matches
     `a·(b_B − b_W)/H` to Monte Carlo error. The D11 warning fires. The contextual effect is
     large enough that the gap exceeds 6 SE of own.
   - O5: the peer-mean process with unbalanced n_j (sizes 2–10). The D-own truth under the
     class-mean model is compared with the peer-mean truth, and the difference is reported, not
     gated. This documents the approximation, not medfit's correctness.
   - Spillover is checked directly against the true NIE minus the true own effect at n_j = 50.
5. **Simulation gates (`tests/sim/coverage-2-1-1.R`).** R = 1000 per scenario:
   - balanced, 60 × 10;
   - unbalanced, sizes 3–30;
   - a random within-slope;
   - J = 15 with `se_type = "kr"`.
   Gates:
   - **SE ratio.** The mean delta SE divided by the empirical SD across replications is within
     [0.9, 1.1] for NIE, own and spillover.
   - **Cross-replication correlation** of â and b̂_B, |r| < 0.1 (D4).
   - **Coverage.** Bradley's (0.925, 0.975) band for path intervals, including the KR t
     intervals at J = 15. Product coverage is reported, not gated, because the product's
     skewness is not a vcov error.
   Results go in `tests/sim/results/coverage-<date>.csv` and in the PR body. The testthat
   companion runs R = 100 of the balanced scenario with the SE-ratio band widened to [0.8, 1.2].
6. **Guards.** Every error in Behavior 1–11 and in the fit engine, each with a regex naming the
   term or model:
   - `glmerMod`;
   - no cluster intercept;
   - treatment varying within clusters;
   - different rows;
   - a missing mean term;
   - a near-miss mean;
   - `X:M_cwc`, `X:M_cm`, `M_cwc:C`, `I(X * M)`;
   - random slopes on raw M, on the mean term and on X;
   - two grouping factors;
   - `kr` on an ML fit;
   - `vcov_fun` on the lmer method;
   - `cluster =` and `kr` with the glm engine;
   - `weights` and `"sandwich"` with lmer;
   - unknown `engine_args`;
   - `cluster =` with a parametric bootstrap.
   Dispatch for a subclass is tested with a local `setClass(contains = "lmerMod")`, so lmerTest
   is not needed as a dependency.
7. **Inference.**
   - KR df are positive and below J for the cluster-level paths.
   - The A2 warnings fire at J = 20 (model) and J = 8 (any), stay silent at J = 30, and fire once
     per call.
   - A parametric bootstrap from `@estimates`/`@vcov` reproduces the point NIE exactly.
   - Cluster bootstrap: every resample has J distinct ids (structural), and a forced singular fit
     is counted in the warning.
8. **Positive controls (planted defects).** Each must make its oracle fail, at the stated size:
   - NIE computed as `a·b_W`, via `effects_from(effect_fn = )`, on a low-noise process with
     `a·(b_B − b_W)` at least 6 SE: oracle 1 fails.
   - Spillover with its sign flipped, via `effect_fn`: the group 4 spillover check fails.
   - Raw read as within (`b_B = κ`), via `local_mocked_bindings(.raw_to_within = )`: R1 fails.
   - A cluster bootstrap without relabeling, through `bootstrap_mediation()` itself, via
     `local_mocked_bindings` on its relabel helper, at ICC ≥ 0.3: the structural check in group
     7 fails, and the SE falls below 0.9 × delta SE.
9. **Assumption claims (D9, `tests/sim/`).** With correlated random intercepts, Corr(v_j, u_j) =
   0.5, and centered covariates, over R = 200 replications at J = 100:
   - the mean bias of own is within 2 Monte Carlo SE of zero;
   - the NIE and NDE biases are more than 4 Monte Carlo SE from zero, in the directions
     Talloen's eqs. 17–18 imply;
   - TE and `c′ + a·κ` show no bias.
   A second run with uncentered covariates correlated with u_j shows that own becomes biased,
   which is the reason for Behavior 8.

## Verification harness

**`tests/testthat/helper-cluster.R`** (new). Each oracle is written once, and planted defects
are injected without editing production code:

| Helper | What it does |
|---|---|
| `sim_cluster211(J, sizes, a, b_W, b_B, c_prime, tau_m, tau_y, rho_vu = 0, slope_sd = 0, cov = c("none", "centered", "confounded"), process = c("class_mean", "peer_mean"), seed)` | Data from a known process. `sizes` is a scalar or a vector (unbalanced). `rho_vu` correlates the random intercepts. `slope_sd` adds a random within-slope. `cov` controls the level-1 covariate. `process = "peer_mean"` uses the mean of the other members (O5). Returns the data plus the true parameters. |
| `true_cluster_effects(dgp, seed)` | Counterfactual truth with equal cluster weights. Recomputes each unit's mediator under X = 0 and X = 1 with the same noise, then the outcome under: all mediators switched (NIE), treatment switched with mediators held (NDE), and only unit i's mediator switched (exact own effect). It never calls the effect formulas. |
| `fit_cluster211(dat, parameterization = c("within", "raw"), slope = FALSE, route = c("extract", "fit"), se_type = "model")` | Fits both models the way the tests share, and returns the `ClusterMediationData`. |
| `te_oracle(dat, B)` | The reduced-form `lmer` X coefficient, and the cluster-bootstrap SE of its difference from `te()`. |
| `effects_from(obj, effect_fn = NULL)` | The object's effects, or recomputed from `@estimates` with a supplied `effect_fn` (group 8). |
| `sim_gate(scenario, R, seed)` | Used by `tests/sim/coverage-2-1-1.R`: returns SE ratios, the cross-replication correlation, path coverage and product coverage. |

**End-to-end run (before each PR).**
- In a fresh R session, simulate a 40-cluster trial with n_j from 5 to 25, a level-1 and a
  level-2 covariate.
- Fit it through both routes.
- Paste into the PR body: the printed object with its assumptions block, `tidy()`,
  `decompose()` with its warning state, and the oracle-1 comparison.
- A mismatch beyond 3 SE blocks the PR.

## Outcomes

What "done" looks like, check by check. Each row can fail.

| Check | Expected outcome | Pass criterion | PR |
|---|---|---|---|
| Oracle 1 | NIE, NDE, TE match the counterfactual truth, both parameterizations and both routes | within 3 SE | A, B |
| Identities | R1, route identity, affine detection | 1e-8 | A, B |
| TE oracle | `te()` against the reduced form | within 3 SE of the difference | A |
| D-own | Large clusters within 3 SE; dyad gap matches `a·(b_B − b_W)/H`; spillover matches truth | 3 SE; Monte Carlo error | A |
| SE ratio | Delta SE over empirical SD, four scenarios | [0.9, 1.1] | A (KR scenario: B) |
| D4 correlation | Cross-replication corr(â, b̂_B) | \|r\| < 0.1 | A |
| Path coverage | Including KR t intervals at J = 15 | Bradley (0.925, 0.975) | A, B |
| Planted defects | All four fail their oracles at the stated power | each fails | A, C |
| Assumption claims | Own unbiased; NIE and NDE biased; TE unbiased under upper-level confounding; own biased with uncentered confounded covariates | mean bias vs Monte Carlo SE, as stated | A |
| Guards | Every listed error names the term or model; subclass dispatch works | `expect_error()` with a regex | A, B, C |
| Cluster bootstrap | Distinct ids per resample; singular fits counted | structural; count in the warning | C |
| No regressions | Existing classes and the row bootstrap are unchanged | full suite 0 failed, 0 errors | A, B, C |
| noSuggests job | Passes with lme4 absent | CI green | A, B, C |
| CRAN runtime | The always-on part of `test-cluster-211.R` | target under 10 s, measured in PR A | A |
| Gates | Lint, spelling, URLs, strict check | 0 lints; clean; 0/0 plus only the Date note | A, B, C |
| E2E transcript | The 40-cluster run through both routes | pasted in the PR body; oracle 1 within 3 SE | A, B, C |

Two rows are targets rather than facts: CRAN runtime and the simulation gates. The D4
correlation and the SE ratio can overturn a decision: if either fails with unbalanced clusters
or random within-slopes, D4 goes back to the grill before PR A merges.

## Boundaries

- **Always:**
  - cite only sources in the review's section 9, and characterize each from the part that was
    read. Substantive claims need depth F or W; Field & Welsh (2007) and Lüdtke et al. (2008)
    are abstract-only;
  - label medfit-side derivations and arguments (D-own, R1, D4, the no-weighting argument with
    random within-slopes) as such, each with a test;
  - state thresholds as medfit's choices;
  - run the full suite, the CI-style lint and the strict check before each PR.
- **Ask first:**
  - adding any dependency beyond lme4 and pbkrtest in Suggests (lmerTest included);
  - changing an existing class (`BootstrapResult` included), the row bootstrap's default behavior,
    or the `tidy()` contract;
  - changing a CI workflow;
  - widening scope to any non-goal;
  - installing packages to reproduce module-2 known answers.
- **Never:**
  - report `a·b_W` as the NIE, or present the conflated coefficient as an effect;
  - accept a `glmer` fit, a mediator product or a raw-M random slope silently;
  - cite the unpublished bridge derivation (review section 4) as a result;
  - cite or characterize a paper that was not read.

## Success criteria

- A 2-1-1 trial fit through either route returns `ClusterMediationData`. Its NIE, NDE and TE
  pass oracle 1, and its SE ratio, D4 correlation and path coverage pass in all four scenarios.
- `decompose()` gives own and spillover parts labeled cluster-average and large-cluster. The
  D11 warning fires when the gap is material.
- `print()` and `summary()` state the design, the estimand and the per-quantity assumptions,
  including the covariate-centering condition.
- Every non-goal that code can reach errors, naming the fix.
- Full suite 0 failed, 0 errors; lint adds no hits; strict check 0/0 with only the Date NOTE;
  noSuggests green.
- Documentation updated:
  - the Methods and Formulas article has the 2-1-1 section;
  - `?ClusterMediationData` states the estimand, the assumptions and the observed-mean model;
  - `NEWS.md`, `_pkgdown.yml`, `inst/WORDLIST` and DESCRIPTION are updated;
  - `CLAUDE.md`, `AGENTS.md` and `README.md` list the seventh class, the new files and the
    `lmer` engine.

## Delivery

One feature branch per PR, each merged to `dev` by squash after the gates:

- **PR A (`ml211-extract`):** the class, extraction, gradients, effect generics, methods,
  assumptions block, harness, groups 1–2, 4–6, 8 and 9 for the extract route, and the
  simulation gates for model-based SEs.
- **PR B (`ml211-fit`):** the `lmer` engine with covariate centering, `se_type = "kr"` and KR
  df, the A2 warnings, the route identity, the KR scenario, and the Methods and Formulas
  section.
- **PR C (`ml211-boot`):** cluster resampling, relabeling, failure counting, the bootstrap
  controls, the TE oracle, NEWS, and the `CLAUDE.md`/`AGENTS.md`/`README.md` updates.

## Adverse review record

Two independent reviews ran on revision 1 (2026-09-25): one on statistics and citations, one on
implementation and the harness. Both ran R checks. Revision 2 applies:

- **Blockers fixed.**
  - KR was a no-op on SEs (ratio 1.000–1.002), so A4 now uses KR df (D10).
  - The fit engine now centers level-1 covariates; without centering, the own effect's
    robustness claim was false. One reviewer's run: b̂_W 0.349 raw vs 0.395 centered, truth 0.40.
  - Random slopes on raw M change the model (Δb_B up to 0.06), so only within-term slopes are
    allowed (D13).
  - Two positive controls and group 9 had no power at one seed: the `a·b_W` defect sat at
    z = −1.4, and group 9 failed in 37 of 40 seeds. Group 9 is now mean bias over replications,
    and each defect has a stated size.
  - The J = 15 normal-interval gate failed by construction (0.928 at df = 13), so the J = 15
    scenario now uses KR t intervals and Bradley's band.
- **Majors fixed.**
  - NDE added to the confounding row, and a TE row added (Talloen p. 374, verified).
  - Locators corrected and verified: eqs. 1–2 p. 364, products p. 368, robustness pp. 370,
    372–374, intact clusters p. 363, and the attribution to VanderWeele (2010) narrowed.
  - A2 anchors restated as medfit's choice.
  - Coverage gates replaced by the SE ratio, the cross-replication correlation and Bradley's band.
  - `glmer` dispatch through `merMod`.
  - Subclass dispatch tested without lmerTest.
  - `kr` errors on ML fits.
  - Pinned tolerance 1e-6.
  - Mediator × covariate product guard, run on value-detected names.
  - Affine term detection.
  - Planted defects injected through `local_mocked_bindings` where `effect_fn` cannot reach.
  - Bootstrap failures counted without a class change (D14).
  - D12's observed-members assumption printed.
  - Class properties aligned with house conventions (`n_obs`, `package`, `source_package`).
- **Declined.**
  - The KR-equals-`vcovAdj()` test was dropped as tautological.
  - A3 at H < 20 was replaced by the relative-gap trigger (D11) rather than kept.

## Open questions

- ~~A1 and A2 need approval before the plan~~ — approved 2026-09-25 (D15, D16).
- If the SE ratio or the D4 correlation fails (group 5), the options are a joint fit for the
  cross-equation block, or the cluster bootstrap as the default interval. Either reopens D4.
- Module 2's grill should revisit D8 with the individual-average own effect and the D-own exact
  form, and decide whether to model the peer mean directly.

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
