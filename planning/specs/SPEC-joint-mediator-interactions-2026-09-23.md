# Spec: joint natural effects for serial and parallel mediators with exposure–mediator products (D8(b))

**Date:** 2026-09-23 · **Status:** **approved** 2026-09-23 (after grill G1–G6, two adverse reviews G7–G8, consistency pass G9)
**Grill:** [GRILL-joint-mediator-interactions-2026-09-23.md](GRILL-joint-mediator-interactions-2026-09-23.md) (G1–G6, G7 and G8: triage of two adverse reviews, G9: consistency pass and approval)
**Origin:** D8(b) in [GRILL-bundled-example-data-2026-09-23.md](GRILL-bundled-example-data-2026-09-23.md).
It replaces part of the D8(a) guard (PR #62, `aa3362c`), which today makes every multi-mediator
extraction with a product term error.
**Decisions taken before drafting (2026-09-23):**

| # | Question | Decision |
|---|---|---|
| Q1 | Estimand | **Joint natural effects** through all mediators together (VanderWeele & Vansteelandt 2014) |
| Q2 | Structures | **Serial and parallel** |
| Q3 | Engines | **lm/glm first.** lavaan keeps the D8(a) error |
| Q4 | Computation | **Closed form, Gaussian first.** Other families error |

## Objective

A user who fits a serial (`X → M1 → M2 → Y`) or parallel (`X → {M1, M2} → Y`) model and includes
an **exposure × mediator** product in the outcome model (for example `Y ~ X * M2 + M1 + C`) gets
the **joint** controlled direct, natural direct, natural indirect and total effects through the
whole mediator vector, with standard errors. The current result is an error. Before PR #62 it was
worse: main-effect numbers that silently ignored the product.

**What the user gives up, stated in the docs:** with a product present, the indirect effect is not
split into per-mediator or per-path pieces. The estimand is the effect through `(M1, …, MK)`
jointly. Per-path splits need stronger assumptions (Daniel et al. 2015) or different estimands
(interventional effects, Vansteelandt & Daniel 2017). Both are out of scope here.

## Capability map

Q1–Q4 phase the work. This spec covers **module 1 only**. Later modules each get their own spec.

| Module id | Responsibility | Depends on | This spec |
|---|---|---|---|
| `joint-xm-lm` | Joint CDE/NDE/NIE/TE, exposure × mediator products in the outcome model, Gaussian lm/glm, serial + parallel | — | **yes** |
| `joint-mm` | Mediator × mediator products (weighting approach, §4 of VanderWeele & Vansteelandt 2014) | `joint-xm-lm` | no |
| `joint-lavaan` | The same estimand from a lavaan fit with precomputed product columns | `joint-xm-lm` | no |
| `joint-nongaussian` | Binary/count outcome, binary mediators (§3.3–3.4 closed forms; Monte Carlo otherwise) | `joint-xm-lm` | no |

Build order: `joint-xm-lm` → the others in any order.

## Estimand and formulas (source: VanderWeele & Vansteelandt 2014, §3.2–3.3, read in full)

Notation (paper's): exposure `A` with contrast `a` vs `a*`, mediators `M(1)…M(K)`, covariates `C`.

**Models the paper assumes.** This covers a continuous outcome.
- Outcome: `E[Y | a, m, c] = θ0 + θ1 a + Σi θ2(i) m(i) + Σi∈I θ3(i) a m(i) + θ4' c`, where `I` is
  the set of mediators that carry an exposure product.
- Each mediator: `E[M(i) | a, c] = β0(i) + β1(i) a + β2(i)' c`. The mediator means are
  **conditional on `a` and `c` only**, not on the other mediators. The paper says this is what
  lets the approach work when mediators affect one another.

**Effects.** Each is the paper's no-interaction expression plus one term per product, multiplied by
`(a − a*)`:

| Effect | Expression × `(a − a*)` |
|---|---|
| CDE(m) | `θ1 + Σi∈I θ3(i) m(i)` |
| NDE | `θ1 + Σi∈I θ3(i) (β0(i) + β1(i) a* + β2(i)' c)` |
| NIE | `Σi (θ2(i) + θ3(i) a) β1(i)`, with `θ3(i) = 0` for `i ∉ I` (evaluated at the active level `a`, not `a*`) |
| TE | `NDE + NIE` |

medfit uses the unit contrast `a* = 0`, `a = 1`, so `NIE = Σi (θ2(i) + θ3(i)) β1(i)`.

**The `β` in this table are total (reduced-form) coefficients (G8).** They are the coefficients of
`M(i)` on `(a, c)` alone. For a serial chain they are **not** the raw coefficients the user's
mediator models report. The extractor computes propagated quantities `β0*(i)`, `β1*(i)`, `γ*(i)`
by recursion down the chain (medfit step 1). For example, `β1*(2) = β1(2) + d21 β1*(1)`, where
`β1(2)` is the raw X coefficient in `M2 ~ X + M1 + C`. Only the propagated quantities enter the
table. For parallel mediators, raw and propagated coincide.

**Identification** (paper, §3.1): the four no-unmeasured-confounding assumptions, stated for the
whole mediator vector. These are no unmeasured exposure–outcome confounding, none for mediators–outcome,
none for exposure–mediators, and no exposure-induced mediator–outcome confounder **outside the
mediator vector**. Earlier mediators in a serial chain are exposure-induced and confound later
ones. They are allowed precisely because they are in the vector; the paper says such a variable
must be added to the vector. The docs must say that mediator–outcome and exposure–mediator
confounders must be controlled for **every** mediator.

**Standard errors.** The paper recommends the bootstrap for these variants and notes that
delta-method formulas are possible but would need deriving case by case. See the SE design below.

### medfit-side steps (not in the paper; each has a test that can fail)

1. **Serial mediator means.** The paper's mediator models regress `M(i)` on `a` and `c` only.
   medfit's serial models condition on earlier mediators (`M2 ~ X + M1 + C`). For linear models
   with no products in the mediator models, iterated expectations give
   `E[M2 | a, c] = β0(2) + β1(2) a + d E[M1 | a, c] + γ2' c`, and so on down the chain. This equals
   the paper's `E[M(i) | a, c]`.
   *Test:* when every mediator model uses the same covariate set, the propagated exposure
   coefficient equals the OLS coefficient of a directly fitted `M(i) ~ X + C` **exactly**, by the
   OLS omitted-variable identity (to 1e-10).
2. **Covariate evaluation point.** NDE depends on `c`. medfit evaluates it at the sample covariate
   means, the convention `extract_mediation()` already uses for the single-mediator four-way path
   (`R/extract-lm.R`, the `m_ref` computation near line 615).
   - The effects are linear in `c`, so the value at `c̄` equals the sample average of the
     per-observation effects exactly.
   - The delta-method SE treats `c̄` as fixed. That makes it conditional on the observed
     covariates, as in the four-way path, and it slightly understates the SE of the
     population-average effect. The docs say so (G7).
3. **Joint vcov for delta-method SEs (G2).** The existing lm chains use a vcov that is
   block-diagonal across equations. That is wrong for parallel mediators with correlated
   residuals. `JointMediationData` fills the cross-equation blocks with the stacked-OLS covariance
   `σ̂_ij (Xi'Xi)⁻¹ Xi'Xj (Xj'Xj)⁻¹`, where `σ̂_ij` is the mean residual cross-product.
   - When a residual lies in another equation's column space, `σ̂_ij = 0` exactly. That holds for
     a serial chain with identical covariate sets (G4), and for the outcome equation against every
     mediator equation.
   - So only parallel mediator–mediator blocks are nonzero.
   - This relies on every model having an intercept and on unweighted OLS. Checked 2026-09-23 (n = 500):
     the serial and outcome cross-products are about 1e-14, and the parallel one is 176.
   - With `weights`, the zero holds only for the weighted cross-product. Module 1 therefore errors
     on weighted or intercept-free models (G7).
   - All models must use the same rows; error otherwise.
   - Existing classes are untouched.
   *Test:* delta-method SEs match nonparametric bootstrap SDs within 3% for **both** structures,
   including a parallel fixture with correlated mediator errors. The serial cross-blocks are zero
   to 1e-10.

### Gradient terms and parameter naming (G8)

The effects depend on these quantities, and every one needs a row in `@estimates` and `@vcov`:
- outcome coefficients `θ1`, `θ2(i)`, `θ3(i)`;
- every mediator model's intercept `β0(i)`, treatment coefficient `β1(i)`, mediator-to-mediator
  coefficients `d_ij` (serial) and covariate coefficients `γ(i)`.

The covariate means `c̄` are constants, conditional on the observed covariates as in the four-way
path.
- **Naming:** source rows keep per-equation prefixes (`m1_`, `m2_`, …, `y_`), following the
  four-way path's `m_`/`y_` rows (`R/effect-se.R`). Aliases (`a1..aK`, `d21, d32, …`,
  `b1..bK`, `theta3_<mediator>`, `c_prime`) are added for the path coefficients only. Intercepts
  and covariate coefficients are reached through the source rows.
- **Gradients:** analytic, for each effect with respect to every quantity above. NDE, for
  example, has non-zero partials in `θ1`, each `θ3(i)`, each `β0(i)` and `β1(i)`, each `d_ij`
  (through the propagated means), and each `γ(i)` (weighted by `c̄`). The plan lists them per
  effect.
- **Bootstrap:** a parametric `statistic_fn` receives the full named `@estimates`. The docs give
  a recipe that closes over `c̄`. Aliases alone cannot reproduce NDE, and the docs say so.

## Behavior

- `extract_mediation(model_m, model_y = ..., mediator = c("M1", "M2"), mediator_models = ...)`
  - With **no product terms**: unchanged. Returns `SerialMediationData` or
    `ParallelMediationData`.
  - With **only exposure × mediator products in the outcome model**, a Gaussian identity-link
    outcome and Gaussian identity-link mediator models: returns a new **`JointMediationData`**
    object.
  - **Every model must carry the same covariate set** after removing the treatment and the
    mediators (G4). Otherwise error, naming the differing terms. This is a medfit limitation that
    keeps the identities exact, not a requirement of the paper. The paper requires only that the
    confounders be controlled for every mediator. Relaxing to nested sets is future work.
  - **Weighted or intercept-free models error** (G7). Detection: non-`NULL` `weights(model)`, or
    no `"(Intercept)"` in `coef(model)`.
  - **Routing depends on which model a product is in (G8).** Product hits keep their
    `"<response>: <term>"` label. A product is allowed only when it is in the outcome model, is
    exactly treatment × one mediator, and is written with `:` or `*`. A product anywhere else
    (for example `X:M1` in the `M2` model of a serial chain) errors, naming the term and the
    model, even when the outcome model is legal.
  - **Every mediator must appear in the outcome model (G8).** The joint NIE counts every mediated
    path, so `Y ~ X + M2` with `M1` left out errors. The existing serial worker requires only the
    last mediator.
  - **Treatment must be numeric 0/1 (G8).** The formulas assume the unit contrast. Factor,
    logical and multi-valued treatments error in module 1.
  - **Gaussian means identity link (G8).** A `gaussian(link = "log")` or any non-identity link
    errors, naming the link.
  - **Mediator order defines the causal order (G8).** For serial chains, `mediator = c("M1", "M2")`
    means M1 precedes M2. A chain whose models contradict that order (for example `M1 ~ X + M2`)
    errors.
  - **Rows must be identical (G8).** The check compares model-frame row names, not just `nrow()`.
    Models fit on different subsets error.
  - **Other arguments on the joint branch (G8):**
    - `decomposition = "two_way"` with a product errors: it would return main-effect numbers.
    - An explicit `structure` that conflicts with the models' predictors errors.
    - A non-default `vcov_fun` errors on the joint branch in module 1, because the stacked-OLS
      cross-blocks assume OLS. PR #75 made `vcov_fun` reach the existing serial, parallel and
      four-way workers; the joint branch is the one place that refuses it. (`fit_mediation()` is
      single-mediator only, so its `se_type` never reaches the joint branch.) A stacked sandwich
      for joint fits is future work.
  - With any other product the error stays, with the message narrowed to what is still
    unsupported. That covers:
    - a product in a mediator model,
    - a mediator × mediator product,
    - a three-way product,
    - an exposure × covariate or mediator × covariate product,
    - non-Gaussian families,
    - any lavaan multi-mediator fit with products.
  - **Product detection covers wrapped terms.** This shipped in PR #74 (`c09d7c8`):
    `.find_wrapped_products()` catches `I(X * M2)` and similar. The joint branch reuses it, and
    test group 8 keeps a regression test. **A product precomputed as a data column cannot be
    detected, and the result would silently ignore it.** The docs must say this plainly in
    `@details`, not only in NEWS.
- New argument behavior (G3): `m_star` is a scalar (applied to every interacting mediator) or a
  named vector keyed by the interacting mediators only, such as `m_star = c(M2 = 1)`. Unknown or
  non-interacting names error. The default is `0`. Supplying `m_star` when no product is present
  errors on the joint branch, reusing `.stop_on_unused_m_star()` from PR #75, which already refuses
  an unused `m_star` on every other path. The check keys on the call site. The extractor expands a
  scalar into a vector named by the interacting mediators before building the object, so the
  stored `@m_star` is always named.
- **The NIE's meaning changes, and this is labeled (G1).** Without a product, `nie()` on a serial
  fit is the chain-only `a*d*b`. The joint NIE counts every mediated path. `print()` and the docs
  say "joint NIE (all paths through M1..MK)", and a test pins the difference.
- `nie()`, `nde()`, `te()`, `pm()` return the joint effects. `decompose()` returns CDE/NDE/NIE/TE.
  `paths()` returns the coefficients the effects depend on.
- `print()`, `summary()`, `confint(parm = "effects")`, `tidy()`, `glance()` work, and follow the
  contracts from #68/#70: effect rows carry numeric delta-method SEs from `.effect_se()`, and
  `tidy()` is silent. Specifically (G8):
  - `pm()` warns and returns `NA` when |TE| is near 0, like the four existing methods.
  - `confint()` warns about the normal approximation, and `tidy()` stays silent (#70 convention).
  - `tidy()` types: `paths` (`a*`, `d*`, `b*`, `theta3_*`, `c_prime`) and `effects` (`cde`,
    `nde`, `nie`, `te`). There is no `components` type, because there is no four-way split.
  - `glance()` gains `structure`, `n_mediators` and `interactions`, with the interacting mediators
    collapsed into one string such as `"M2"`. It also gains `m_star`, formatted as `"M2=0"`.
- `nie()`/`nde()`/`te()`/`pm()` read the stored effect slots. The validator ties those slots to
  the stored path slots, so the two cannot drift apart.
- `bootstrap_mediation()`:
  - `method = "parametric"` and `"plugin"` accept the object. Every coefficient the effects use has
    a named row in `@estimates` and `@vcov`: an alias for path coefficients, a prefixed source row
    for intercepts and covariate coefficients (see "Gradient terms and parameter naming").
  - `method = "nonparametric"` works through the user's own refit function, as today.

## Class sketch

```r
JointMediationData <- S7::new_class(
  "JointMediationData",
  package = "medfit",
  properties = list(
    structure    = S7::class_character,   # "serial" or "parallel"
    mediators    = S7::class_character,
    treatment    = S7::class_character,
    outcome      = S7::class_character,
    interactions = S7::class_character,   # mediators carrying an X x M product
    # path slots (G8): propagated totals + outcome coefficients
    a_total = S7::class_numeric,          # beta1*(i), named by mediator
    b_paths = S7::class_numeric,          # theta2(i), named by mediator
    theta3  = S7::class_numeric,          # theta3(i), named by interacting mediator
    c_prime = S7::class_numeric,          # theta1
    cde = S7::class_numeric, nde = S7::class_numeric,
    nie = S7::class_numeric, total_effect = S7::class_numeric,
    m_star   = S7::class_numeric,         # named by interacting mediators (G3)
    estimates = S7::class_numeric,        # named, with alias rows
    vcov      = S7::class_any,            # named matrix matching estimates
    n = S7::class_integer
  ),
  validator = function(self) {
    tol <- 1e-8 * max(1, abs(self@total_effect))   # relative, as InteractionMediationData
    if (abs(self@total_effect - (self@nde + self@nie)) > tol)
      return("total_effect must equal nde + nie")
    th3 <- stats::setNames(numeric(length(self@mediators)), self@mediators)
    th3[names(self@theta3)] <- self@theta3
    if (abs(self@nie - sum((self@b_paths + th3) * self@a_total)) > tol)
      return("nie must equal sum((theta2 + theta3) * beta1*)")
    if (abs(self@cde - (self@c_prime + sum(self@theta3 * self@m_star[names(self@theta3)]))) > tol)
      return("cde must equal theta1 + sum(theta3 * m_star)")
    if (!setequal(names(self@m_star), self@interactions))
      return("m_star must be named by exactly the interacting mediators")
    NULL
  }
)
```

## Commands

```r
devtools::load_all(); devtools::document()   # then revert DESCRIPTION/NAMESPACE churn (roxygen 8.1 vs pinned 8.0)
testthat::test_file("tests/testthat/test-extract-joint.R")
devtools::test()                             # report failed + error counts
# lint the way CI does
R CMD INSTALL --library=<scratch> . && R_LIBS=<scratch> Rscript -e 'lintr::lint_package()'
spelling::spell_check_package(); urlchecker::url_check()   # every cycle (CLAUDE.md CRAN practice)
devtools::check(cran = TRUE, args = c("--run-donttest", "--no-manual"), document = FALSE,
  env_vars = c(`_R_CHECK_DEPENDS_ONLY_` = "true", `_R_CHECK_SUGGESTS_ONLY_` = "true",
               `_R_CHECK_CRAN_INCOMING_` = "true", `_R_CHECK_CRAN_INCOMING_REMOTE_` = "true"))
```

## Project structure

| File | Change |
|---|---|
| `R/classes.R` | `JointMediationData` class, validator, print |
| `R/extract-joint.R` (new) | `.extract_joint_mediation_lm()`: mediator means (propagated for serial), effects, estimates/vcov with aliases |
| `R/extract-lm.R` | narrow `.stop_on_multimediator_products()`; route supported cases to the new worker |
| `R/effect-se.R` | gradients for the new class in `.effect_gradients()` |
| `R/generics-effects.R` | `nie`/`nde`/`te`/`pm`/`decompose`/`paths` methods (PR A) |
| `R/bootstrap.R` | add the class to `.assert_param_mediation_data()` (PR A, or the class is rejected) |
| `R/methods-base.R`, `R/methods-tidy.R` | print/summary/confint/tidy/glance (PR B) |
| `_pkgdown.yml` | `JointMediationData` in the classes section (every exported topic is listed) |
| `tests/testthat/test-extract-joint.R` (new) | all tests below |
| `NEWS.md`, `inst/WORDLIST` | entries |
| `vignettes/` | a short section in the "Model Extraction" article (`mediation_demo$outcome_int` carries a treatment × mediator1 product) |

## Code style

Match the existing extractors: `checkmate` validation at entry, explicit namespacing, internal
helpers prefixed with `.`, S7 methods `@noRd`, error messages that name the offending term.

```r
# hits carry "<response>: <term>" labels (.find_product_terms()), so the model
# is named. The allowed outcome-model X:M terms are removed before this runs.
.stop_on_unsupported_joint_products <- function(hits, outcome) {
  if (length(hits) == 0L) return(invisible(NULL))
  stop(paste0(
    "Multi-mediator extraction supports treatment x mediator products in the ",
    "outcome model ('", outcome, "') only; found unsupported term(s): ",
    paste(hits, collapse = ", "), "."
  ), call. = FALSE)
}
```

## Testing strategy

All tests go in `test-extract-joint.R` and use fixed seeds, so results are deterministic and
cannot flake. Each oracle is independent of the code under test.

**Runtime policy (G8).** The heavy oracles use `skip_on_cran()`: test 1's 1,000,000-draw truth,
test 2's 200,000-draw Monte Carlo, and test 5's 5,000-rep nonparametric bootstrap. Each has an
always-on companion that runs under `R CMD check`: small n, a pinned value, tolerance 1e-8. CRAN
runs the pins; CI and `devtools::test()` run everything.

**Fixtures (G8).** The serial oracle fixtures must have `d ≠ 0` and cover both an upstream product
(`X:M1`) and a downstream product (`X:M2`). The downstream case is the only one where raw and
propagated `β1` differ. A negative-control test shows that wiring the raw coefficient fails
oracles 1–2.

1. **Known answer (simulation).** Generate serial and parallel data with chosen `θ`, `β` and
   `θ3(i)`, at n = 20,000.
   - Compute the true joint NDE/NIE **without the closed-form formulas** (G7): simulate the nested
     counterfactuals `Y(1, M(0))`, `Y(0, M(0))` and `Y(1, M(1))` directly from the data-generating
     process (1,000,000 draws), then take differences of means.
   - Estimates fall within 3 SE.
2. **Mediation-formula Monte Carlo oracle.** From the fitted models, simulate `M(a*)` and `M(a)`
   draws and average the outcome model over them (g-computation, 200,000 draws). The joint
   NDE/NIE match the closed form to Monte Carlo error. This checks the formulas without reusing them.
3. **Reductions.**
   - K = 1 with a product: matches `InteractionMediationData`'s `nde`/`nie`/`cde` (1e-10).
   - Parallel with `θ3 = 0` in the data-generating process: the joint NIE equals the existing
     `ParallelMediationData` NIE on the same fits (1e-8). Serial is covered by the G1 pin in
     group 8.
4. **Serial propagation identity.** This is medfit step 1 above: an exact 1e-10 match to direct
   `M(i) ~ X + C` OLS.
5. **SE oracle.** This is medfit step 3 above.
   - Delta-method SEs are within 3% of nonparametric bootstrap SDs, for serial and for parallel
     with correlated mediator errors. Use 5,000 reps (3% is about 3 Monte Carlo SEs of a bootstrap
     SD, 1/√(2B) ≈ 1%) and n ≥ 5,000 (keeps the delta-method approximation gap small).
   - Serial and outcome cross-blocks are zero to 1e-10.
   - Models with different rows, weights or no intercept error.
6. **Guard.** Each still-unsupported product type errors with its term named, on lm and glm. lavaan
   multi-mediator with products still errors. No-product fits are unchanged: snapshot of the
   existing serial/parallel outputs.
7. **Methods contract.**
   - `tidy()` is silent and returns numeric effect SEs.
   - `confint()` equals `tidy(conf.int = TRUE)`.
   - A parametric bootstrap with the documented `statistic_fn` recipe (full named `@estimates`,
     closing over `c̄`) reproduces the point NDE and NIE exactly.
   - The validator rejects a bad `total_effect`, an `m_star` not named by exactly the interacting
     mediators, and NIE or CDE values that break the path ties.
8. **G1 pin, G3 and G4.**
   - With θ3 = 0 in the data-generating process, the joint NIE equals the sum over all mediated
     paths and differs from `a*d*b`.
   - A non-interacting or unknown `m_star` name errors.
   - Differing covariate sets error, naming the terms.
   - An `I(X * M)` product in any model is detected (regression test for #74).
   - Each G8 error: a legal outcome product with an illegal mediator-model product, a missing
     mediator in the outcome, a factor treatment, a `gaussian(link = "log")` model, a reversed
     mediator order, same-n but different rows, weights, no intercept, `decomposition = "two_way"`
     with a product, and a non-default `vcov_fun`.
   - `bootstrap_mediation(method = "plugin")` accepts the class (the `R/bootstrap.R` change ships
     in PR A).
9. **Positive control.** Flip the sign of one `θ3(i)` term in the NIE; oracles 1 and 2 must fail.

## Verification harness

Everything the tests need to check the estimator independently lives in one helper file, so each
oracle is written once and reused, and a planted defect can be injected without editing
production code.

**`tests/testthat/helper-joint.R`** (new):

| Helper | What it does |
|---|---|
| `sim_joint(structure, product, n, seed, rho = 0)` | Data from a known data-generating process. `structure` is `"serial"` or `"parallel"`; `product` is `"M1"`, `"M2"` or `"none"`. Serial uses `d ≠ 0`. `rho` sets the mediator error correlation (parallel). Returns the data plus the true parameters. |
| `true_joint_effects(dgp, draws = 1e6, seed)` | Oracle 1 truth. Simulates `M(0)` and `M(1)` for each unit from the true mediator equations, then `Y(1, M(0))`, `Y(0, M(0))` and `Y(1, M(1))` from the true outcome equation. Returns NDE, NIE, TE and CDE(m*) as differences of means. It never calls the closed-form formulas. |
| `gcomp_joint(fits, draws = 2e5, seed)` | Oracle 2. The same simulation, but from the **fitted** models, with residual SDs from the fits. |
| `boot_joint_se(dat, spec, B = 5000, seed)` | Oracle 5. Nonparametric bootstrap: resample rows, refit every model, re-extract, and return the SD of each effect. |
| `effects_from(obj, effect_fn = NULL)` | Returns the object's effects. With `effect_fn` supplied, it recomputes them from `@estimates` with that function instead. The planted-defect controls pass a broken `effect_fn` (sign-flipped `θ3`, or raw instead of propagated `β1`) and assert that oracles 1–2 then **fail**. Production code is never edited. |
| `fit_joint(dat, structure, product, ...)` | Fits the models the tests share, with identical covariate sets, and calls `extract_mediation()`. |

**Gating.** Each heavy oracle carries `skip_on_cran()`: `true_joint_effects()` at 1e6 draws,
`gcomp_joint()` at 2e5 draws, and `boot_joint_se()` at B = 5,000. Each has an always-on
companion at small n with a value pinned to 1e-8, so `R CMD check` on CRAN still exercises every
code path. `withr` is not in DESCRIPTION (checked 2026-09-23), so tests call `set.seed()` inside
each `test_that()` block, which is the existing test files' convention. No new dependency.

**CI must actually run the heavy oracles.** `skip_on_cran()` skips unless `NOT_CRAN = "true"`. None
of `.github/workflows/` sets it explicitly (checked 2026-09-23); whether the r-lib actions set it
implicitly is unverified. The plan's first task confirms from a CI log that the heavy oracles run,
or sets `NOT_CRAN` in the workflow. That workflow change needs asking first (Boundaries). A heavy oracle that CI
silently skips proves nothing.

**End-to-end run (before each PR, per the e2e-before-pr rule).** In a fresh R session, run the D8
motivating case: serial, `X:M1`, n = 5,000, coefficient 0.82. Then run a downstream `X:M2` case.
Paste the printed `JointMediationData`, its `tidy()` output, and the oracle-1 comparison into the
PR body. The run can fail: a mismatch against `true_joint_effects()` beyond 3 SE blocks the PR.

## Outcomes

What "done" looks like, check by check. Each row can fail.

| Check | Expected outcome | Pass criterion | PR |
|---|---|---|---|
| Oracle 1 (known answer) | Joint NDE, NIE, TE, CDE match the simulated counterfactual truth: serial with `X:M1`, serial with `X:M2` (`d ≠ 0`), parallel with `X:M1` | every estimate within 3 SE of the truth | A |
| Oracle 2 (g-computation) | The closed form matches the Monte Carlo average over the fitted models | within 4 Monte Carlo SEs | A |
| Planted defects | A sign-flipped `θ3` and a raw-`β1` wiring each **fail** oracles 1–2 | at least one oracle fails for each defect | A |
| Reductions | K = 1 matches `InteractionMediationData`; parallel with θ3 = 0 matches `ParallelMediationData` NIE | 1e-10 and 1e-8 | A |
| Propagation identity | Propagated `β1*(i)` equals a direct `M(i) ~ X + C` OLS fit | 1e-10 | A |
| SE oracle | Delta-method SEs match bootstrap SDs, serial and correlated-error parallel | within 3% | A |
| Zero cross-blocks | Serial and outcome cross-equation blocks | 1e-10 | A |
| Guards | Every unsupported product, and every G8 condition, errors naming the term and model | `expect_error()` with a regex naming the term | A |
| No-product behavior | Serial and parallel outputs are unchanged | snapshot equality | A |
| G1 pin | With θ3 = 0, the joint NIE differs from `a*d*b` and equals the all-paths sum | 1e-8 | A |
| Methods contract | `tidy()` silent; `confint()` equals `tidy()`; the bootstrap recipe reproduces NDE/NIE | exact | B |
| CRAN runtime | The always-on portion of `test-extract-joint.R` | target under 10 s on one core | A |
| CI coverage | The heavy oracles run, not skip, on GitHub Actions | CI log shows them executed | A |
| Suite and gates | Full `devtools::test()`; lint; spelling; strict check | 0 failed, 0 errors; 0 lints; clean; 0/0 plus only the Date note | A, B |
| E2E transcript | D8 motivating case and downstream case in a fresh session | pasted in the PR body; oracle 1 within 3 SE | A, B |

Two rows are targets, not proven facts: CRAN runtime (to be measured) and CI coverage (to be
confirmed from a log). The plan's first task measures or confirms both before any feature code.

## Boundaries

- **Always:**
  - cite only the papers listed below, each checked against its PubMed record;
  - state claims about a paper only if they are in the part that was read;
  - label medfit-side derivations as such, each with a test that can fail;
  - run the full suite, the CI-style lint and the strict check before the PR.
- **Ask first:**
  - adding a dependency (numerical-gradient packages included);
  - changing any existing class or the #70 `tidy()` contract;
  - widening scope to any later module.
- **Never:**
  - return main-effect numbers when a product is present;
  - report a per-mediator split of the joint NIE;
  - cite or characterize a paper that was not read.

## Success criteria

- The D8 motivating case works: a serial fit with a treatment × mediator1 product (the GRILL D8
  reproduction: coefficient 0.82, n = 5000) returns `JointMediationData` whose NIE/NDE pass
  oracles 1–2. So does a downstream-product serial fit (`X:M2`, `d ≠ 0`).
- Every still-unsupported product still errors, naming the term.
- All 9 test groups pass. Full suite: 0 failed, 0 errors. Lint adds no hits. Strict check 0/0 with
  only the Date NOTE.
- Docs state the estimand (joint, no per-path split), the NIE-meaning difference from the
  no-product serial class (G1), the whole-vector assumptions, the identical-covariate-set
  requirement and the covariate evaluation point.

## Delivery (G5)

- **PR A:** class, extractor, guard narrowing, cross-equation vcov, `.effect_gradients()` and the
  effect generics. It carries test groups 1–6, 8 and 9.
- **PR B:** `print`/`summary`/`confint`/`tidy`/`glance`, bootstrap aliases (test group 7), NEWS,
  pkgdown and the Model Extraction section.

## Resolved questions (G6)

1. **Class name:** `JointMediationData`.
2. **Gradients:** analytic, by the chain rule through the propagated means.
3. **A four-way analog for K ≥ 2:** out unless a verified source is found.
4. **Covariate evaluation:** at the sample means. Because the effects are linear in `c`, this
   equals the sample average of the per-observation effects exactly (G7 corrected the earlier
   "population-average" wording). The means are treated as fixed in the delta method, as in the
   four-way path, so the SE is conditional on the observed covariates.

## References

Metadata confirmed via PubMed 2026-09-23. "Read" marks the parts this spec relies on.

- VanderWeele TJ, Vansteelandt S (2014). Mediation analysis with multiple mediators.
  *Epidemiologic Methods* 2(1):95–115. doi:[10.1515/em-2012-0010](https://doi.org/10.1515/em-2012-0010).
  PMID 25580377, PMC4287269. **Read: full text** (§3.2–3.3 formulas, §3.1 assumptions, §4 weighting,
  §6 robustness). The appendix proofs were not in the retrieved text.
- Daniel RM, De Stavola BL, Cousens SN, Vansteelandt S (2015). Causal mediation analysis with
  multiple mediators. *Biometrics* 71(1):1–14. doi:[10.1111/biom.12248](https://doi.org/10.1111/biom.12248).
  **Read: abstract.** Cited only for "per-path decompositions need strong assumptions".
- Vansteelandt S, Daniel RM (2017). Interventional effects for mediation analysis with multiple
  mediators. *Epidemiology* 28(2):258–265.
  doi:[10.1097/EDE.0000000000000596](https://doi.org/10.1097/EDE.0000000000000596).
  **Read: abstract.** Cited only as the alternative estimand.
- Steen J, Loeys T, Moerkerke B, Vansteelandt S (2017). Flexible mediation analysis with multiple
  mediators. *American Journal of Epidemiology* 186(2):184–193.
  doi:[10.1093/aje/kwx051](https://doi.org/10.1093/aje/kwx051). **Read: abstract.** Cited only as the
  alternative (natural effects models).
- VanderWeele TJ (2014). A unification of mediation and interaction: a 4-way decomposition.
  *Epidemiology* 25(5):749–761. Already cited by `SPEC-interaction-fourway-2026-06-03.md`; used here
  only for the K = 1 reduction test.
